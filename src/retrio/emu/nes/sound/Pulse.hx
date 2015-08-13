package retrio.emu.nes.sound;

import haxe.ds.Vector;


class Pulse
{
	static var dutyLookup:Vector<Vector<Bool>> = Vector.fromArrayCopy([
		Vector.fromArrayCopy([	false,	true,	false,	false,	false,	false,	false,	false,	]),
		Vector.fromArrayCopy([	false,	true,	true,	false,	false,	false,	false,	false,	]),
		Vector.fromArrayCopy([	false,	true,	true,	true,	true,	false,	false,	false,	]),
		Vector.fromArrayCopy([	true,	false,	false,	true,	true,	true,	true,	true,	]),
	]);

	@:state public var pulse2:Bool = false;

	public function new() {}

	public var enabled(get, never):Bool;
	inline function get_enabled()
	{
		return period > 0 && (lengthCounterHalt || lengthCounter > 0) && frequency >= 8 && frequency <= 0x7ff;
	}

	public var register1(get, set):Int;
	inline function get_register1()
	{
		return volume | (constantVolume ? 0x10 : 0) | (lengthCounterHalt ? 0x20 : 0) | (duty << 6);
	}
	inline function set_register1(v:Int)
	{
		envelopeDiv = amplitude = volume = v & 0xf;
		envelopeCounter = 0xf;
		constantVolume = Util.getbit(v, 4);
		lengthCounterHalt = Util.getbit(v, 5);
		duty = (v & 0xc0) >> 6;
		return v;
	}

	public var register2(get, set):Int;
	inline function get_register2()
	{
		return sweepShift | (sweepNegate ? 0x8 : 0) | (sweepPeriod << 4) | (sweepEnabled ? 0x80 : 0);
	}
	inline function set_register2(v:Int)
	{
		sweepShift = v & 0x7;
		sweepNegate = Util.getbit(v, 3);
		sweepCounter = (sweepPeriod = (v >> 4) & 0x7) + 1;
		sweepEnabled = Util.getbit(v, 7);
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
		if (f < 8) period = 0;
		else period = 4 * (f + 1);
		return frequency = f;
	}

	@:state var duty(default, set):Int = 0;
	inline function set_duty(d:Int)
	{
		cachedDuty = dutyLookup[d];
		return duty = d;
	}

	@:state var sweepEnabled:Bool = false;
	@:state var sweepPeriod:Int = 0;
	@:state var sweepShift:Int = 0;
	@:state var sweepNegate:Bool = false;
	@:state var sweepCounter:Int = 0;

	@:state var cachedDuty:Vector<Bool> = dutyLookup[0];
	@:state var volume:Int = 0;
	@:state var envelopeCounter:Int = 0;
	@:state var envelopeDiv:Int = 0;

	@:state var amplitude:Int = 0;
	@:state var period:Int = 0;
	@:state var position:Float = 0;
	@:state var dutyPos:Int = 0;
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
			lengthCounter -= 2;

		if (sweepEnabled && enabled)
		{
			if (--sweepCounter <= 0)
			{
				frequency = frequency + (frequency >> sweepShift) * (sweepNegate ? -1 : 1);
				sweepCounter += (sweepPeriod + 1);
			}
		}
	}

	public inline function play(rate:Float):Int
	{
		var val = 0;
		if (enabled)
		{
			if ((position += APU.NATIVE_SAMPLE_RATIO * rate) > period)
			{
				dutyPos = (dutyPos + 1) % 8;
				position -= period;
			}
			val = cachedDuty[dutyPos] ? amplitude : 0;
		}

		return val;
	}
}
