package strafe.emu.nes;

import haxe.ds.Vector;
import strafe.ByteString;
import strafe.emu.nes.mappers.*;


class Mapper implements IState
{
	public static function getMapper(mapperNumber:Int):Mapper
	{
		// TODO: replace this with a macro
		return switch (mapperNumber)
		{
			case 0: new NromMapper();
			case 1: new MMC1Mapper();
			case 2: new UnromMapper();
			case 3: new CnromMapper();
			case 4: new MMC3Mapper();
			case 7: new AoromMapper();
			default: throw ("Mapper " + mapperNumber + " is not implemented yet.");
		}
	}

	public var rom:ROM;
	public var ram:RAM;
	public var cpu:CPU;
	public var ppu:PPU;

	// nametable pointers
	public var nt0:ByteString;
	public var nt1:ByteString;
	public var nt2:ByteString;
	public var nt3:ByteString;

	public var prgMap:Vector<Int>;
	public var chrMap:Vector<Int>;

	public var mirror(default, set):MirrorMode;
	function set_mirror(m:MirrorMode)
	{
		switch(m)
		{
			case H_MIRROR:
				nt0 = ppu.t0;
				nt1 = ppu.t0;
				nt2 = ppu.t1;
				nt3 = ppu.t1;
				//trace("h");

			case V_MIRROR:
				nt0 = ppu.t0;
				nt1 = ppu.t1;
				nt2 = ppu.t0;
				nt3 = ppu.t1;
				//trace("v");

			case SS_MIRROR0:
				nt0 = ppu.t0;
				nt1 = ppu.t0;
				nt2 = ppu.t0;
				nt3 = ppu.t0;
				//trace("ss0");

			case SS_MIRROR1:
				nt0 = ppu.t1;
				nt1 = ppu.t1;
				nt2 = ppu.t1;
				nt3 = ppu.t1;
				//trace("ss1");

			case FOUR_SCREEN_MIRROR:
				nt0 = ppu.t0;
				nt1 = ppu.t1;
				nt2 = ppu.t2;
				nt3 = ppu.t3;
				//trace("4s");
		}
		return mirror = m;
	}

	// this is an abstract class
	function new() {}

	public function init(cpu:CPU, ppu:PPU, rom:ROM, ram:RAM)
	{
		this.cpu = cpu;
		this.ppu = ppu;
		this.rom = rom;
		this.ram = ram;

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

	public inline function read(addr:Int)
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
			rom.prgRam.set(addr & 0x1fff, data);
		}
	}

	var _readResult:Int;
	public inline function ppuRead(addr:Int)
	{
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

	public inline function ppuWrite(addr:Int, data:Int)
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

	public function writeState(out:haxe.io.Output)
	{
		// TODO
	}
}
