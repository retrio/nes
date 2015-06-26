package strafe.emu.nes;

import haxe.ds.Vector;
import strafe.ByteString;


@:build(strafe.macro.Optimizer.build())
class PPU implements IState
{
	static inline var OPEN_BUS_DECAY_CYCLES = 1000000;

	static var defaultPalette=[
		0x09, 0x01, 0x00, 0x01, 0x00, 0x02, 0x02, 0x0D,
		0x08, 0x10, 0x08, 0x24, 0x00, 0x00, 0x04, 0x2C, 0x09, 0x01, 0x34, 0x03,
		0x00, 0x04, 0x00, 0x14, 0x08, 0x3A, 0x00, 0x02, 0x00, 0x20, 0x2C, 0x08
	];

	public var mapper:Mapper;
	public var cpu:CPU;
	public var frameCount:Int = 1;
	public var stolenCycles:Int = 0;
	public var finished:Bool = false;
	public var needCatchUp(default, set):Bool = false;
	inline function set_needCatchUp(b:Bool)
	{
		if (b) catchUp();
		return needCatchUp = false;
	}

	public static inline var RESOLUTION_X=256;
	public static inline var RESOLUTION_Y=240;

	public var oam:ByteString = new ByteString(0x100);
	public var t0:ByteString = new ByteString(0x400);
	public var t1:ByteString = new ByteString(0x400);
	public var t2:ByteString = new ByteString(0x400);
	public var t3:ByteString = new ByteString(0x400);
	public var statusReg:Int=0;
	public var pal:ByteString = new ByteString(32);
	public var screenBuffer:ByteString = new ByteString(240 * 256);

	public var scanline:Int = 0;
	public var cycles:Int = 1;

	var vramAddr:Int = 0;
	var vramAddrTemp:Int = 0;
	var xScroll:Int = 0;
	var even = true;

	var bgPatternAddr = 0x1000;
	var sprPatternAddr = 0;

	var oamAddr:Int = 0;

	var bgShiftRegH:Int = 0;
	var bgShiftRegL:Int = 0;
	var bgAttrShiftRegH:Int = 0;
	var bgAttrShiftRegL:Int = 0;
	// $2000 PPUCTRL registers
	var nmiEnabled:Bool = false;
	var ntAddr:Int = 0;
	var vramInc:Int = 1;
	var tallSprites:Bool = false;
	// $2001 PPUMASK registers
	var greyscale:Bool = false;
	var bgClip:Bool = false;
	var sprClip:Bool = false;
	var bgRender:Bool = false;
	var sprRender:Bool = false;
	var emph:Int = 0;
	// $2002 PPUSTATUS registers
	var spriteOverflow:Bool = false;
	var sprite0:Bool = false;
	var vblank:Bool = false;

	var spritebgflags:Vector<Bool> = new Vector(8);
	var spriteShiftRegH:Vector<Int> = new Vector(8);
	var spriteShiftRegL:Vector<Int> = new Vector(8);
	var spriteXlatch:Vector<Int> = new Vector(8);
	var spritepals:Vector<Int> = new Vector(8);
	var openBus:Int = 0;
	var openBusDecayH:Int = 0;
	var openBusDecayL:Int = 0;
	var readBuffer:Int = 0;
	var tileAddr:Int = 0;
	var tileL:Int = 0;
	var tileH:Int = 0;
	var attr:Int = 0;
	var attrH:Int = 0;
	var attrL:Int = 0;

	var off:Int = 0;
	var index:Int = 0;
	var sprpxl:Int = 0;
	var found:Int = 0;
	var sprite0here:Bool = false;
	var suppress:Bool = false;
	var sprite0coming:Null<Int> = null;

	var enabled(get, never):Bool;
	inline function get_enabled()
	{
		return bgRender || sprRender;
	}

	public function new(mapper:Mapper, cpu:CPU)
	{
		this.mapper = mapper;
		mapper.ppu = this;

		this.cpu = cpu;

		oam.fillWith(0xff);
		screenBuffer.fillWith(0);
		t0.fillWith(0);
		t1.fillWith(0);
		t2.fillWith(0);
		t3.fillWith(0);

		pal = new ByteString(defaultPalette.length);
		for (i in 0 ... pal.length) pal.set(i, defaultPalette[i]);
	}

