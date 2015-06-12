package strafe.emu.nes.mappers;

import haxe.ds.Vector;
import strafe.emu.nes.Mapper;


@:build(strafe.macro.Optimizer.build())
class MMC3Mapper extends Mapper
{
	var bank = 0;
	var prgConfig = false;
	var chrConfig = false;
	var irqCtrReload = 0;
	var irqCtr = 0;
	var irqEnable = false;
	var irqReload = false;
	var bank6 = 0;
	var chrReg:Vector<Int> = new Vector(6);
	var interrupted = false;

	var lastA12 = false;
	var a12timer = 0;

	override public function onLoad()
	{
		//needs to be in every mapper. Fill with initial cfg
		super.onLoad();
		for (i in 1 ... 33)
		{
			prgMap[32 - i] = rom.prgSize - (0x400 * i);
		}

		for (i in 0 ... 8)
		{
			chrMap[i] = 0;
		}

		for (i in 0 ... chrReg.length)
			chrReg[i] = 0;

		setBank6();
	}

	override public function write(addr:Int, data:Int)
	{
		if (addr < 0x8000 || addr > 0xffff)
		{
			super.write(addr, data);
		}
		else
		{
			// bank switch
			if (Util.getbit(addr, 0))
			{
				// odd registers
				if ((addr >= 0x8000) && (addr < 0xa000)) {
					if (bank <= 5)
					{
						chrReg[bank] = data;
						setupChr();
					}
					else if (bank == 6)
					{
						bank6 = data;
						setBank6();
					}
					else if (bank == 7)
					{
						@unroll for (i in 0 ... 8)
						{
							prgMap[i + 8] = (0x400 * (i + (data * 8))) % rom.prgSize;
						}
					}
				}
				else if ((addr >= 0xa000) && (addr < 0xc000))
				{
					// prg ram write protect
					// TODO
				}
				else if ((addr >= 0xc000) && (addr < 0xe000))
				{
					irqReload = true;
				}
				else if ((addr >= 0xe000) && (addr < 0x10000))
				{
					irqEnable = true;
				}
			}
			else
			{
				// even registers
				if ((addr >= 0x8000) && (addr < 0xa000))
				{
					bank = data & 7;
					prgConfig = Util.getbit(data, 6);
					chrConfig = Util.getbit(data, 7);
					setupChr();
					setBank6();
				}
				else if ((addr >= 0xA000) && (addr < 0xc000))
				{
					if (mirror != FOUR_SCREEN_MIRROR)
					{
						mirror = Util.getbit(data, 0) ? H_MIRROR : V_MIRROR;
					}
				}
				else if ((addr >= 0xc000) && (addr < 0xe000))
				{
					irqCtrReload = data;
				}
				else if ((addr >= 0xe000) && (addr < 0x10000))
				{
					if (interrupted)
					{
						--cpu.interrupt;
					}
					interrupted = false;
					irqEnable = false;
				}
			}
		}
	}

	inline function setupChr()
	{
		if (chrConfig)
		{
			setPpuBank(1, 0, chrReg[2]);
			setPpuBank(1, 1, chrReg[3]);
			setPpuBank(1, 2, chrReg[4]);
			setPpuBank(1, 3, chrReg[5]);
			// ignore low bit for 2k banks
			setPpuBank(2, 4, chrReg[0] & 0xfe);
			setPpuBank(2, 6, chrReg[1] & 0xfe);
		}
		else
		{
			setPpuBank(1, 4, chrReg[2]);
			setPpuBank(1, 5, chrReg[3]);
			setPpuBank(1, 6, chrReg[4]);
			setPpuBank(1, 7, chrReg[5]);
			// ignore low bit for 2k banks
			setPpuBank(2, 0, chrReg[0] & 0xfe);
			setPpuBank(2, 2, chrReg[1] & 0xfe);
		}
	}

	inline function setBank6()
	{
		if (!prgConfig)
		{
			// map c000-dfff to last bank, 8000-9fff to selected bank
			@unroll for (i in 0 ... 8)
			{
				prgMap[i] = (0x400 * (i + (bank6 * 8))) % rom.prgSize;
				prgMap[i + 16] = ((rom.prgSize - 0x4000) + 0x400 * i);
			}
		}
		else
		{
			// map 8000-9fff to last bank, c000 to dfff to selected bank
			@unroll for (i in 0 ... 8)
			{
				prgMap[i] = ((rom.prgSize - 0x4000) + 0x400 * i);
				prgMap[i + 16] = (0x400 * (i + (bank6 * 8))) % rom.prgSize;
			}
		}
	}

	function checkA12(addr:Int)
	{
		//run on every PPU cycle (wasteful...)
		//clocks scanline counter every time A12 line goes from low to high
		//on PPU address bus, _except_ when it has been less than 8 PPU cycles
		//since the line last went low.
		var a12 = Util.getbit(addr, 12);
		if (a12 && (!lastA12))
		{
			//rising edge
			if ((a12timer <= 0))
			{
				clockScanCounter();
			}
		}
		else if (!a12 && lastA12)
		{
			//falling edge
			a12timer = 8;
		}

		--a12timer;
		lastA12 = a12;
	}

	inline function clockScanCounter()
	{
		if (irqReload || (irqCtr == 0))
		{
			irqCtr = irqCtrReload;
			irqReload = false;
		}
		else
		{
			--irqCtr;
		}
		if ((irqCtr == 0) && irqEnable)
		{
			if (!interrupted)
			{
				++cpu.interrupt;
				interrupted = true;
			}
		}

	}

	inline function setPpuBank(bankSize:Int, bankPos:Int, bankNum:Int)
	{
		for (i in 0 ... bankSize)
		{
			chrMap[i + bankPos] = (0x400 * ((bankNum) + i)) % rom.chrSize;
		}
	}

	/*public function onScanline(scanline:Int)
	{
		checkA12();
	}*/
}
