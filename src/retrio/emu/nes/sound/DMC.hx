package retrio.emu.nes.sound;

import haxe.ds.Vector;


class DMC
{
	static var frequencyPeriods:Vector<Int> = Vector.fromArrayCopy([
		4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068
	]);
	static var noise:Vector<Bool>;

	public function new()
	{
		noise = new Vector(0x8000);
		for (i in 0 ... noise.length)
		{
			noise[i] = Math.random() > 0.5;
		}
	}

	public var enabled(get, never):Bool;
	inline function get_enabled()
	{
		return period > 0 && (lengthCounterHalt || lengthCounter > 0) && frequency >= 8 && frequency <= 0x7ff;
	}

	public var register1(get, set):Int;
	inline function get_register1()
	{
		return volume | (constantVolume ? 0x10 : 0) | (lengthCounterHalt ? 0x20 : 0);
	}
	inline function set_register1(v:Int)
	{
		envelopeDiv = amplitude = volume = v & 0xf;
		envelopeCounter = 0xf;
		constantVolume = Util.getbit(v, 4);
		lengthCounterHalt = Util.getbit(v, 5);
		return v;
	}

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
		return frequency;
	}
	inline function set_register3(v:Int)
	{
		loopNoise = Util.getbit(v, 7);
		frequency = v & 0xf;
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
		return v;
	}

	@:state var length(default, set):Int = 0;
	inline function set_length(l:Int)
	{
		lengthCounter = APU.lengthCounterTable[l];
		envelopeCounter = volume;
		return length = l;
	}

	@:state var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		period = 4 * frequencyPeriods[f];
		return frequency = f;
	}

	@:state var volume:Int = 0;
	@:state var envelopeCounter:Int = 0;
	@:state var envelopeDiv:Int = 0;
	@:state var loopNoise:Bool = false;

	@:state var amplitude:Int = 0;
	@:state var period:Int = 0;
	@:state var position:Int = 0;
	@:state var noisePos:Int = 0;
	@:state public var lengthCounter:Int = 0;
	@:state var constantVolume:Bool = false;
	@:state var lengthCounterHalt:Bool = false;

	public inline function envelopeClock():Void
	{
		if (envelopeDiv > 0)
		{
			if (--envelopeDiv == 0 && envelopeCounter > 0)
			{
				envelopeDiv = volume;
				amplitude = constantVolume ? volume : envelopeCounter;
				if (--envelopeCounter == 0 && lengthCounterHalt)
					envelopeCounter = 0xf;
			}
		}
	}

	public inline function lengthClock():Void
	{
		if (!lengthCounterHalt && lengthCounter > 0)
			lengthCounter -= 1;
	}

	public inline function play():Int
	{
		var val = 0;
		if (enabled)
		{
			if ((position += APU.NATIVE_SAMPLE_RATIO) > period)
			{
				noisePos = (noisePos + 1) % (loopNoise ? 0x60 : noise.length);
				position -= period;
			}
			val = noise[noisePos] ? amplitude : 0;
		}

		return val;
	}
}
