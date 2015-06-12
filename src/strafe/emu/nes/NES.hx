package strafe.emu.nes;

import haxe.ds.Vector;
import haxe.io.Output;
import strafe.FileWrapper;
import strafe.IController;
import strafe.emu.nes.CPU;
import strafe.emu.nes.PPU;
import strafe.emu.nes.ROM;


class NES implements IEmulator implements IState
{
	// hardware components
	public var rom:ROM;
	public var ram:RAM;
	public var cpu:CPU;
	public var ppu:PPU;
	public var apu:APU;
	public var mapper:Mapper;
	public var controllers:Vector<NESController> = new Vector(2);

	public function new() {}

	public function loadGame(gameData:FileWrapper)
	{
		ram = new RAM();

		rom = new ROM(gameData, ram);
		mapper = rom.mapper;

		cpu = new CPU(ram);
		ppu = new PPU(mapper, cpu);
		apu = new APU();

		ram.init(mapper, ppu, apu, controllers);
		mapper.init(cpu, ppu, rom, ram);
		mapper.onLoad();
		cpu.init(ppu);
		apu.init(cpu, ram);
	}

	public function reset():Void
	{
		cpu.reset();
	}

	public function frame()
	{
		ppu.runFrame();
	}

	public function addController(controller:IController, ?port:Int=null):Null<Int>
	{
		if (port == null)
		{
			for (i in 0 ... controllers.length)
			{
				if (controllers[i] == null)
				{
					port = i;
					break;
				}
			}
			if (port == null) return null;
		}
		else
		{
			if (controllers[port] != null) return null;
		}

		controllers[port] = new NESController(controller);
		controller.init(this);

		return port;
	}

	public function writeState(out:Output)
	{
		rom.writeState(out);
		mapper.writeState(out);
		ram.writeState(out);
		cpu.writeState(out);
		ppu.writeState(out);
	}


}
