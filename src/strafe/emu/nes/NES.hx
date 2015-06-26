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
	public static inline var WIDTH = 256;
	public static inline var HEIGHT = 240;

	public var width:Int = WIDTH;
	public var height:Int = HEIGHT;

	public var buffer:ByteString;
	public var extensions:Array<String> = ["*.nes"];

	// hardware components
	public var rom:ROM;
	public var ram:Memory;
	public var cpu:CPU;
	public var ppu:PPU;
	public var apu:APU;
	public var mapper:Mapper;
	public var controllers:Vector<NESController> = new Vector(2);

	public function new() {}

	public function loadGame(gameData:FileWrapper)
	{
		ram = new Memory();

		rom = new ROM(gameData, ram);
		mapper = rom.mapper;

		cpu = new CPU(ram);
		ppu = new PPU(mapper, cpu);
		apu = new APU();

		ram.init(mapper, ppu, apu, controllers);
		mapper.init(cpu, ppu, rom, ram);
		mapper.onLoad();
		apu.init(cpu, ram);
		cpu.init(this, ppu);

		buffer = ppu.screenBuffer;
	}

	public function reset():Void
	{
		cpu.reset(this);
	}

	public function frame()
	{
		cpu.runFrame();
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

	public function getColor(c:Int)
	{
		return Palette.getColor(c);
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