	public inline function read(addr:Int):Int
	{
		catchUp();
		var result:Int = 0;

		switch(addr)
		{
			case 2:
				if (scanline == 241)
				{
					if (cycles < 4)
					{
						if (cycles == 0)
						{
							vblank = false;
						}
						suppress = true;
					}
				}

				// PPUSTATUS
				even = true;
				openBus = (spriteOverflow ? 0x20 : 0) |
					(sprite0 ? 0x40 : 0) |
					(vblank ? 0x80 : 0) |
					(openBus & 0x1f);
				// reading PPUSTATUS doesn't refresh decay of the lower 5 bits
				openBusDecayH = OPEN_BUS_DECAY_CYCLES;
				vblank = false;

			case 4:
				// read from sprite ram
				// clearing bits 2-4 will cause PPU open bus test to pass,
				// but sprite RAM test to fail
				openBus = oam.get(oamAddr) & 0xe3;
				openBusDecayH = openBusDecayL = OPEN_BUS_DECAY_CYCLES;

			case 7:
				// PPUDATA
				// read is buffered and returned next time
				// unless reading from sprite memory
				if ((vramAddr & 0x3fff) < 0x3f00)
				{
					openBus = readBuffer;
					readBuffer = mapper.ppuRead(vramAddr & 0x3fff);
				}
				else
				{
					openBus = (openBus & 0xc0) | (mapper.ppuRead(vramAddr) & 0x3f);
					readBuffer = mapper.ppuRead((vramAddr & 0x3fff) - 0x1000);
				}
				openBusDecayH = openBusDecayL = OPEN_BUS_DECAY_CYCLES;
				if (!enabled || (scanline > 240 && scanline < 261))
				{
					vramAddr += vramInc;
				}
				else
				{
					incrementX();
					incrementY();
				}

			default: {}
		}

		return openBus;
	}

	public inline function write(addr:Int, data:Int)
	{
		catchUp();
		openBus = data;
		openBusDecayH = openBusDecayL = OPEN_BUS_DECAY_CYCLES;

		switch(addr)
		{
			case 0:
				// PPUCTRL
				vramAddrTemp &= ~0xc00;
				vramAddrTemp += (data & 3) << 10;
				vramInc = Util.getbit(data, 2) ? 0x20 : 1;
				sprPatternAddr = Util.getbit(data, 3) ? 0x1000 : 0;
				bgPatternAddr = Util.getbit(data, 4) ? 0x1000 : 0;
				tallSprites = Util.getbit(data, 5);
				// ppu master/slave?
				nmiEnabled = Util.getbit(data, 7);
				if (!nmiEnabled)
				{
					suppress = true;
				}

			case 1:
				// PPUMASK
				greyscale = Util.getbit(data, 0);
				bgClip = Util.getbit(data, 1);
				sprClip = Util.getbit(data, 2);
				bgRender = Util.getbit(data, 3);
				sprRender = Util.getbit(data, 4);
				emph = (data & 0xe0) << 1;

			case 3:
				// OAMADDR
				oamAddr = data & 0xff;

			case 4:
				// OAMDATA
				oam.set(oamAddr++, data);
				oamAddr &= 0xff;

			case 5:
				// PPUSCROLL
				if (even)
				{
					// update horizontal scroll
					vramAddrTemp &= ~0x1f;
					xScroll = data & 7;
					vramAddrTemp += data >> 3;
					even = false;
				}
				else
				{
					// update vertical scroll
					vramAddrTemp &= ~0x7000;
					vramAddrTemp |= ((data & 7) << 12);
					vramAddrTemp &= ~0x3e0;
					vramAddrTemp |= (data & 0xf8) << 2;
					even = true;
				}

			case 6:
				// PPUADDR: write twice to set this register data
				if (even)
				{
					// high byte
					vramAddrTemp &= 0xff;
					vramAddrTemp |= ((data & 0x3f) << 8);
					even = false;
				}
				else
				{
					vramAddrTemp &= 0x7f00;
					vramAddrTemp |= data;
					vramAddr = vramAddrTemp;
					// trace(StringTools.hex(vramAddr));
					even = true;
				}

			case 7:
				// PPUDATA: write to location specified by vramAddr
				mapper.ppuWrite(vramAddr & 0x3fff, data);
				if (!enabled || (scanline > 240 && scanline < 261))
				{
					vramAddr += vramInc;
				}
				else
				{
					// if 2007 is read during rendering PPU increments both horiz
					// and vert counters erroneously.
					if (((cycles - 1) & 7) != 7)
					{
						incrementX();
						incrementY();
					}
				}
		}
	}

