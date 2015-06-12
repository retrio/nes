package strafe.emu.nes.mappers;

import strafe.emu.nes.Mapper;


@:build(strafe.macro.Optimizer.build())
class MMC1Mapper extends Mapper
{
	var mmc1shift:Int = 0;
	var mmc1latch:Int = 0;
	var mmc1ctrl:Int = 0xc;
	var mmc1chr0:Int = 0;
	var mmc1chr1:Int = 0;
	var mmc1prg:Int = 0;
	var soromlatch:Bool = false;

	var lastCycle:Int = 0;

	override public function onLoad()
	{
		super.onLoad();
		setBanks();
	}

	override public function write(addr:Int, data:Int)
	{
		if (addr < 0x8000 || addr > 0xffff)
		{
			super.write(addr, data);
		}
		else if (cpu.cycleCount == lastCycle)
		{
			return;
		}
		else
		{
			lastCycle = cpu.cycleCount;
			if (data & 0x80 > 0)
			{
				// reset shift register
				mmc1shift = 0;
				mmc1latch = 0;
				mmc1ctrl |= 0xc;
				setBanks();
				return;
			}

			mmc1shift += (data & 1) << mmc1latch++;
			if (mmc1latch < 5)
			{
				return; // no need to do anything
			}
			else
			{
				if (addr >= 0x8000 && addr < 0xa000)
				{
					// mmc1control
					mmc1ctrl = mmc1shift & 0x1f;

					switch (mmc1ctrl & 3)
					{
						case 0:
							mirror = SS_MIRROR0;

						case 1:
							mirror = SS_MIRROR1;

						case 2:
							mirror = V_MIRROR;

						default:
							mirror = H_MIRROR;
					}
				}
				else if (addr >= 0xa000 && addr < 0xc000)
				{
					// mmc1chr0
					mmc1chr0 = mmc1shift & 0x1f;
					if (rom.prgSize > 0x40000)
					{
						//SOROM boards use the high bit of CHR to switch between 1st and last
						//256k of the PRG ROM
						mmc1chr0 &= 0xf;
						soromlatch = Util.getbit(mmc1shift, 4);
					}
				}
				else if (addr >= 0xc000 && addr < 0xe000)
				{
					// mmc1chr1
					mmc1chr1 = mmc1shift & 0x1f;
					if (rom.prgSize > 0x40000)
					{
						mmc1chr1 &= 0xf;
					}
				}
				else if (addr >= 0xe000 && addr < 0x10000)
				{
					// mmc1prg
					mmc1prg = mmc1shift & 0xf;
				}

				setBanks();
				mmc1latch = 0;
				mmc1shift = 0;
			}
		}
	}

	inline function setBanks()
	{
		// chr bank 0
		if (Util.getbit(mmc1ctrl, 4))
		{
			// 4k bank mode
			@unroll for (i in 0 ... 4)
			{
				chrMap[i] = (0x400 * (i + 4 * mmc1chr0)) % rom.chrSize;
			}
			@unroll for (i in 0 ... 4)
			{
				chrMap[i + 4] = (0x400 * (i + 4 * mmc1chr1)) % rom.chrSize;
			}
		}
		else
		{
			// 8k bank mode
			@unroll for (i in 0 ... 8)
			{
				chrMap[i] = (0x400 * (i + 8 * (mmc1chr0 >> 1))) % rom.chrSize;
			}
		}

		// prg bank
		if (!Util.getbit(mmc1ctrl, 3))
		{
			// 32k switch
			// ignore low bank bit
			@unroll for (i in 0 ... 32)
			{
				prgMap[i] = (0x400 * i + 0x8000 * (mmc1prg >> 1)) % rom.prgSize;
			}
		}
		else if (!Util.getbit(mmc1ctrl, 2))
		{
			// fix 1st bank, 16k switch 2nd bank
			@unroll for (i in 0 ... 16)
			{
				prgMap[i] = (0x400 * i);
			}
			@unroll for (i in 0 ... 16)
			{
				prgMap[i + 16] = (0x400 * i + 0x4000 * mmc1prg) % rom.prgSize;
			}
		}
		else
		{
			// fix last bank, switch 1st bank
			@unroll for (i in 0 ... 16)
			{
				prgMap[i] = (0x400 * i + 0x4000 * mmc1prg) % rom.prgSize;
			}
			@unroll for (i in 1 ... 17)
			{
				prgMap[32 - i] = (rom.prgSize - (0x400 * i));
				if ((prgMap[32 - i]) > 0x40000)
				{
					prgMap[32 - i] -= 0x40000;
				}
			}
		}

		// if more thn 256k ROM AND SOROM latch is on
		if (soromlatch && (rom.prgSize > 0x40000))
		{
			// add 256k to all of the prg bank #s
			for (i in 0 ... prgMap.length)
			{
				prgMap[i] += 0x40000;
			}
		}
	}
}
