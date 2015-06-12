package strafe.emu.nes;

import haxe.ds.Vector;


class APU
{
	public var cpu:CPU;
	public var ram:RAM;

	public var cycles:Int = 0;

	var statusFrameInt:Bool = false;
	var statusDmcInt:Bool = false;
	var dmcSamplesLeft:Int = 0;
	var lengthCtrl:Vector<Int> = new Vector(4);
	var remainder:Int = 0;
	var frameCtrDiv:Int = 7456;
	var cyclesPerSample:Float = 0;
	var linearCtr:Int = 0;
	//var timers:Vector<Timer> = new Vector(4);

	public function new() {}

	public function init(cpu:CPU, ram:RAM)
	{
		this.cpu = cpu;
		this.ram = ram;

		for (i in 0 ... lengthCtrl.length) lengthCtrl[i] = 0;

		var sampleRate = 44100;
		cyclesPerSample = 1789773.0 / sampleRate;
	}

	public function read(addr:Int):Int
	{
		//updateto(cpu.cycles);
		return 0;
		/*switch (addr - 0x4000)
		{
			case 0x15:
				// channel status
				var val = ((lengthCtrl[0] > 0) ? 1 : 0)
						+ ((lengthCtrl[1] > 0) ? 2 : 0)
						+ ((lengthCtrl[2] > 0) ? 4 : 0)
						+ ((lengthCtrl[3] > 0) ? 8 : 0)
						+ ((dmcSamplesLeft > 0) ? 16 : 0)
						+ (statusFrameInt ? 64 : 0)
						+ (statusDmcInt ? 128 : 0);

				if (statusFrameInt)
				{
					--cpu.interrupt;
					statusFrameInt = false;
				}

				return val;

			default:
				return 0x40; //open bus
		}*/
	}