	/*public inline function runFrame()
	{
		++frameCount;
		scanline = 0;
		var skip = (bgRender && (frameCount & 1 == 1))
			? 1 : 0;
		cycles = skip;

		while (scanline < 262)
		{
			if (scanline <= 241 || scanline >= 260)
			{
				clock();
			}
			else
			{
				yieldToCPU();
				signalNMI();
			}

			if (++cycles > 340)
			{
				mapper.onScanline(scanline);
				cycles = 0;
				++scanline;
			}
		}
	}*/

	inline function incPixel()
	{
		if (++cycles > 340)
		{
			cycles = 0;
			if (scanline < 241)
			{
				mapper.onScanline(scanline);
			}
			if (++scanline > 261)
			{
				scanline = 0;
				++frameCount;
				if (bgRender && (frameCount & 1 == 1))
					++cycles;
				finished = true;
			}
		}
	}

	public function catchUp()
	{
		//cpu.cycles += cpu.ticks;
		//cpu.ticks = 0;
		stolenCycles += cpu.cycles;

		while (!finished && cpu.cycles > 0)
		{
			--cpu.cycles;
			@unroll for (i in 0 ... 3)
			{
				clock();
				incPixel();
			}
		}

		stolenCycles -= cpu.cycles;
	}

	public inline function clock()
	{
		var enabled = enabled;

		if (suppress)
		{
			cpu.suppressNmi();
			suppress = false;
		}

		if (scanline < 240 || scanline == 261)
		{
			// visible scanlines
			if (enabled
				&& ((cycles >= 1 && cycles <= 256)
				|| (cycles >= 321 && cycles <= 336)))
			{
				// fetch background tiles, load shift registers
				bgFetch();
			}
			else if (cycles == 257 && enabled)
			{
				// horizontal bits of vramAddr = vramAddrTemp
				vramAddr &= ~0x41f;
				vramAddr |= vramAddrTemp & 0x41f;
			}
			else if (cycles > 257 && cycles <= 341)
			{
				// clear the oam address from pxls 257-341 continuously
				oamAddr = 0;
			}
			if ((cycles == 340) && enabled)
			{
				// read the same nametable byte twice
				// this signals the MMC5 to increment the scanline counter
				fetchNTByte();
				fetchNTByte();
			}
			if (cycles == 260 && enabled)
			{
				evalSprites();
			}
			if (scanline == 261)
			{
				if (cycles == 1)
				{
					// turn off vblank, sprite 0, sprite overflow flags
					vblank = sprite0 = spriteOverflow = false;
				}
				else if (cycles >= 280 && cycles <= 304 && enabled)
				{
					vramAddr = vramAddrTemp;
				}
			}
		}
		else if (scanline == 241 && cycles == 1)
		{
			vblank = true;
		}

		if (scanline < 240)
		{
			if (cycles >= 1 && cycles <= 256)
			{
				var bufferOffset = (scanline << 8) + (cycles - 1);
				// bg drawing
				if (bgRender)
				{
					var isBG = drawBGPixel(bufferOffset);
					drawSprites(scanline << 8, cycles - 1, isBG);
				}
				else
				{
					// rendering is off; draw either the background color or
					// if the PPU address points to the palette, draw that color
					var bgcolor = ((vramAddr > 0x3f00 && vramAddr < 0x3fff) ? mapper.ppuRead(vramAddr) : pal.get(0));
					screenBuffer.set(bufferOffset, bgcolor);
				}
				// greyscale
				if (greyscale)
				{
					screenBuffer.set(bufferOffset, screenBuffer.get(bufferOffset) & 0x30);
				}
				// color emphasis
				screenBuffer.set(bufferOffset, (screenBuffer.get(bufferOffset) & 0x3f) | emph);
			}
		}

		signalNMI();

		// open bus value decay
		if (openBusDecayH > 0 && --openBusDecayH == 0)
		{
			openBus &= 0x1f;
		}
		if (openBusDecayL > 0 && --openBusDecayL == 0)
		{
			openBus &= 0xe0;
		}
	}

