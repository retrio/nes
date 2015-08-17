package retrio.emu.nes;

import haxe.ds.Vector;
import retrio.ByteString;
import retrio.emu.nes.mappers.*;


class Mapper implements IState
{
	public static function getMapper(mapperNumber:Int):Mapper
	{
		return switch (mapperNumber)
		{
			case 0: new Mapper();		// NROM; no special functionality
			case 1: new MMC1Mapper();
			case 2: new UnromMapper();
			case 3: new CnromMapper();
			case 4: new MMC3Mapper();
			case 7: new AoromMapper();
			default: throw ("Mapper " + mapperNumber + " is not implemented yet.");
		}
	}

	public var rom:ROM;
	public var memory:Memory;
	public var cpu:CPU;
	public var ppu:PPU;

	// nametable pointers
	@:state var nt0a(default, set):Byte;
	function set_nt0a(b:Byte)
	{
		nt0 = ppu.nameTables[b];
		return nt0a = b;
	}
	@:state var nt1a(default, set):Byte;
	function set_nt1a(b:Byte)
	{
		nt1 = ppu.nameTables[b];
		return nt1a = b;
	}
	@:state var nt2a(default, set):Byte;
	function set_nt2a(b:Byte)
	{
		nt2 = ppu.nameTables[b];
		return nt2a = b;
	}
	@:state var nt3a(default, set):Byte;
	function set_nt3a(b:Byte)
	{
		nt3 = ppu.nameTables[b];
		return nt3a = b;
	}

	public var nt0:ByteString;
	public var nt1:ByteString;
	public var nt2:ByteString;
	public var nt3:ByteString;

	@:state public var prgMap:Vector<Int>;
	@:state public var chrMap:Vector<Int>;

	public var mirror(default, set):MirrorMode;
	function set_mirror(m:MirrorMode)
	{
		switch(m)
		{
			case H_MIRROR:
				nt0a = 0;
				nt1a = 0;
				nt2a = 1;
				nt3a = 1;

			case V_MIRROR:
				nt0a = 0;
				nt1a = 1;
				nt2a = 0;
				nt3a = 1;

			case SS_MIRROR0:
				nt0a = 0;
				nt1a = 0;
				nt2a = 0;
				nt3a = 0;

			case SS_MIRROR1:
				nt0a = 1;
				nt1a = 1;
				nt2a = 1;
				nt3a = 1;

			case FOUR_SCREEN_MIRROR:
				nt0a = 0;
				nt1a = 1;
				nt2a = 2;
				nt3a = 3;
		}
		return mirror = m;
	}

	// this is an abstract class
	function new() {}

	public function init(cpu:CPU, ppu:PPU, rom:ROM, memory:Memory)
	{
		this.cpu = cpu;
		this.ppu = ppu;
		this.rom = rom;
		this.memory = memory;

		mirror = rom.mirror;
	}

	public function onLoad()
	{
		prgMap = new Vector(32);
		for (i in 0 ... 32)
		{
			prgMap[i] = (0x400 * i) & (rom.prgSize - 1);
		}
		chrMap = new Vector(8);
		for (i in 0 ... 8)
		{
			chrMap[i] = (0x400 * i) & (rom.chrSize - 1);
		}
	}

	public function read(addr:Int)
	{
		if (addr >= 0x8000)
		{
			return rom.prgRom.get(prgMap[((addr & 0x7fff)) >> 10] + (addr & 0x3ff)) & 0xff;
		}
		else if (addr >= 0x6000 && rom.hasPrgRam)
		{
			return rom.prgRam.get(addr & 0x1fff) & 0xff;
		}
		else return addr >> 8;
	}

	public function write(addr:Int, data:Int)
	{
		if (addr >= 0x6000 && addr < 0x8000)
		{
			var a = addr & 0x1fff;
			rom.sramDirty = rom.sramDirty || rom.prgRam[a] != data;
			rom.prgRam.set(a, data);
		}
	}

	public function ppuRead(addr:Int)
	{
		var _readResult:Int;
		if (addr < 0x2000)
		{
			_readResult = rom.chr.get(chrMap[addr >> 10] + (addr & 1023)) & 0xff;
		}
		else
		{
			switch (addr & 0xc00)
			{
				case 0:
					_readResult = nt0.get(addr & 0x3ff);

				case 0x400:
					_readResult = nt1.get(addr & 0x3ff);

				case 0x800:
					_readResult = nt2.get(addr & 0x3ff);

				default:
					if (addr >= 0x3f00)
					{
						addr &= 0x1f;
						if (addr >= 0x10 && ((addr & 3) == 0))
						{
							addr -= 0x10;
						}
						_readResult = ppu.pal.get(addr);
					}
					else
					{
						_readResult = nt3.get(addr & 0x3ff);
					}
			}
		}
		return _readResult;
	}

	public function ppuWrite(addr:Int, data:Int)
	{
		if (addr < 0x2000)
		{
			rom.chr.set(chrMap[addr >> 10] + (addr & 0x3ff), data);
		}
		else
		{
			switch (addr & 0xc00)
			{
				case 0x0:
					nt0.set(addr & 0x3ff, data);

				case 0x400:
					nt1.set(addr & 0x3ff, data);

				case 0x800:
					nt2.set(addr & 0x3ff, data);

				default:
					if (addr >= 0x3f00)
					{
						addr &= 0x1f;
						if (addr >= 0x10 && ((addr & 3) == 0))
						{
							// mirrors
							addr -= 0x10;
						}
						ppu.pal.set(addr, data & 0x3f);
					}
					else
					{
						nt3.set(addr & 0x3ff, data);
					}
			}
		}
	}

	public function onReset() {}
	public function onCpuCycle() {}
	public function onScanline(scanline:Int) {}
}
