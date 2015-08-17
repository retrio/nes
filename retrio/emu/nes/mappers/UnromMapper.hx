package retrio.emu.nes.mappers;

import retrio.emu.nes.Mapper;


@:build(retrio.macro.Optimizer.build())
class UnromMapper extends Mapper
{
	@:state var bank:Int = 0;

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
			ppu.needCatchUp = true;

			bank = data & 0xf;
			// remap switchable 1st PRG bank
			@unroll for (i in 0 ... 16)
			{
				prgMap[i] = (0x400 * (i + 16 * bank)) & (rom.prgSize - 1);
			}
		}
	}
}