	inline function signalNMI()
	{
		cpu.nmi = vblank && nmiEnabled;
	}

	inline function incrementY()
	{
		if (vramAddr & 0x7000 != 0x7000)
		{
			vramAddr += 0x1000;
		}
		else
		{
			vramAddr &= ~0x7000;
			var y = (vramAddr & 0x3e0) >> 5;
			if (y == 29)
			{
				y = 0;
				vramAddr ^= 0x800;
			}
			else if (y == 31)
			{
				y = 0;
			}
			else
			{
				++y;
			}
			vramAddr = (vramAddr & ~0x3e0) | (y << 5);
		}
	}

	inline function incrementX()
	{
		//increment horizontal part of vramAddr
		// if coarse X == 31
		if ((vramAddr & 0x001F) == 31)
		{
			// coarse X = 0
			vramAddr &= ~0x001F;
			// switch horizontal nametable
			vramAddr ^= 0x0400;
		}
		else
		{
			// increment coarse X
			++vramAddr;
		}
	}

	inline function bgFetch()
	{
		bgShiftClock();

		bgAttrShiftRegH |= attrH;
		bgAttrShiftRegL |= attrL;

		// background fetches
		switch ((cycles - 1) & 7)
		{
			case 1:
				fetchNTByte();

			case 3:
				// fetch attribute
				attr = getAttribute(((vramAddr & 0xc00) | 0x23c0),
								(vramAddr) & 0x1f,
								(((vramAddr) & 0x3e0) >> 5));

			case 5:
				// fetch low bg byte
				tileL = mapper.ppuRead((tileAddr) + ((vramAddr & 0x7000) >> 12)) & 0xff;

			case 7:
				// fetch high bg byte
				tileH = mapper.ppuRead((tileAddr) + ((vramAddr & 0x7000) >> 12) + 8) & 0xff;

				bgShiftRegH |= tileH;
				bgShiftRegL |= tileL;

				attrH = (attr >> 1) & 1;
				attrL = attr & 1;

				if (cycles != 256)
				{
					incrementX();
				}
				else
				{
					incrementY();
				}

			default: {}
		}
	}

	inline function fetchNTByte()
	{
		// fetch nt byte
		tileAddr = (mapper.ppuRead(((vramAddr & 0xc00) | 0x2000) + (vramAddr & 0x3ff)) << 4) + bgPatternAddr;
	}

	inline function drawBGPixel(bufferOffset:Int):Bool
	{
		var isBG:Bool;
		if (!bgClip && (bufferOffset & 0xff) < 8)
		{
			// left clip
			screenBuffer.set(bufferOffset, pal.get(0));
			isBG = true;
		}
		else
		{
			var bgPix = (Util.getbitI(bgShiftRegH, 16 - xScroll) << 1)
					+ Util.getbitI(bgShiftRegL, 16 - xScroll);
			var bgPal = (Util.getbitI(bgAttrShiftRegH, 8 - xScroll) << 1)
					+ Util.getbitI(bgAttrShiftRegL, 8 - xScroll);
			isBG = (bgPix == 0);
			screenBuffer.set(bufferOffset, (isBG ? pal.get(0) : pal.get((bgPal << 2) + bgPix)));
		}
		return isBG;
	}

	inline function bgShiftClock()
	{
		bgShiftRegH <<= 1;
		bgShiftRegL <<= 1;
		bgAttrShiftRegH <<= 1;
		bgAttrShiftRegL <<= 1;
	}

