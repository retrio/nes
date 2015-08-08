package retrio.emu.nes;

import haxe.ds.Vector;
import haxe.io.BytesInput;
import haxe.io.Output;


class NES implements IEmulator implements IState
{
	@:stateVersion static var stateVersion = 1;
	@:stateChildren static var stateChildren = ['cpu', 'ram', 'rom', 'ppu', 'apu', 'mapper'];

	public static inline var WIDTH = 256;
	public static inline var HEIGHT = 224;
	// minimum # of frames to wait between saves
	public static inline var SRAM_SAVE_FRAMES = 60;

	public var width:Int = WIDTH;
	public var height:Int = HEIGHT;

	public var io:IEnvironment;
	public var buffer:ByteString;
	public var extensions:Array<String> = ["*.nes"];

	// hardware components
	public var cpu:CPU;
	public var ram:Memory;
	public var rom:ROM;
	public var ppu:PPU;
	public var apu:APU;
	public var mapper:Mapper;
	public var controllers:Vector<NESController> = new Vector(2);

	var _saveCounter:Int = 0;
	@:state var romName:String;
	@:state var useSram:Bool = true;

	public function new() {}

	public function loadGame(gameData:FileWrapper, ?useSram:Bool=true)
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

		romName = gameData.name;
		this.useSram = useSram;
		if (useSram) loadSram();
	}

	public function reset():Void
	{
		cpu.reset(this);
	}

	var _time:Float = 0;
	public function frame()
	{
		var _newTime = haxe.Timer.stamp();
		var elapsed = _newTime - _time;
		_time = _newTime;
		apu.newFrame(Math.ceil(1/elapsed));
		cpu.runFrame();
		if (rom.sramDirty)
		{
			if (_saveCounter < SRAM_SAVE_FRAMES)
			{
				++_saveCounter;
			}
			else
			{
				saveSram();
			}
		}
		else _saveCounter = 0;
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

	public function savePersistentState(slot:SaveSlot):Void
	{
		if (io != null)
		{
			var state = saveState();
			io.writeBytesToFile(romName + ".st" + slot, state);
		}
	}

	public function loadPersistentState(slot:SaveSlot):Void
	{
		if (io != null)
		{
			var stateFile = io.readFile(romName + ".st" + slot);
			if (stateFile == null) throw "State " + slot + " does not exist";
			var input = new BytesInput(stateFile.readAll());
			loadState(input);
		}
	}

	function saveSram()
	{
		if (useSram && rom.hasSram && rom.sramDirty && io != null)
		{
			var data = rom.prgRam;
			io.writeByteStringToFile(romName + ".srm", data);
			rom.sramDirty = false;
			_saveCounter = 0;
		}
	}

	function loadSram()
	{
		if (useSram && io.fileExists(romName + ".srm"))
		{
			var file = io.readFile(romName + ".srm");
			if (file != null)
			{
				rom.prgRam.readFrom(file);
				rom.sramDirty = false;
			}
		}
	}
}
