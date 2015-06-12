package strafe.emu.nes;


class CPU implements IState
{
	public var ram:RAM;
	public var ppu:PPU;
	public var cycles:Int = 0;
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

	var cf:Bool = false;		// carry
	var zf:Bool = false;		// zero
	var id:Bool = true;			// interrupt disable
	var dm:Bool = false;		// decimal mode
	var bc:Bool = false;		// break command
	var uf:Bool = false;		// unused flag; for compatibility with fceux trace
	var of:Bool = false;		// overflow
	var nf:Bool = false;		// negative

	var interruptDelay:Bool = false;
	var prevIntFlag:Bool = false;

	var ticks:Int = 0;

	public function new(ram:RAM)
	{
		this.ram = ram;
	}

	public function init(ppu:PPU)
	{
		this.ppu = ppu;

		for (i in 0 ... 0x800)
		{
			write(i, 0xff);
		}

		write(0x0008, 0xf7);
		write(0x0009, 0xef);
		write(0x000A, 0xdf);
		write(0x000F, 0xbf);

		for (i in 0x4000 ...  0x4010)
		{
			write(i, 0);
		}

		write(0x4015, 0);
		write(0x4017, 0);

		pc = (read(0xfffd) << 8) | read(0xfffc);
	}

	public function reset()
	{
		pc = (read(0xfffd) << 8) | read(0xfffc);
		write(0x4015, 0);
		write(0x4017, read(0x4017));
		id = true;
	}

	public inline function suppressNmi()
	{
		nmiQueued = false;
		if (nmi) prevNmi = true;
	}