	/**
	 * evaluates PPU sprites for the NEXT scanline
	 */
	inline function evalSprites()
	{
		sprite0here = false;
		var ypos:Int = 0;
		var offset:Int = 0;
		var tilefetched:Int = 0;
		found = 0;
		// primary evaluation
		// need to emulate behavior when OAM address is set to nonzero here
		var spritestart = 0;
		while (spritestart < 253)
		{
			// for each sprite, first we cull the non-visible ones
			ypos = oam.get(spritestart);
			offset = scanline - ypos;
			if (ypos > scanline || ypos > 254 || offset > (tallSprites ? 15 : 7))
			{
				// sprite is out of range vertically
				spritestart += 4;
				continue;
			}

			if (spritestart == 0)
			{
				sprite0here = true;
			}

			if (found >= 8)
			{
				// if more than 8 sprites, set overflow bit and stop looking
				// TODO: add "no sprite limit" option
				spriteOverflow = true;
				// obscure (hardware glitch) behavior not yet implemented
				break;
			}

			// set up sprite for rendering
			var oamextra = oam.get(spritestart + 2);
			// bg flag
			spritebgflags[found] = Util.getbit(oamextra, 5);
			// x value
			spriteXlatch[found] = oam.get(spritestart + 3);
			spritepals[found] = ((oamextra & 3) + 4) * 4;
			if (Util.getbit(oamextra, 7))
			{
				// if sprite is flipped vertically, reverse the offset
				offset = (tallSprites ? 15 : 7) - offset;
			}
			// now correction for the fact that 8x16 tiles are 2 separate tiles
			if (offset > 7)
			{
				offset += 8;
			}
			// get tile address (8x16 sprites can use both pattern tbl pages but only the even tiles)
			var tilenum = oam.get(spritestart + 1);
			spriteFetch(tilenum, offset, oamextra);
			++found;

			spritestart += 4;
		}
		for (i in found ... 8)
		{
			// fill unused sprite registers with zeros
			spriteShiftRegL[i] = 0;
			spriteShiftRegH[i] = 0;
		}
	}

	inline function spriteFetch(tilenum:Int, offset:Int, oamextra:Int)
	{
		var tilefetched:Int;
		if (tallSprites)
		{
			tilefetched = ((tilenum & 1) * 0x1000)
					+ (tilenum & 0xfe) * 16;
		}
		else
		{
			tilefetched = tilenum * 16
					+ (sprPatternAddr);
		}
		tilefetched += offset;
		// load sprite shift registers
		var hflip:Bool = Util.getbit(oamextra, 6);
		if (!hflip)
		{
			spriteShiftRegL[found] = Util.reverseByte(mapper.ppuRead(tilefetched));
			spriteShiftRegH[found] = Util.reverseByte(mapper.ppuRead(tilefetched + 8));
		}
		else
		{
			spriteShiftRegL[found] = mapper.ppuRead(tilefetched);
			spriteShiftRegH[found] = mapper.ppuRead(tilefetched + 8);
		}
	}

	/**
	 * draws appropriate lines of the sprites selected by sprite evaluation
	 */
	inline function drawSprites(bufferOffset:Int, x:Int, bgflag:Bool)
	{
		//sprite left 8 pixels clip
		var startdraw = sprClip ? 0 : 8;
		sprpxl = 0;
		index = 7;

		var y = found - 1;
		while (y >= 0)
		{
			off = x - spriteXlatch[y];
			if (off >= 0 && off <= 8)
			{
				if ((spriteShiftRegH[y] & 1) + (spriteShiftRegL[y] & 1) != 0)
				{
					index = y;
					sprpxl = 2 * (spriteShiftRegH[y] & 1) + (spriteShiftRegL[y] & 1);
				}
				spriteShiftRegH[y] >>= 1;
				spriteShiftRegL[y] >>= 1;
			}
			--y;
		}
		if (sprpxl == 0 || x < startdraw || !sprRender)
		{
			// no opaque sprite pixel here
		}
		else
		{
			if (sprite0here && (index == 0) && !bgflag && x < 255)
			{
				// sprite 0 hit
				sprite0 = true;
			}
			if (!spritebgflags[index] || bgflag)
			{
				screenBuffer.set(bufferOffset + x, pal.get(spritepals[index] + sprpxl));
			}
		}
	}

	inline function getAttribute(ntstart:Int, tileX:Int, tileY:Int)
	{
		var base = mapper.ppuRead(ntstart + (tileX >> 2) + 8 * (tileY >> 2));
		if (Util.getbit(tileY, 1))
		{
			if (Util.getbit(tileX, 1))
			{
				return (base >> 6) & 3;
			}
			else
			{
				return (base >> 4) & 3;
			}
		}
		else
		{
			if (Util.getbit(tileX, 1))
			{
				return (base >> 2) & 3;
			}
			else
			{
				return base & 3;
			}
		}
	}

	public function writeState(out:haxe.io.Output)
	{
		// TODO
	}
}
