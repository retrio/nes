package strafe.emu.nes;

import haxe.ds.Vector;


// the macro was a cool idea, but currently it actually hurts performance,
// so leaving it disabled
// might do better by inlining getAddress/getValue and using constant
// propogation to eliminate the branching in those functions, but since I'm
// already aggressively inlining, it might not be worth the code size increase
//@:build(strafe.emu.nes.macro.CPUOptimizer.build())
class CPU implements IState
{
	public var ram:Memory;
	public var ppu:PPU;
	public var cycles:Int = 0;
	public var ticks:Int = 0;
	public var cycleCount:Int = 0;
	public var nmi:Bool = false;
	public var pc:Int = 0x8000;	// program counter
	public var dma:Int = 0;

	public var interrupt:Int = 0;

	var nmiQueued:Bool = false;
	var prevNmi:Bool = false;
	var sp:Int = 0xFD;			// stack pointer
	var accumulator:Int = 0;	// accumulator
	var x:Int = 0;				// x register
	var y:Int = 0;				// y register

	var value:Int;
	var address:Int;
	var tmp:Int;

#if vectorflags
	var flags:Vector<Bool> = new Vector(8);
	var cf(get, set):Bool;		// carry
	inline function get_cf() return flags[0];
	inline function set_cf(f:Bool) return flags[0] = f;
	var zf(get, set):Bool;		// zero
	inline function get_zf() return flags[1];
	inline function set_zf(f:Bool) return flags[1] = f;
	var id(get, set):Bool;		// interrupt disable
	inline function get_id() return flags[2];
	inline function set_id(f:Bool) return flags[2] = f;
	var dm(get, set):Bool;		// decimal mode
	inline function get_dm() return flags[3];
	inline function set_dm(f:Bool) return flags[3] = f;
	var bc(get, set):Bool;		// break command
	inline function get_bc() return flags[4];
	inline function set_bc(f:Bool) return flags[4] = f;
	var uf(get, set):Bool;		// unused flag
	inline function get_uf() return flags[5];
	inline function set_uf(f:Bool) return flags[5] = f;
	var of(get, set):Bool;		// overflow
	inline function get_of() return flags[6];
	inline function set_of(f:Bool) return flags[6] = f;
	var nf(get, set):Bool;		// negative
	inline function get_nf() return flags[7];
	inline function set_nf(f:Bool) return flags[7] = f;
#else
	var cf:Bool;		// carry
	var zf:Bool;		// zero
	var id:Bool;		// interrupt disable
	var dm:Bool;		// decimal mode
	var bc:Bool;		// break command
	var uf:Bool;		// unused flag
	var of:Bool;		// overflow
	var nf:Bool;		// negative
#end

	var interruptDelay:Bool = false;
	var prevIntFlag:Bool = false;

	public function new(ram:Memory)
	{
		this.ram = ram;
	}

	public function init(nes:NES, ppu:PPU)
	{
		this.ppu = ppu;

		for (i in 0 ... 0x800)
		{
			ram._ram.set(i, 0xff);
		}

		ram._ram.set(0x0008, 0xf7);
		ram._ram.set(0x0009, 0xef);
		ram._ram.set(0x000A, 0xdf);
		ram._ram.set(0x000F, 0xbf);

		for (i in 0x4000 ...  0x4010)
		{
			nes.apu.write(i-0x4000, 0);
		}

		nes.apu.write(0x0015, 0);
		nes.apu.write(0x0017, 0);

		pc = (nes.mapper.read(0xfffd) << 8) | nes.mapper.read(0xfffc);

#if vectorflags
		for (i in 0 ... flags.length) flags[i] = false;
#end
	}

	public function reset(nes:NES)
	{
		pc = (nes.mapper.read(0xfffd) << 8) | nes.mapper.read(0xfffc);
		nes.apu.write(0x0015, 0);
		nes.apu.write(0x0017, nes.apu.read(0x0017));
		id = true;
	}

	public inline function suppressNmi()
	{
		nmiQueued = false;
		if (nmi) prevNmi = true;
	}

	public function runFrame()
	{
		ppu.stolenCycles = 0;
		while (!ppu.finished)
		{
			runCycle();

			if ((cycles + ppu.stolenCycles >= 27200 && ppu.scanline < 242 ) ||
				(cycles + ppu.stolenCycles >= 31200))
			{
				// yield control to the the PPU to catch up to this clock; this
				// happens when the PPU has been modified or at end of frame
				ppu.catchUp();
			}
		}
		ppu.finished = false;
	}