	/**
	 * Run a single instruction.
	 */
	public function runCycle()
	{
		read(0x4000);
		if (ram.dmaCounter > 0 && --ram.dmaCounter == 0)
		{
			// account for CPU cycles from DMA
			cycles += 513;
		}

		if (cycles-- > 0) return;

		var ad:Int, v:Int;
		var mode:AddressingMode;

		if (nmiQueued)
		{
			doNmi();
			nmiQueued = false;
		}
		if (nmi && !prevNmi)
		{
			nmiQueued = true;
		}
		prevNmi = nmi;

		if (interrupt > 0)
		{
			if (!id && !interruptDelay)
			{
				doInterrupt();
				cycles += 7;
				return;
			}
			else if (interruptDelay)
			{
				interruptDelay = false;
				if (!prevIntFlag)
				{
					doInterrupt();
					cycles += 7;
					return;
				}
			}
		}

		var byte:Int = read(pc);
		var code:OpCode = OpCode.getCode(byte);

		var value:Null<Int> = null;

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
		++pc;
		pc &= 0xffff;

		// get base number of CPU cycles for this operation
		// (in some circumstances, this may increase during execution)
		ticks = OpCode.getTicks(byte);

		// execute instruction
		switch (code)
		{
			case ORA:					// logical or
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				value = getValue(mode, ad);
				accumulator |= value;
				value = accumulator;

			case AND:					// logical and
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				accumulator &= v;
				value = accumulator;

			case EOR:					// exclusive or
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				value = getValue(mode, ad);
				accumulator = value ^ accumulator;
				value = accumulator;

			case ADC:					// add with carry
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				value = adc(v);

			case STA:					// store accumulator
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
#if cputrace
				Sys.print(" = #$" + StringTools.hex(read(ad), 2));
#end
				if (mode == AbsoluteX || mode == ZeroPageY)
					read(ad);
				write(ad, accumulator);

			case LDA:					// load accumulator
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				value = accumulator = getValue(mode, ad);

			case STX:					// store x
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				write(ad, x);
#if cputrace
				Sys.print(" = #$" + StringTools.hex(x, 2));
#end

			case STY:					// store y
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				write(ad, y);
#if cputrace
				Sys.print(" = #$" + StringTools.hex(y, 2));
#end

			case SEI, CLI:				// set/clear interrupt disable
				delayInterrupt();
				id = code == OpCode.SEI;

			case SED, CLD:				// set/clear decimal mode
				dm = code == OpCode.SED;

			case SEC, CLC:				// set/clear carry
				cf = code == OpCode.SEC;

			case CLV:					// clear overflow
				of = false;

			case BIT:					// bit test
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				zf = v & accumulator == 0;
				of = v & 0x40 != 0;
				nf = v & 0x80 != 0;

			case CMP,
				CPX,
				CPY:					// compare [x/y]
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);

				var compare_to = switch (code)
				{
					case CMP: accumulator;
					case CPX: x;
					default: y;
				}

				var tmp = compare_to - v;
				if (tmp < 0)
					tmp += 0xff + 1;

				cf = compare_to >= v;
				zf = compare_to == v;
				nf = tmp & 0x80 == 0x80;

			case SBC:					// subtract with carry
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				value = sbc(v);

			case JSR:					// jump to subroutine
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				pushStack(pc - 1 >> 8);
				pushStack((pc - 1) & 0xff);
				pc = ad;

			case RTS:					// return from subroutine
				read(pc++);
				pc = (popStack() | (popStack() << 8)) + 1;

			case RTI:					// return from interrupt
				read(pc++);
				popStatus();
				pc = popStack() | (popStack() << 8);

			case ASL:					// arithmetic shift left
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				//write(ad, v);
				cf = v & 0x80 != 0;
				value = (v << 1) & 0xff;
				storeValue(mode, ad, value);

			case LSR:					// logical shift right
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				//write(ad, v);
				cf = v & 1 != 0;
				value = v >> 1;
				storeValue(mode, ad, value);

			case ROL:					// rotate left
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				//write(ad, v);
				var new_cf = v & 0x80 != 0;
				value = (v << 1) & 0xff;
				value += cf ? 1 : 0;
				cf = new_cf;
				storeValue(mode, ad, value);

			case ROR:					// rotate right
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				//write(ad, v);
				var new_cf = v & 1 != 0;
				value = (v >> 1) & 0xff;
				value += cf ? 0x80 : 0;
				cf = new_cf;
				storeValue(mode, ad, value);

			case BCC,
					BCS,
					BEQ,
					BMI,
					BNE,
					BPL,
					BVC,
					BVS:					// branch
				var toCheck = switch(code)
				{
					case BCC, BCS:
						cf;
					case BEQ, BNE:
						zf;
					case BMI, BPL:
						nf;
					case BVC, BVS:
						of;
					default: false;
				}

				var checkAgainst = switch(code)
				{
					case BCS, BEQ, BMI, BVS:
						true;
					default:
						false;
				}

				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				if (toCheck == checkAgainst)
				{
					ticks += 1;
					pc = ad;
				}
				else
				{
					ticks = 2;
				}

			case JMP:					// jump
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				pc = ad;

			case LDX:					// load x
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				x = getValue(mode, ad);
				zf = x == 0;
				nf = x & 0x80 == 0x80;

			case LDY:					// load y
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				y = getValue(mode, ad);
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
				accumulator = value = popStack();

			case INC:					// increment memory
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				value = read(ad);
				//write(ad, value);
				value = (value + 1) & 0xff;
				write(ad, value);

			case INX:					// increment x
				x += 1;
				x &= 0xff;
				value = x;

			case INY:					// increment x
				y += 1;
				y &= 0xff;
				value = y;

			case DEC:					// decrement memory
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				value = read(ad);
				//write(ad, value);
				value = (value - 1) & 0xff;
				write(ad, value);

			case DEX:					// decrement x
				x = (x-1) & 0xff;
				value = x;

			case DEY:					// decrement y
				y = (y-1) & 0xff;
				value = y;

			case TAX:					// transfer accumulator to x
				x = value = accumulator;

			case TAY:					// transfer accumulator to y
				y = value = accumulator;

			case TSX:					// transfer stack pointer to x
				x = value = sp;

			case TSY:					// transfer stack pointer to y
				y = value = sp;

			case TYA:					// transfer y to accumulator
				accumulator = value = y;

			case TXS:					// transfer x to stack pointer
				sp = x;

			case TXA:					// transfer x to accumulator
				accumulator = value = x;

			case NOP: {}					// no operation

			case IGN1:
				pc += 1;

			case IGN2:
				pc += 2;

			case LAX:					// LDX + TXA
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				x = getValue(mode, ad);
				accumulator = value = x;

			case SAX:					// store (x & accumulator)
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				write(ad, x & accumulator);

			case RLA:					// ROL then AND
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				value = (v << 1) & 0xff;
				value += cf ? 1 : 0;

				write(ad, value);
				cf = v & 0x80 != 0;

				accumulator &= value;
				value = accumulator;

			case RRA:					// ROR then ADC
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				value = (v >> 1) & 0xff;
				value += cf ? 0x80 : 0;

				write(ad, value);
				cf = v & 1 != 0;

				value = accumulator = adc(value);

			case SLO:					// ASL then ORA
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				cf = v & 0x80 != 0;
				v = (v << 1) & 0xff;
				write(ad, v);
				accumulator |= v;
				value = accumulator;

			case SRE:					// LSR then EOR
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad);
				cf = v & 1 != 0;
				value = v >> 1;
				write(ad, value);
				accumulator = value ^ accumulator;
				value = accumulator;

