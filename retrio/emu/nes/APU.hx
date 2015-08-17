package retrio.emu.nes;

import haxe.ds.Vector;
import retrio.audio.SoundBuffer;
import retrio.audio.LowPassFilter;
import retrio.emu.nes.sound.*;


@:build(retrio.macro.Optimizer.build())
class APU implements IState
{
	@:stateChildren static var stateChildren = ['pulse1', 'pulse2', 'triangle', 'noise', 'dmc'];

	// currently OpenFL on native, like Flash, does not support non-44100 sample rates
	public static inline var SAMPLE_RATE:Int = 44100;//#if flash 44100 #else 48000 #end;
	public static inline var NATIVE_SAMPLE_RATE:Int = Std.int(341*262*60/2);
	public static inline var NATIVE_SAMPLE_RATIO:Int = 2;
	static inline var SEQUENCER_RATE4:Int = 14915;
	static inline var SEQUENCER_RATE5:Int = 18641;
	static inline var BUFFER_LENGTH:Int = 0x8000;
	static inline var FILTER_ORDER = 63;

	public static var lengthCounterTable:Vector<Int> = Vector.fromArrayCopy([
		10,254, 20,  2, 40,  4, 80,  6, 160,  8, 60, 10, 14, 12, 26, 14,
		12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30
	]);

	public var cpu:CPU;
	public var memory:Memory;

	public var buffer:SoundBuffer;		// mono output

	var playRate:Float = 1;

	@:state var mode:Bool = false;		// true: 5 step, false: 4 step

	public var pulse1:Pulse;
	public var pulse2:Pulse;
	public var triangle:Triangle;
	public var noise:Noise;
	public var dmc:DMC;

	@:state var ch1Enabled:Bool = false;
	@:state var ch2Enabled:Bool = false;
	@:state var ch3Enabled:Bool = false;
	@:state var ch4Enabled:Bool = false;
	@:state var ch5Enabled:Bool = false;

	@:state var cycles:Int = 0;
	var sampleCounter:Int = 0;
	var sampleSync:Float = 0;
	var sampleStepSize:Float = SAMPLE_RATE * NATIVE_SAMPLE_RATIO;
	var cycleSkip:Int = NATIVE_SAMPLE_RATIO;

	// sample data for interpolation
	var s:Float = 0;
	var sPrev:Float = 0;
	var t:Null<Float> = null;

	var filter:LowPassFilter;

	public function new()
	{
		buffer = new SoundBuffer(BUFFER_LENGTH);

		pulse1 = new Pulse();
		pulse2 = new Pulse();
		pulse2.pulse2 = true;
		triangle = new Triangle();
		noise = new Noise();
		dmc = new DMC();

		filter = new LowPassFilter(Std.int(NATIVE_SAMPLE_RATE / NATIVE_SAMPLE_RATIO), SAMPLE_RATE, FILTER_ORDER);
	}

	public function init(cpu:CPU, memory:Memory)
	{
		this.cpu = cpu;
		this.memory = memory;
	}

	public function newFrame(rate:Float)
	{
		playRate = 60/rate;
		sampleStepSize = SAMPLE_RATE * NATIVE_SAMPLE_RATIO * playRate;
	}

	public inline function read(addr:Int):Int
	{
		catchUp();

		switch (addr)
		{
			case 0x4000:
				return pulse1.register1;
			case 0x4001:
				return pulse1.register2;
			case 0x4002:
				return pulse1.register3;
			case 0x4003:
				return pulse1.register4;
			case 0x4004:
				return pulse2.register1;
			case 0x4005:
				return pulse2.register2;
			case 0x4006:
				return pulse2.register3;
			case 0x4007:
				return pulse2.register4;
			case 0x4008:
				return triangle.register1;
			case 0x4009:
				return triangle.register2;
			case 0x400a:
				return triangle.register3;
			case 0x400b:
				return triangle.register4;
			case 0x400c:
				return noise.register1;
			case 0x400d:
				return noise.register2;
			case 0x400e:
				return noise.register3;
			case 0x400f:
				return noise.register4;
			case 0x4010:
				return 0;
			case 0x4011:
				return 0;
			case 0x4012:
				return 0;
			case 0x4013:
				return 0;

			case 0x4015:
				return (pulse1.lengthCounter > 0 ? 0x1 : 0) |
					(pulse2.lengthCounter > 0 ? 0x2 : 0) |
					(triangle.lengthCounter > 0 ? 0x4 : 0) |
					(noise.lengthCounter > 0 ? 0x8 : 0) |
					(dmc.lengthCounter > 0 ? 0x10 : 0);
				// TODO: I, F
			case 0x4017:
				return 0;

			default:
				return 0;
		}
	}