	/**
	 * Run a single instruction.
	 */
	public inline function runCycle()
	{
		//read(0x4000);
		if (ram.dmaCounter > 0 && --ram.dmaCounter == 0)
		{
			// account for CPU cycles from DMA
			cycles += 513;
			ppu.catchUp();
		}

		var nmiFrame:Bool = false;

		var mode:AddressingMode;

		if (nmiQueued)
		{
			doNmi();
			nmiQueued = false;
			nmiFrame = true;
		}
		if (nmi && !prevNmi)
		{
			nmiQueued = true;
		}
		prevNmi = nmi;

		if (nmiFrame) {}
		else if (interrupt > 0)
		{
			if (!id && !interruptDelay)
			{
				doInterrupt();
				cycles += 7;
			}
			else if (interruptDelay)
			{
				interruptDelay = false;
				if (!prevIntFlag)
				{
					doInterrupt();
					cycles += 7;
				}
			}
		}
		else
		{
			var byte:Int = read(pc);
			var code:OpCode = OpCode.getCode(byte);

#if cputrace
			Sys.print("f" + StringTools.rpad(Std.string(ppu.frameCount), " ", 7));
			Sys.print("c" + StringTools.rpad(Std.string(cycleCount), " ", 12));
			Sys.print("A:" + StringTools.hex(accumulator, 2));
			Sys.print(" X:" + StringTools.hex(x, 2));
			Sys.print(" Y:" + StringTools.hex(y, 2));
			Sys.print(" S:" + StringTools.hex(sp, 2));
			Sys.print(" P:"
				+ (nf ? "N" : "n")
				+ (of ? "V" : "v")
				+ (uf ? "U" : "u")
				+ (bc ? "B" : "b")
				+ (dm ? "D" : "d")
				+ (id ? "I" : "i")
				+ (zf ? "Z" : "z")
				+ (cf ? "C" : "c")
			);
			Sys.print("   $" + StringTools.hex(pc, 4) + ":" + StringTools.hex(byte, 2));
			Sys.print("        " + OpCode.opCodeNames[Std.int(code)] + " ");
#end
			pc = (pc + 1) & 0xffff;

			// get base number of CPU cycles for this operation
			// (in some circumstances, this may increase during execution)
			ticks = OpCode.getTicks(byte);

			// execute instruction
			@execute switch (code)
			{
				case ORA:					// logical or
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					accumulator |= value;
					setFlags(accumulator);

				case AND:					// logical and
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					accumulator &= value;
					setFlags(accumulator);

				case EOR:					// exclusive or
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					accumulator = value ^ accumulator;
					setFlags(accumulator);

				case ADC:					// add with carry
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					setFlags(adc(value));

				case STA:					// store accumulator
					mode = OpCode.getAddressingMode(byte);
					address = getAddress(mode);
					// dummy read
					switch (mode)
					{
						case AddressingMode.AbsoluteX:
							dummyRead((address - x) & 0xffff);
						case AddressingMode.ZeroPageY, AddressingMode.IndirectY:
							dummyRead((address - y) & 0xffff);
						default: {}
					}

					write(address, accumulator);

				case LDA:					// load accumulator
					mode = OpCode.getAddressingMode(byte);
					accumulator = getValue(mode);
					if (mode == AddressingMode.AbsoluteX && (address & 0xff00 != ((address-x) & 0xff00)))
					{
						// dummy read
						dummyRead((address - 0x100) & 0xffff);
					}
					else if (mode == AddressingMode.IndirectY && (address & 0xff00 != ((address-y) & 0xff00)))
					{
						// dummy read
						dummyRead((address - 0x100) & 0xffff);
					}

					setFlags(accumulator);

				case STX:					// store x
					mode = OpCode.getAddressingMode(byte);
					address = getAddress(mode);
					write(address, x);

				case STY:					// store y
					mode = OpCode.getAddressingMode(byte);
					address = getAddress(mode);
					write(address, y);

				case SEI:					// set interrupt disable
					delayInterrupt();
					id = true;

				case CLI:					// clear interrupt disable
					delayInterrupt();
					id = false;

				case SED:					// set decimal mode
					dm = true;

				case CLD:					// clear decimal mode
					dm = false;

				case SEC:					// set carry
					cf = true;

				case CLC:					// clear carry
					cf = false;

				case CLV:					// clear overflow
					of = false;

				case BIT:					// bit test
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					zf = value & accumulator == 0;
					of = value & 0x40 != 0;
					nf = value & 0x80 != 0;

				case CMP:					// compare accumulator
					mode = OpCode.getAddressingMode(byte);
					cmp(accumulator, mode);

				case CPX:					// compare x
					mode = OpCode.getAddressingMode(byte);
					cmp(x, mode);

				case CPY:					// compare y
					mode = OpCode.getAddressingMode(byte);
					cmp(y, mode);

				case SBC:					// subtract with carry
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					setFlags(sbc(value));

				case JSR:					// jump to subroutine
					mode = OpCode.getAddressingMode(byte);
					address = getAddress(mode);
					pushStack(pc - 1 >> 8);
					pushStack((pc - 1) & 0xff);
					pc = address;

				case RTS:					// return from subroutine
					dummyRead(pc++);
					pc = (popStack() | (popStack() << 8)) + 1;

				case RTI:					// return from interrupt
					dummyRead(pc++);
					popStatus();
					pc = popStack() | (popStack() << 8);

				case ASL:					// arithmetic shift left
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					//write(address, value);
					cf = value & 0x80 != 0;
					value = (value << 1) & 0xff;
					storeValue(mode, address, value);
					setFlags(value);

				case LSR:					// logical shift right
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					//write(address, value);
					cf = value & 1 != 0;
					value = value >> 1;
					storeValue(mode, address, value);
					setFlags(value);

				case ROL:					// rotate left
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					var new_cf = value & 0x80 != 0;
					value = (value << 1) & 0xff;
					value += cf ? 1 : 0;
					cf = new_cf;
					storeValue(mode, address, value);
					setFlags(value);

				case ROR:					// rotate right
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					//write(ad, v);
					var new_cf = value & 1 != 0;
					value = (value >> 1) & 0xff;
					value += cf ? 0x80 : 0;
					cf = new_cf;
					storeValue(mode, address, value);
					setFlags(value);

				case BCC:
					mode = OpCode.getAddressingMode(byte);
					branch(!cf, mode);

				case BCS:
					mode = OpCode.getAddressingMode(byte);
					branch(cf, mode);

				case BNE:
					mode = OpCode.getAddressingMode(byte);
					branch(!zf, mode);

				case BEQ:
					mode = OpCode.getAddressingMode(byte);
					branch(zf, mode);

				case BPL:
					mode = OpCode.getAddressingMode(byte);
					branch(!nf, mode);

				case BMI:
					mode = OpCode.getAddressingMode(byte);
					branch(nf, mode);

				case BVC:
					mode = OpCode.getAddressingMode(byte);
					branch(!of, mode);

				case BVS:
					mode = OpCode.getAddressingMode(byte);
					branch(of, mode);

				case JMP:					// jump
					mode = OpCode.getAddressingMode(byte);
					address = getAddress(mode);
					pc = address;

				case LDX:					// load x
					mode = OpCode.getAddressingMode(byte);
					x = getValue(mode);
					zf = x == 0;
					nf = x & 0x80 == 0x80;

				case LDY:					// load y
					mode = OpCode.getAddressingMode(byte);
					y = getValue(mode);
					zf = y == 0;
					nf = y & 0x80 == 0x80;

				case PHA:					// push accumulator
					pushStack(accumulator);

				case PHP:					// push cpu status
					pushStatus();

				case PLP:					// pull cpu status
					delayInterrupt();
					popStatus();

				case PLA:					// pull accumulator
					accumulator = popStack();
					setFlags(accumulator);

				case INC:					// increment memory
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					//write(ad, value);
					value = (value + 1) & 0xff;
					write(address, value);
					setFlags(value);

				case INX:					// increment x
					x += 1;
					x &= 0xff;
					setFlags(x);

				case INY:					// increment x
					y += 1;
					y &= 0xff;
					setFlags(y);

				case DEC:					// decrement memory
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					//write(ad, value);
					value = (value - 1) & 0xff;
					write(address, value);
					setFlags(value);

				case DEX:					// decrement x
					setFlags(x = (x-1) & 0xff);

				case DEY:					// decrement y
					setFlags(y = (y-1) & 0xff);

				case TAX:					// transfer accumulator to x
					setFlags(x = accumulator);

				case TAY:					// transfer accumulator to y
					setFlags(y = accumulator);

				case TSX:					// transfer stack pointer to x
					setFlags(x = sp);

				case TSY:					// transfer stack pointer to y
					setFlags(y = sp);

				case TYA:					// transfer y to accumulator
					setFlags(accumulator = y);

				case TXS:					// transfer x to stack pointer
					sp = x;

				case TXA:					// transfer x to accumulator
					setFlags(accumulator = x);

				case NOP: {}					// no operation

				case IGN1:
					pc += 1;

				case IGN2:
					pc += 2;

				case LAX:					// LDX + TXA
					mode = OpCode.getAddressingMode(byte);
					x = getValue(mode);
					setFlags(accumulator = x);

				case SAX:					// store (x & accumulator)
					mode = OpCode.getAddressingMode(byte);
					address = getAddress(mode);
					write(address, x & accumulator);

				case RLA:					// ROL then AND
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					value = (value << 1) & 0xff;
					value += cf ? 1 : 0;

					write(address, value);
					cf = value & 0x80 != 0;

					accumulator &= value;
					setFlags(accumulator);

				case RRA:					// ROR then ADC
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					value = (value >> 1) & 0xff;
					value += cf ? 0x80 : 0;

					write(address, value);
					cf = value & 1 != 0;

					accumulator = adc(value);
					setFlags(accumulator);

				case SLO:					// ASL then ORA
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					cf = value & 0x80 != 0;
					value = (value << 1) & 0xff;
					write(address, value);
					accumulator |= value;
					setFlags(accumulator);

				case SRE:					// LSR then EOR
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode);
					cf = value & 1 != 0;
					value = value >> 1;
					write(address, value);
					accumulator = value ^ accumulator;
					setFlags(accumulator);

				case DCP:					// DEC then CMP
					mode = OpCode.getAddressingMode(byte);
					value = getValue(mode) - 1;
					write(address, value & 0xff);

					tmp = accumulator - value;
					if (tmp < 0) tmp += 0xff + 1;

					cf = accumulator >= value;
					zf = accumulator == value;
					nf = tmp & 0x80 == 0x80;

				case ISC:					// INC then SBC
					mode = OpCode.getAddressingMode(byte);
					value = (getValue(mode) + 1) & 0xff;
					write(address, value);
					setFlags(sbc(value));

				case BRK:					// break
					dummyRead(pc++);
					breakInterrupt();

				case ALR:
					mode = OpCode.getAddressingMode(byte);
					accumulator &= getValue(mode);
					cf = accumulator & 1 != 0;
					accumulator >>= 1;
					accumulator &= 0x7f;
					setFlags(accumulator);

				case ANC:
					mode = OpCode.getAddressingMode(byte);
					accumulator &= getValue(mode);
					cf = nf = accumulator & 0x80 == 0x80;
					zf = accumulator == 0;

				case ARR:
					mode = OpCode.getAddressingMode(byte);
					accumulator = (((getValue(mode) & accumulator) >> 1) | (cf ? 0x80 : 0x00));
					zf = accumulator == 0;
					nf = accumulator & 0x80 == 0x80;
					cf = accumulator & 0x40 == 0x40;
					of = accumulator & 0x20 == 0x20 != cf;

				case AXS:
					mode = OpCode.getAddressingMode(byte);
					x = (accumulator & x) - getValue(mode);
					cf = (x >= 0);
					setFlags(x);

				default:
					throw "Invalid instruction: $" + StringTools.hex(byte);
			}

#if cputrace
			Sys.print("\n");
#end

			cycles += ticks;
			cycleCount += ticks;
			pc &= 0xffff;
		}
	}

	inline function setFlags(value:Int)
	{
		zf = value == 0;
		nf = value & 0x80 == 0x80;
	}

	inline function getAddress(mode:AddressingMode):Int
	{
		switch(mode)
		{
			case Immediate:
				address = read(pc++);
#if cputrace
				Sys.print("#$" + StringTools.hex(address, 2));
#end

			case ZeroPage:
				address = read(pc++);// & 0xff;
#if cputrace
				Sys.print("$" + StringTools.hex(address, 4));
#end

			case ZeroPageX, ZeroPageY:
				address = read(pc++);
#if cputrace
				Sys.print("$" + StringTools.hex(address, 4) + "," + (mode==ZeroPageX ? "X" : "Y") + " @ ");
#end
				address += (mode==ZeroPageX) ? x : y;
				address &= 0xff;
#if cputrace
				Sys.print("$" + StringTools.hex(address, 4));
#end

			case Relative:
				address = getSigned(read(pc++));
				address += pc;
#if cputrace
				Sys.print("$" + StringTools.hex(address, 4));
#end
				//address = (read(pc++) & 0xff) + pc;
				// new page
				if ((address & 0xff00) != (pc & 0xff00)) ticks += 1;

			case Indirect:
				address = read(pc++) | (read(pc++) << 8);

				var next_addr = address + 1;
				if (next_addr & 0xff == 0)
				{
					next_addr -= 0x0100;
				}

				address = (read(address) & 0xff) | (read(next_addr) << 8);
#if cputrace
				Sys.print("$" + StringTools.hex(address, 4));
#end

			case IndirectX:
				address = read(pc++);
#if cputrace
				Sys.print("($" + StringTools.hex(address, 4) + ",X)");
#end
				address += x;
				address &= 0xff;
				address = (read(address) & 0xff) | (read((address+1) & 0xff) << 8);
#if cputrace
				Sys.print(" @ $" + StringTools.hex(address, 4));
#end

			case IndirectY:
				address = read(pc++);
#if cputrace
				Sys.print("($" + StringTools.hex(address, 4) + ")");
#end
				address = (read(address) & 0xff) | (read((address+1) & 0xff) << 8);

				// new page
				if (ticks == 5 && address&0xff00 != (address+y)&0xff00) ticks += 1;

				address += y;
#if cputrace
				Sys.print(",Y @ $" + StringTools.hex(address & 0xFFFF, 4));
#end

			case Absolute,
				 AbsoluteX,
				 AbsoluteY:

				address = read(pc++) | (read(pc++) << 8);

				if (mode==AddressingMode.AbsoluteX)
				{
					// new page
					if (ticks==4 && (address&0xff00 != (address+x)&0xff00)) ticks += 1;
#if cputrace
					Sys.print("$" + StringTools.hex(address, 4) + ",X @ ");
#end
					address += x;
#if cputrace
					Sys.print(StringTools.hex(address & 0xFFFF, 4));
#end
				}
				else if (mode==AddressingMode.AbsoluteY)
				{
					// new page
					if (ticks==4 && (address&0xff00 != (address+y)&0xff00)) ticks += 1;

#if cputrace
					Sys.print("$" + StringTools.hex(address, 4) + ",Y @ ");
#end
					address += y;
#if cputrace
					Sys.print(StringTools.hex(address & 0xFFFF, 4));
#end
				}
#if cputrace
				else
				{
					Sys.print("$" + StringTools.hex(address, 4));
				}
#end

			case Accumulator:
				// not important; will use the value of the accumulator
				address = 0;

			default:
				throw "Unknown addressing mode: " + mode;
		}

		return address & 0xffff;
	}

	inline function getSigned(byte:Int):Int
	{
		byte &= 0xff;

		return (byte & 0x80 != 0) ? -((~(byte - 1)) & 0xff) : byte;
	}

	inline function getValue(mode:AddressingMode):Int
	{
		switch(mode)
		{
			case Immediate:
				value = address = read(pc++);

			case ZeroPage:
				address = read(pc++);// & 0xff;
				value = read(address);

			case ZeroPageX, ZeroPageY:
				address = read(pc++);
				address += (mode==ZeroPageX) ? x : y;
				address &= 0xff;
				value = read(address);

			case Relative:
				address = getSigned(read(pc++));
				address += pc;
				//address = (read(pc++) & 0xff) + pc;
				// new page
				if ((address & 0xff00) != (pc & 0xff00)) ticks += 1;
				value = read(address);

			case Indirect:
				address = read(pc++) | (read(pc++) << 8);

				var next_addr = address + 1;
				if (next_addr & 0xff == 0)
				{
					next_addr -= 0x0100;
				}

				address = (read(address) & 0xff) | (read(next_addr) << 8);
				value = read(address);

			case IndirectX:
				address = read(pc++);
				address += x;
				address &= 0xff;
				address = (read(address) & 0xff) | (read((address+1) & 0xff) << 8);
				value = read(address);

			case IndirectY:
				address = read(pc++);
				address = (read(address) & 0xff) | (read((address+1) & 0xff) << 8);

				// new page
				if (ticks == 5 && address&0xff00 != (address+y)&0xff00) ticks += 1;

				address += y;
				value = read(address);

			case Absolute,
				 AbsoluteX,
				 AbsoluteY:

				address = read(pc++) | (read(pc++) << 8);

				if (mode==AddressingMode.AbsoluteX)
				{
					// new page
					if (ticks==4 && (address&0xff00 != (address+x)&0xff00)) ticks += 1;
					address += x;
				}
				else if (mode==AddressingMode.AbsoluteY)
				{
					// new page
					if (ticks==4 && (address&0xff00 != (address+y)&0xff00)) ticks += 1;

					address += y;
				}
				value = read(address);

			case Accumulator:
				value = accumulator;

			default:
				throw "Unknown addressing mode: " + mode;
		}

		return value;
	}

	inline function branch(cond:Bool, mode:AddressingMode):Void
	{
		address = getAddress(mode);
		if (cond)
		{
			++ticks;
			pc = address;
		}
		else ticks = 2;
	}

	inline function cmp(val:Int, mode:AddressingMode):Void
	{
		value = getValue(mode);

		tmp = val - value;
		if (tmp < 0)
			tmp += 0xff + 1;

		cf = val >= value;
		zf = val == value;
		nf = tmp & 0x80 == 0x80;
	}

	inline function adc(value:Int):Int
	{
		tmp = value + accumulator + (cf ? 1 : 0);
		cf = (tmp >> 8 != 0);
		of = (((accumulator ^ value) & 0x80) == 0)
				&& (((accumulator ^ tmp) & 0x80) != 0);
		accumulator = tmp & 0xff;

		return accumulator;
	}

	inline function sbc(value:Int):Int
	{
		tmp = accumulator - value - (cf ? 0 : 1);
		cf = (tmp >> 8 == 0);
		of = (((accumulator ^ value) & 0x80) != 0)
				&& (((accumulator ^ tmp) & 0x80) != 0);
		accumulator = tmp & 0xff;

		return accumulator;
	}

	inline function pushStack(value:Int)
	{
		write(0x100 + (sp & 0xff), value);
		sp--;
		sp &= 0xff;
	}

	inline function popStack():Int
	{
		++sp;
		sp &= 0xff;
		return read(0x100 + sp);
	}

	inline function pushStatus():Void
	{
		pushStack(statusFlag | 0x10 | 0x20);
	}

	inline function popStatus():Void
	{
		statusFlag = popStack();
	}

	inline function storeValue(mode:AddressingMode, addr:Int, value:Int):Void
	{
		if (mode == AddressingMode.Accumulator)
		{
			accumulator = value;
		}
		else
		{
			write(addr, value);
		}
	}

	var statusFlag(get, set):Int;
	inline function get_statusFlag()
	{
		return (cf ? 0x1 : 0) |
			(zf ? 0x2 : 0) |
			(id ? 0x4 : 0) |
			(dm ? 0x8 : 0) |
			(of ? 0x40 : 0) |
			(nf ? 0x80 : 0);
	}
	inline function set_statusFlag(val:Int)
	{
		cf = val & 0x1 != 0;
		zf = val & 0x2 != 0;
		id = val & 0x4 != 0;
		dm = val & 0x8 != 0;
		bc = val & 0x10 != 0;
		uf = true;
		of = val & 0x40 != 0;
		nf = val & 0x80 != 0;
		return val;
	}

	public inline function read(addr:Int):Int
	{
		return ram.read(addr & 0xffff) & 0xff;
	}

	inline function dummyRead(addr:Int):Void
	{
		read(addr);
	}

	public inline function write(addr:Int, data:Int):Void
	{
		ram.write(addr & 0xffff, data & 0xff);
	}

	inline function doNmi()
	{
		pushStack(pc >> 8);
		pushStack(pc & 0xff);
		pushStack(statusFlag);
		pc = read(0xfffa) | (read(0xfffb) << 8);
		cycles += 7;
		id = true;
	}

	inline function doInterrupt()
	{
		pushStack(pc >> 8); // high bit 1st
		pushStack((pc) & 0xff);// check that this pushes right address
		pushStack(statusFlag);
		pc = read(0xfffe) | (read(0xffff) << 8);
		id = true;
	}

	inline function breakInterrupt()
	{
		//same as interrupt but BRK flag is turned on
		pushStack(pc >> 8); // high bit 1st
		pushStack(pc & 0xff);// check that this pushes right address
		pushStatus();
		pc = read(0xfffe) | (read(0xffff)  << 8);
		id = true;
	}

	inline function delayInterrupt()
	{
		interruptDelay = true;
		prevIntFlag = id;
	}

	public function writeState(out:haxe.io.Output)
	{
		// TODO
	}
}