			case DCP:					// DEC then CMP
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				v = getValue(mode, ad) - 1;
				v &= 0xff;
				write(ad, v);

				var tmp = accumulator - v;
				if (tmp < 0) tmp += 0xff + 1;

				cf = accumulator >= v;
				zf = accumulator == v;
				nf = tmp & 0x80 == 0x80;

			case ISC:					// INC then SBC
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				value = (read(ad) + 1) & 0xff;
				write(ad, value);
				value = sbc(value);

			case BRK:					// break
				read(pc++);
				breakInterrupt();

			case ALR:
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				accumulator &= read(ad);
				cf = accumulator & 1 != 0;
				accumulator >>= 1;
				accumulator &= 0x7f;
				value = accumulator;

			case ANC:
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				accumulator &= read(ad);
				cf = nf = accumulator & 0x80 == 0x80;
				zf = accumulator == 0;

			case ARR:
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				accumulator = (((ram.read(ad) & accumulator) >> 1)	 | (cf ? 0x80 : 0x00));
				zf = accumulator == 0;
				nf = accumulator & 0x80 == 0x80;
				cf = accumulator & 0x40 == 0x40;
				of = accumulator & 0x20 == 0x20 != cf;

			case AXS:
				mode = OpCode.getAddressingMode(byte);
				ad = getAddress(mode);
				value = x = (accumulator & x) - ram.read(ad);
				cf = (x >= 0);

			default:
				throw "Instruction $" + StringTools.hex(byte,2) + " not implemented";
		}

		if (value != null)
		{
			zf = value == 0;
			nf = value & 0x80 == 0x80;
		}

#if cputrace
		Sys.print("\n");
#end

		cycles += ticks;
		cycleCount += ticks;
		pc &= 0xffff;
	}

	inline function getAddress(mode:AddressingMode):Int
	{
		var address:Int;
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
				if ((address & 0xff00) != (pc & 0xff00)) ticks += 2;

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

	inline function getSigned(byte:Int)
	{
		byte &= 0xff;

		return (byte & 0x80 != 0) ? -((~(byte - 1)) & 0xff) : byte;
	}

	inline function getValue(mode:AddressingMode, addr:Int)
	{
		switch(mode)
		{
			case AddressingMode.Immediate:
				return addr & 0xff;

			case AddressingMode.Accumulator:
#if cputrace
				Sys.print(" = #$" + StringTools.hex(accumulator, 2));
#end
				return accumulator;
			default:
				var r = read(addr);
#if cputrace
				Sys.print(" = #$" + StringTools.hex(r, 2));
#end
				read(addr+1);
				return r;
		}
	}

	inline function adc(value:Int)
	{
		var result = value + accumulator + (cf ? 1 : 0);
		cf = (result >> 8 != 0);
		of = (((accumulator ^ value) & 0x80) == 0)
				&& (((accumulator ^ result) & 0x80) != 0);
		accumulator = result & 0xff;

		return accumulator;
	}

	inline function sbc(value:Int)
	{
		var result = accumulator - value - (cf ? 0 : 1);
		cf = (result >> 8 == 0);
		of = (((accumulator ^ value) & 0x80) != 0)
				&& (((accumulator ^ result) & 0x80) != 0);
		accumulator = result & 0xff;

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

	inline function pushStatus()
	{
		pushStack(statusFlag | 0x10 | 0x20);
	}

	inline function popStatus()
	{
		statusFlag = popStack();
	}

	inline function storeValue(mode:AddressingMode, ad:Int, value:Int)
	{
		if (mode == AddressingMode.Accumulator)
		{
			accumulator = value;
		}
		else
		{
			write(ad, value);
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
