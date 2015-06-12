package strafe.emu.nes;

import haxe.io.Bytes;
import haxe.ds.Vector;
import haxe.io.Input;
import strafe.ByteString;
import strafe.FileWrapper;


class ROM implements IState
{
	public var mapper:Mapper;
	public var mirror:MirrorMode;

	public var prgRom:ByteString;
	public var prgRam:ByteString;
	public var chr:ByteString;				// ROM or RAM

	public var prgSize:Int = 0;				// size of PRG ROM (# of 0x4000 blocks)
	public var chrSize:Int = 0;				// size of CHR ROM (# of 0x2000 blocks)

	public var hasPrgRam:Bool = true;
	public var hasChrRam:Bool = false;
	public var saveRam:Bool = false;

	var mapperNumber:Int=0;

	public function new(file:FileWrapper, ram:RAM)
	{
		var pos = 0;

		// check for "NES" at beginning of header
		var firstWord = file.readString(3);
		if (firstWord != "NES" || file.readByte() != 0x1A)
		{
			throw "Not in iNES format";
		}
		prgSize = file.readByte() * 0x4000;
		if (prgSize == 0)
			throw "No PRG ROM size in header";
		chrSize = file.readByte() * 0x2000;
		var f6 = file.readByte();
		var f7 = file.readByte();

		var fourScreenMirror = Util.getbit(f6, 3);
		var verticalMirror = Util.getbit(f6, 0);
		mirror = fourScreenMirror ? FOUR_SCREEN_MIRROR
			: verticalMirror ? V_MIRROR : H_MIRROR;

		saveRam = Util.getbit(f6, 1);

		//prgRamSize = file.readByte() * 0x2000;

		prgRom = new ByteString(prgSize);
		prgRam = new ByteString(0x2000);
		prgRam.fillWith(0);

		mapperNumber = (f6 >> 4);// + f7 & 0xF0;
		mapper = Mapper.getMapper(mapperNumber);

		for (i in 0...8) file.readByte();

		prgRom.readFrom(new haxe.io.BytesInput(file.readBytes(prgSize)));

		if (chrSize > 0)
		{
			chr = new ByteString(chrSize);
			chr.readFrom(file);
		}
		else
		{
			hasChrRam = true;
			chrSize = 0x2000;
			chr = new ByteString(chrSize);
			chr.fillWith(0);
		}
	}

	public function writeState(out:haxe.io.Output)
	{
		// TODO
	}
}
