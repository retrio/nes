package strafe.emu.nes.mappers;

import strafe.emu.nes.Mapper;


@:build(strafe.macro.Optimizer.build())
class AoromMapper extends Mapper
{
	var bank:Int = 0;

	override public function onLoad()
	{
		super.onLoad();

		for (i in 1 ... 17)
		{
			// fixed bank
			prgMap[32-i] = rom.prgSize - (0x400 * i);
		}
	}

	override public function write(addr:Int, data:Int)
	{
		if (addr < 0x8000 || addr > 0xffff)
		{
			super.write(addr, data);
		}
		else
		{
			//remap all 32k of PRG to 32 x bank #
			@unroll for (i in 0 ... 32)
			{
				prgMap[i] = (1024 * (i + (32 * (data & 15)))) & (rom.prgSize - 1);
			}
			mirror = Util.getbit(data, 4) ? SS_MIRROR1 : SS_MIRROR0;
		}
	}
}
