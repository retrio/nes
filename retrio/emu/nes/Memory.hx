package retrio.emu.nes;

import haxe.ds.Vector;
import retrio.ByteString;


class Memory implements IState
{
	@:state public var ram:ByteString = new ByteString(0x800);
	public var mapper:Mapper;
	public var ppu:PPU;
	public var apu:APU;

	public var controllers:Vector<NESController>;

	@:state public var dmaCounter:Int = 0;

	public function new() {}

	public function init(mapper:Mapper, ppu:PPU, apu:APU, controllers:Vector<NESController>)
	{
		ram.fillWith(0xff);
		this.mapper = mapper;
		this.ppu = ppu;
		this.apu = apu;
		this.controllers = controllers;
	}

	public function read(addr:Int):Int
	{
		if (addr < 0x2000)
		{
			// RAM
			return ram.get(addr & 0x7ff);
		}
		else if (addr > 0x4018)
		{
			// cartridge space
			return mapper.read(addr);
		}
		else if (addr < 0x4000)
		{
			// ppu, mirrored 7 bytes of io registers
			return ppu.read(addr & 7);
		}
		else if (addr == 0x4016 || addr == 0x4017)
		{
			// controller read
			var port = addr - 0x4016;
			return controllers[port] == null ? 0 : controllers[port].pop();
		}
		else if (addr >= 0x4000 && addr <= 0x4018)
		{
			// APU registers
			return apu.read(addr);
		}
		else
		{
			throw "Bad address: " + StringTools.hex(addr);
		}
	}

	public function write(addr:Int, data:Int)
	{
		if (addr < 0x2000)
		{
			// write to RAM (mirrored)
			ram.set(addr & 0x7ff, data);
		}
		else if (addr > 0x4018)
		{
			// cartridge space
			mapper.write(addr, data);
		}
		else if (addr < 0x4000)
		{
			// ppu, mirrored 7 bytes of io registers
			ppu.write(addr & 7, data);
		}
		else if (addr == 0x4014)
		{
			// sprite DMA
			dma(data);
		}
		else if (addr == 0x4016)
		{
			// controller latch
			for (controller in controllers)
				if (controller != null) controller.latch();
		}
		else if (addr >= 0x4000 && addr <= 0x4018)
		{
			apu.write(addr, data);
		}
	}

	inline function dma(data:Int)
	{
		var start = (data << 8);
		var i = start;
		while (i < start + 256)
		{
			// shortcut, written to 0x2004
			ppu.write(4, read((i++) & 0xffff) & 0xff);
		}
		dmaCounter = 2;
	}
}