	public function write(addr:Int, value:Int):Void
	{
		catchUp();

		switch (addr)
		{
			case 0x4000:
				pulse1.register1 = value;
			case 0x4001:
				pulse1.register2 = value;
			case 0x4002:
				pulse1.register3 = value;
			case 0x4003:
				pulse1.register4 = value;
			case 0x4004:
				pulse2.register1 = value;
			case 0x4005:
				pulse2.register2 = value;
			case 0x4006:
				pulse2.register3 = value;
			case 0x4007:
				pulse2.register4 = value;
			case 0x4008:
				triangle.register1 = value;
			case 0x4009:
				triangle.register2 = value;
			case 0x400a:
				triangle.register3 = value;
			case 0x400b:
				triangle.register4 = value;
			case 0x400c:
				noise.register1 = value;
			case 0x400d:
				noise.register2 = value;
			case 0x400e:
				noise.register3 = value;
			case 0x400f:
				noise.register4 = value;
			case 0x4010:
			case 0x4011:
			case 0x4012:
			case 0x4013:

			case 0x4015:
				ch1Enabled = Util.getbit(value, 0);
				if (!ch1Enabled) pulse1.lengthCounter = 0;
				ch2Enabled = Util.getbit(value, 1);
				if (!ch2Enabled) pulse2.lengthCounter = 0;
				ch3Enabled = Util.getbit(value, 2);
				if (!ch3Enabled) triangle.lengthCounter = 0;
				ch4Enabled = Util.getbit(value, 3);
				if (!ch4Enabled) noise.lengthCounter = 0;
				ch5Enabled = Util.getbit(value, 4);
				if (!ch5Enabled) dmc.lengthCounter = 0;
			case 0x4017:

			default:
		}
	}

	public function catchUp()
	{
		while (cpu.apuCycles > 1)
		{
			var runTo = Std.int(Math.min(predict(), Math.floor(cpu.apuCycles/2)));
			cpu.apuCycles -= runTo * 2;
			for (i in 0 ... runTo)
			{
				generateSample();
				generateSample();
				generateSample();
			}
			subCycles -= runTo * 4;
			while (subCycles < 0)
			{
				runCycle();
				subCycles += mode ? SEQUENCER_RATE5 : SEQUENCER_RATE4;
			}
		}
	}

	inline function predict()
	{
		return Std.int(Math.max(subCycles, 1));
	}

	var subCycles:Int = 0;
	inline function runCycle()
	{
		if (mode)
		{
			// 5 step
			switch (cycles++)
			{
				case 0:
					lengthClock();
					envelopeClock();
				case 1:
					envelopeClock();
				case 2:
					lengthClock();
					envelopeClock();
				case 3:
					envelopeClock();
				case 4: {}
			}
			cycles %= 5;
		}
		else
		{
			switch (cycles++)
			{
				case 0:
					envelopeClock();
				case 1:
					lengthClock();
					envelopeClock();
				case 2:
					envelopeClock();
				case 3:
					lengthClock();
					envelopeClock();
					//irq();
			}
			cycles %= 4;
		}
	}

	inline function lengthClock()
	{
		pulse1.lengthClock();
		pulse2.lengthClock();
		triangle.lengthClock();
		noise.lengthClock();
		//dmc.lengthClock();
	}

	inline function envelopeClock()
	{
		pulse1.envelopeClock();
		pulse2.envelopeClock();
		triangle.envelopeClock();
		noise.envelopeClock();
		//dmc.envelopeClock();
	}

	var _samples:Vector<Int> = new Vector(4);
	inline function generateSample()
	{
		if (++sampleCounter >= cycleSkip)
		{
			sampleCounter -= cycleSkip;
			sampleSync += sampleStepSize;

			getSoundOut();
			filter.addSample(s);

			if (NATIVE_SAMPLE_RATE - sampleSync < sampleStepSize)
			{
				if (t == null)
				{
					sPrev = filter.getSample();
					t = (NATIVE_SAMPLE_RATE - sampleSync) / (sampleStepSize);
				}
				else
				{
					buffer.push(Util.lerp(sPrev, filter.getSample(), t));

					sampleSync -= NATIVE_SAMPLE_RATE;
					t = null;
				}
			}
		}
	}

	inline function getSoundOut()
	{
		var p1 = ch1Enabled ? pulse1.play(playRate) : 0;
		var p2 = ch2Enabled ? pulse2.play(playRate) : 0;
		var s1 = ch3Enabled ? triangle.play(playRate) : 0;
		var s2 = ch4Enabled ? noise.play(playRate) : 0;
		var s3 = ch5Enabled ? 0 : 0;//dmc.play();
		s = 0;
		if (p1 + p2 != 0) s += 95.88 / ((8128 / (p1 + p2)) + 100);
		if (s1 + s2 + s3 != 0) s += 159.79 / ((1 / (s1/8227 + s2/12241 + s3/22638)) + 100);
	}
}
