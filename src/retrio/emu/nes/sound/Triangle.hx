package retrio.emu.nes.sound;

import haxe.ds.Vector;


class Triangle
{
	static var dutyLookup:Vector<Int> = Vector.fromArrayCopy([
		0,  1,  2,  3,  4,  5,  6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
		15, 14, 13, 12, 11, 10, 9, 8, 7, 6,  5,  4,  3,  2,  1,  0,
	]);

	public function new() {}

	public var enabled(get, never):Bool;
	inline function get_enabled()
	{
		return period > 0 && (lengthCounterHalt || lengthCounter > 0) && linearCounter > 0;
	}

	public var register1(get, set):Int;
	inline function get_register1()
	{
		return counterReload | (lengthCounterHalt ? 0x80 : 0);
	}
	inline function set_register1(v:Int)
	{
		counterReload = v & 0x7f;
		lengthCounterHalt = Util.getbit(v, 7);
		return v;
	}

	// unused
	public var register2(get, set):Int;
	inline function get_register2()
	{
		return 0;
	}
	inline function set_register2(v:Int)
	{
		return v;
	}

	public var register3(get, set):Int;
	inline function get_register3()
	{
		return frequency & 0xff;
	}
	inline function set_register3(v:Int)
	{
		frequency = (frequency & 0x700) | v;
		return v;
	}

	public var register4(get, set):Int;
	inline function get_register4()
	{
		return ((frequency & 0x700) >> 8) | (length << 3);
	}
	inline function set_register4(v:Int)
	{
		frequency = (frequency & 0xff) | ((v & 7) << 8);
		length = (v & 0xf8) >> 3;
		linearCounter = counterReload;
		return v;
	}

	@:state var length(default, set):Int = 0;
	inline function set_length(l:Int)
	{
		lengthCounter = APU.lengthCounterTable[l];
		return length = l;
	}

	@:state var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		if (f < 8) period = 0;
		else period = 1 * (f + 1);
		return frequency = f;
	}

	@:state var amplitude:Int = 0;
	@:state var period:Int = 0;
	@:state var position:Float = 0;
	@:state var dutyPos:Int = 0;
	@:state public var lengthCounter:Int = 0;
	@:state var lengthCounterHalt:Bool = false;
	@:state var linearCounter:Int = 0;
	@:state var counterReload:Int = 0;

	public inline function lengthClock():Void
	{
		if (!lengthCounterHalt && lengthCounter > 0)
		{
			--lengthCounter;
		}
	}

	public inline function envelopeClock():Void
	{
		if (linearCounter > 0)
		{
			--linearCounter;
		}
	}

	public inline function play(rate:Float):Int
	{
		var val = 0;
		if (enabled)
		{
			if ((position += APU.NATIVE_SAMPLE_RATIO * rate) > period)
			{
				dutyPos = (dutyPos + 1) % 32;
				position -= period;
			}
			val = dutyLookup[dutyPos];
		}
		else dutyPos = 0;

		return 0;//val;
	}
}