	public function write(addr:Int, data:Int)
	{
		updateto(cpu.cycles - 1);

		/*switch (addr - 0x4000)
		{
			case 0x0:
				//length counter 1 halt
				lenctrHalt[0] = utils.getbit(data, 5);
				// pulse 1 duty cycle
				timers[0].setduty(dutylookup[data >> 6]);
				// and envelope
				envConstVolume[0] = utils.getbit(data, 4);
				envelopeValue[0] = data & 15;
				//setvolumes();

			case 0x1:
				//pulse 1 sweep setup
				//sweep enabled
				sweepenable[0] = utils.getbit(data, 7);
				//sweep divider period
				sweepperiod[0] = (data >> 4) & 7;
				//sweep negate flag
				sweepnegate[0] = utils.getbit(data, 3);
				//sweep shift count
				sweepshift[0] = (data & 7);
				sweepreload[0] = true;

			case 0x2:
				// pulse 1 timer low bit
				timers[0].setperiod((timers[0].getperiod() & 0xfe00) + (data << 1));

			case 0x3:
				// length counter load, timer 1 high bits
				if (lenCtrEnable[0]) {
					lengthCtrl[0] = lenctrload[data >> 3];
				}
				timers[0].setperiod((timers[0].getperiod() & 0x1ff) + ((data & 7) << 9));
				// sequencer restarted
				timers[0].reset();
				//envelope also restarted
				envelopeStartFlag[0] = true;

			case 0x4:
				//length counter 2 halt
				lenctrHalt[1] = utils.getbit(data, 5);
				// pulse 2 duty cycle
				timers[1].setduty(dutylookup[data >> 6]);
				// and envelope
				envConstVolume[1] = utils.getbit(data, 4);
				envelopeValue[1] = data & 15;
				//setvolumes();

			case 0x5:
				//pulse 2 sweep setup
				//sweep enabled
				sweepenable[1] = utils.getbit(data, 7);
				//sweep divider period
				sweepperiod[1] = (data >> 4) & 7;
				//sweep negate flag
				sweepnegate[1] = utils.getbit(data, 3);
				//sweep shift count
				sweepshift[1] = (data & 7);
				sweepreload[1] = true;

			case 0x6:
				// pulse 2 timer low bit
				timers[1].setperiod((timers[1].getperiod() & 0xfe00) + (data << 1));

			case 0x7:
				if (lenCtrEnable[1]) {
					lengthCtrl[1] = lenctrload[data >> 3];
				}
				timers[1].setperiod((timers[1].getperiod() & 0x1ff) + ((data & 7) << 9));
				// sequencer restarted
				timers[1].reset();
				//envelope also restarted
				envelopeStartFlag[1] = true;

			case 0x8:
				//triangle linear counter load
				linctrreload = data & 0x7f;
				//and length counter halt
				lenctrHalt[2] = utils.getbit(data, 7);

			case 0xA:
				// triangle low bits of timer
				timers[2].setperiod((((timers[2].getperiod() * 1) & 0xff00) + data));

			case 0xB:
				// triangle length counter load
				// and high bits of timer
				if (lenCtrEnable[2]) {
					lengthCtrl[2] = lenctrload[data >> 3];
				}
				timers[2].setperiod((((timers[2].getperiod() * 1) & 0xff) + ((data & 7) << 8)));
				linctrflag = true;

			case 0xC:
				//noise halt and envelope
				lenctrHalt[3] = utils.getbit(data, 5);
				envConstVolume[3] = utils.getbit(data, 4);
				envelopeValue[3] = data & 0xf;
				//setvolumes();

			case 0xE:
				timers[3].setduty(utils.getbit(data, 7) ? 6 : 1);
				timers[3].setperiod(noiseperiod[data & 15]);

			case 0xF:
				//noise length counter load, envelope restart
				if (lenCtrEnable[3]) {
					lengthCtrl[3] = lenctrload[data >> 3];
				}
				envelopeStartFlag[3] = true;

			case 0x10:
				dmcirq = utils.getbit(data, 7);
				dmcloop = utils.getbit(data, 6);
				dmcrate = dmcperiods[data & 0xf];
				if (!dmcirq && statusDmcInt) {
					--cpu.interrupt;
					statusDmcInt = false;
				}
				//System.err.println(dmcirq ? "dmc irq on" : "dmc irq off");

			case 0x11:
				dmcvalue = data & 0x7f;

			case 0x12:
				dmcstartaddr = (data << 6) + 0xc000;

			case 0x13:
				dmcsamplelength = (data << 4) + 1;

			case 0x14:
				//sprite dma
				for (int i = 0; i < 256; ++i) {
					cpuram.write(0x2004, cpuram.read((data << 8) + i));
				}
				//account for time stolen from cpu
				sprdma_count = 2;

			case 0x15:
				//status register
				// counter enable(silence channel when bit is off)
				for (int i = 0; i < 4; ++i) {
					lenCtrEnable[i] = utils.getbit(data, i);
					//THIS was the channels not cutting off bug! If you toggle a channel's
					//status on and off very quickly then the length counter should
					//IMMEDIATELY be forced to zero.
					if (!lenCtrEnable[i]) {
						lengthCtrl[i] = 0;
					}
				}
				if (utils.getbit(data, 4)) {
					if (dmcSamplesLeft == 0) {
						restartdmc();
					}
				} else {
					dmcSamplesLeft = 0;
					dmcsilence = true;
				}
				if (statusDmcInt) {
					--cpu.interrupt;
					statusDmcInt = false;
				}

			case 0x16:
				// latch controller 1 + 2
				nes.getcontroller1().output(utils.getbit(data, 0));
				nes.getcontroller2().output(utils.getbit(data, 0));

			case 0x17:
				ctrmode = utils.getbit(data, 7) ? 5 : 4;
				//System.err.println("reset " + ctrmode + ' ' + cpu.cycles);
				apuintflag = utils.getbit(data, 6);
				//set is no interrupt, clear is an interrupt
				framectr = 0;
				frameCtrDiv = 7456 + 8;
				if (apuintflag && statusFrameInt) {
					statusFrameInt = false;
					--cpu.interrupt;
					//System.err.println("Frame interrupt off at " + cpu.cycles);
				}
				if (ctrmode == 5) {
					//everything frame counter runs is clocked no matter what
					setenvelope();
					setlinctr();
					setlength();
					setsweep();
				}

			default:
		}*/
	}

	public inline function updateto(cpuCycle:Int)
	{
		while (cycles < cpuCycle)
		{
			++remainder;
			//clockDmc();
			if (--frameCtrDiv <= 0)
			{
				frameCtrDiv = 7456;
				//clockFrameCounter();
			}
			if ((cycles % cyclesPerSample) < 1)
			{
				//not quite right - there's a non-integer # cycles per sample.
				//timers[0].clock(remainder);
				//timers[1].clock(remainder);
				if (lengthCtrl[2] > 0 && linearCtr > 0) {
				//	timers[2].clock(remainder);
				}
				//timers[3].clock(remainder);
				//var mixVol = getOutputLevel();
				/*if (!expnSound.isEmpty())
				{
					for (c in expnSound) {
						c.clock(remainder);
					}
				}*/
				remainder = 0;
				//ai.outputSample(lowpass_filter(highpass_filter(mixvol)));
			}
			++cycles;
		}
	}
}
