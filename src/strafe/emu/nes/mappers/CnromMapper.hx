package strafe.emu.nes.mappers;

import strafe.emu.nes.Mapper;


@:build(strafe.macro.Optimizer.build())
class CnromMapper extends Mapper
{
	override public function write(addr:Int, data:Int)
	{
		if (addr < 0x8000 || addr > 0xffff)
		{
			super.write(addr, data);
		}
		else
		{
			@unroll for (i in 0 ... 8)
			{
				chrMap[i] = (1024 * (i + 8 * (data & 0xff))) & (rom.chrSize - 1);
			}
		}
	}
}
