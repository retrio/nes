package retrio.emu.nes;

import haxe.ds.Vector;


class CPU implements IState
{
	public var memory:Memory;
	public var ppu:PPU;
	@:state public var cycles:Int = 0;
	@:state public var apuCycles:Int = 0;
	@:state public var ticks:Byte = 0;
	@:state public var cycleCount:Int = 0;
	@:state public var nmi:Bool = false;
	@:state public var pc:Int = 0x8000;	// program counter
	@:state public var dma:Int = 0;

	@:state public var interrupt:Int = 0;

	@:state var nmiQueued:Bool = false;
	@:state var prevNmi:Bool = false;
	@:state var sp:Byte = 0xFD;			// stack pointer
	@:state var a:Byte = 0;				// accumulator
	@:state var x:Byte = 0;				// x register
	@:state var y:Byte = 0;				// y register

	@:state var cf:Bool;		// carry
	@:state var zf:Bool;		// zero
	@:state var id:Bool;		// interrupt disable
	@:state var dm:Bool;		// decimal mode
	@:state var bc:Bool;		// break command
	@:state var uf:Bool;		// unused flag
	@:state var of:Bool;		// overflow
	@:state var nf:Bool;		// negative

	@:state var interruptDelay:Bool = false;
	@:state var prevIntFlag:Bool = false;

	var address:Int;

	public function new(memory:Memory)
	{
		this.memory = memory;
	}

	public function init(nes:NES, ppu:PPU)
	{
		this.ppu = ppu;

		for (i in 0 ... 0x800)
		{
			memory.ram.set(i, 0xff);
		}

		memory.ram.set(0x0008, 0xf7);
		memory.ram.set(0x0009, 0xef);
		memory.ram.set(0x000A, 0xdf);
		memory.ram.set(0x000F, 0xbf);

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

			var projScanline = Std.int(ppu.scanline + (ppu.cycles + (cycles * 3)) / 340);
			if (projScanline > ppu.scanline || projScanline == 241)
			{
				// yield control to the the PPU to catch up to this clock; this
				// happens when the PPU has been modified or at end of each scanline
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
		ticks = 0;

		if (memory.dmaCounter > 0 && --memory.dmaCounter == 0)
		{
			// account for CPU cycles from DMA
			addTicks(513);
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

		if (interrupt > 0 && (!id && !interruptDelay))
		{
			doInterrupt();
			addTicks(7);
		}
		else if (interrupt > 0 && interruptDelay)
		{
			interruptDelay = false;
			if (!prevIntFlag)
			{
				doInterrupt();
				addTicks(7);
			}
		}
		else
		{
			interruptDelay = false;

			var byte:Int = readpc();

#if cputrace
			var code:OpCode = OpCode.getCode(byte);
			var mode:AddressingMode = OpCode.getAddressingMode(byte);

			Sys.print("f" + StringTools.rpad(Std.string(ppu.frameCount), " ", 7));
			Sys.print("c" + StringTools.rpad(Std.string(cycleCount), " ", 12));
			Sys.print("A:" + StringTools.hex(a, 2));
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
			Sys.print("   $" + StringTools.hex(pc-1, 4) + ":" + StringTools.hex(byte, 2));
			Sys.print("        " + OpCode.opCodeNames[Std.int(code)] + " ");
#end

			var value:Int;

			// execute instruction
			switch byte {
				case 0x01:
					// ORA
					ticks += 6;
					ora(read(inx()));

				case 0x05:
					// ORA
					ticks += 3;
					ora(read(zpg()));

				case 0x09:
					// ORA
					ticks += 2;
					ora(imm());

				case 0x0d:
					// ORA
					ticks += 4;
					ora(read(abs()));

				case 0x11:
					// ORA
					ticks += 5;
					ora(read(inyPb()));

				case 0x15:
					// ORA
					ticks += 4;
					ora(read(zpx()));

				case 0x19:
					// ORA
					ticks += 4;
					ora(read(abyPb()));

				case 0x1d:
					// ORA
					ticks += 4;
					ora(read(abxPb()));

				case 0x21:
					// AND
					ticks += 6;
					and(read(inx()));

				case 0x25:
					// AND
					ticks += 3;
					and(read(zpg()));

				case 0x29:
					// AND
					ticks += 2;
					and(imm());

				case 0x2d:
					// AND
					ticks += 4;
					and(read(abs()));

				case 0x31:
					// AND
					ticks += 5;
					and(read(inyPb()));

				case 0x35:
					// AND
					ticks += 4;
					and(read(zpx()));

				case 0x39:
					// AND
					ticks += 4;
					and(read(abyPb()));

				case 0x3d:
					// AND
					ticks += 4;
					and(read(abxPb()));

				case 0x41:
					// EOR
					ticks += 6;
					eor(read(inx()));

				case 0x45:
					// EOR
					ticks += 3;
					eor(read(zpg()));

				case 0x49:
					// EOR
					ticks += 2;
					eor(imm());

				case 0x4d:
					// EOR
					ticks += 4;
					eor(read(abs()));

				case 0x51:
					// EOR
					ticks += 5;
					eor(read(inyPb()));

				case 0x55:
					// EOR
					ticks += 4;
					eor(read(zpx()));

				case 0x59:
					// EOR
					ticks += 4;
					eor(read(abyPb()));

				case 0x5d:
					// EOR
					ticks += 4;
					eor(read(abxPb()));

				case 0x61:
					// ADC
					ticks += 6;
					adc(read(inx()));

				case 0x65:
					// ADC
					ticks += 3;
					adc(read(zpg()));

				case 0x69:
					// ADC
					ticks += 2;
					adc(imm());

				case 0x6d:
					// ADC
					ticks += 4;
					adc(read(abs()));

				case 0x71:
					// ADC
					ticks += 5;
					adc(read(inyPb()));

				case 0x75:
					// ADC
					ticks += 4;
					adc(read(zpx()));

				case 0x79:
					// ADC
					ticks += 4;
					adc(read(abyPb()));

				case 0x7d:
					// ADC
					ticks += 4;
					adc(read(abxPb()));

				case 0x81:
					// STA
					ticks += 6;
					inx();
					write(address, a);

				case 0x85:
					// STA
					ticks += 3;
					zpg();
					write(address, a);

				case 0x8d:
					// STA
					ticks += 4;
					abs();
					write(address, a);

				case 0x91:
					// STA
					ticks += 6;
					iny();
					dummyRead(((address - y) & 0xff00) | (address & 0xff));
					write(address, a);

				case 0x95:
					// STA
					ticks += 4;
					zpx();
					write(address, a);

				case 0x99:
					// STA
					ticks += 5;
					aby();
					write(address, a);

				case 0x9d:
					// STA
					ticks += 5;
					abx();
					dummyRead(((address - x) & 0xff00) | (address & 0xff));
					write(address, a);

				case 0xa1:
					// LDA
					ticks += 6;
					a = read(inx());
					setFlags(a);

				case 0xa5:
					// LDA
					ticks += 3;
					a = read(zpg());
					setFlags(a);

				case 0xa9:
					// LDA
					ticks += 2;
					a = imm();
					setFlags(a);

				case 0xad:
					// LDA
					ticks += 4;
					a = read(abs());
					setFlags(a);

				case 0xb1:
					// LDA
					ticks += 5;
					inyPb();
					if (address & 0xff00 != ((address - y) & 0xff00))
					{
						dummyRead(((address - y) & 0xff00) | (address & 0xff));
					}
					a = read(address);
					setFlags(a);

				case 0xb5:
					// LDA
					ticks += 4;
					a = read(zpx());
					setFlags(a);

				case 0xb9:
					// LDA
					ticks += 4;
					a = read(abyPb());
					setFlags(a);

				case 0xbd:
					// LDA
					ticks += 4;
					abxPb();
					if (address & 0xff00 != ((address - x) & 0xff00))
					{
						dummyRead(((address - x) & 0xff00) | (address & 0xff));
					}
					a = read(address);
					setFlags(a);

				case 0x86:
					// STX
					ticks += 3;
					address = zpg();
					write(address, x);

				case 0x8e:
					// STX
					ticks += 4;
					address = abs();
					write(address, x);

				case 0x96:
					// STX
					ticks += 4;
					address = zpy();
					write(address, x);

				case 0x84:
					// STY
					ticks += 3;
					address = zpg();
					write(address, y);

				case 0x8c:
					// STY
					ticks += 4;
					address = abs();
					write(address, y);

				case 0x94:
					// STY
					ticks += 4;
					address = zpx();
					write(address, y);

				case 0x78:
					// SEI
					ticks += 2;
					delayInterrupt();
					id = true;

				case 0x58:
					// CEI
					ticks += 2;
					delayInterrupt();
					id = false;

				case 0xf8:
					ticks += 2;
					dm = true;

				case 0xd8:
					ticks += 2;
					dm = false;

				case 0x38:
					ticks += 2;
					cf = true;

				case 0x18:
					ticks += 2;
					cf = false;

				case 0xb8:
					ticks += 2;
					of = false;

				case 0x24:
					// BIT
					ticks += 3;
					value = read(zpg());
					zf = value & a == 0;
					of = value & 0x40 != 0;
					nf = value & 0x80 != 0;

				case 0x2c:
					// BIT
					ticks += 4;
					value = read(abs());
					zf = value & a == 0;
					of = value & 0x40 != 0;
					nf = value & 0x80 != 0;

				case 0xc1:
					// CMP
					ticks += 6;
					value = read(inx());
					cmp(a, value);

				case 0xc5:
					// CMP
					ticks += 3;
					value = read(zpg());
					cmp(a, value);

				case 0xc9:
					// CMP
					ticks += 2;
					value = imm();
					cmp(a, value);

				case 0xcd:
					// CMP
					ticks += 4;
					value = read(abs());
					cmp(a, value);

				case 0xd1:
					// CMP
					ticks += 5;
					value = read(inyPb());
					cmp(a, value);

				case 0xd5:
					// CMP
					ticks += 4;
					value = read(zpx());
					cmp(a, value);

				case 0xd9:
					// CMP
					ticks += 4;
					value = read(abyPb());
					cmp(a, value);

				case 0xdd:
					// CMP
					ticks += 4;
					value = read(abxPb());
					cmp(a, value);

				case 0xe0:
					// CPX
					ticks += 2;
					value = imm();
					cmp(x, value);

				case 0xe4:
					// CPX
					ticks += 3;
					value = read(zpg());
					cmp(x, value);

				case 0xec:
					// CPX
					ticks += 4;
					value = read(abs());
					cmp(x, value);

				case 0xc0:
					// CPY
					ticks += 2;
					value = imm();
					cmp(y, value);

				case 0xc4:
					// CPY
					ticks += 3;
					value = read(zpg());
					cmp(y, value);

				case 0xcc:
					// CPY
					ticks += 4;
					value = read(abs());
					cmp(y, value);

				case 0xe1:
					// SBC
					ticks += 6;
					value = read(inx());
					sbc(value);

				case 0xe5:
					// SBC
					ticks += 3;
					value = read(zpg());
					sbc(value);

				case 0xe9:
					// SBC
					ticks += 2;
					value = imm();
					sbc(value);

				case 0xeb:
					// SBC
					ticks += 2;
					value = imm();
					sbc(value);

				case 0xed:
					// SBC
					ticks += 4;
					value = read(abs());
					sbc(value);

				case 0xf1:
					// SBC
					ticks += 5;
					value = read(inyPb());
					sbc(value);

				case 0xf5:
					// SBC
					ticks += 4;
					value = read(zpx());
					sbc(value);

				case 0xf9:
					// SBC
					ticks += 4;
					value = read(abyPb());
					sbc(value);

				case 0xfd:
					// SBC
					ticks += 4;
					value = read(abxPb());
					sbc(value);

				case 0x20:
					// JSR
					ticks += 6;
					value = read(abs());
					pushStack(pc - 1 >> 8);
					pushStack((pc - 1) & 0xff);
					pc = address;

				case 0x60:
					// RTS
					ticks += 6;
					dummyRead(pc++);
					pc = (popStack() | (popStack() << 8)) + 1;

				case 0x40:
					// RTI
					ticks += 6;
					dummyRead(pc++);
					popStatus();
					pc = popStack() | (popStack() << 8);

				case 0x06:
					// ASL
					ticks += 5;
					write(address, asl(read(zpg())));

				case 0x0a:
					// ASL
					ticks += 2;
					a = asl(a);

				case 0x0e:
					// ASL
					ticks += 6;
					write(address, asl(read(abs())));

				case 0x16:
					// ASL
					ticks += 6;
					write(address, asl(read(zpx())));

				case 0x1e:
					// ASL
					ticks += 7;
					write(address, asl(read(abx())));

				case 0x46:
					// LSR
					ticks += 5;
					write(address, lsr(read(zpg())));

				case 0x4a:
					// LSR
					ticks += 2;
					a = lsr(a);

				case 0x4e:
					// LSR
					ticks += 6;
					write(address, lsr(read(abs())));

				case 0x56:
					// LSR
					ticks += 6;
					write(address, lsr(read(zpx())));

				case 0x5e:
					// LSR
					ticks += 7;
					write(address, lsr(read(abx())));

				case 0x26:
					// ROL
					ticks += 5;
					write(address, rol(read(zpg())));

				case 0x2a:
					// ROL
					ticks += 2;
					a = rol(a);

				case 0x2e:
					// ROL
					ticks += 6;
					write(address, rol(read(abs())));

				case 0x36:
					// ROL
					ticks += 6;
					write(address, rol(read(zpx())));

				case 0x3e:
					// ROL
					ticks += 7;
					abx();
					dummyRead(((address - x) & 0xff00) | (address & 0xff));
					write(address, rol(read(address)));

				case 0x66:
					// ROR
					ticks += 5;
					write(address, ror(read(zpg())));

				case 0x6a:
					// ROR
					ticks += 2;
					a = ror(a);

				case 0x6e:
					// ROR
					ticks += 6;
					write(address, ror(read(abs())));

				case 0x76:
					// ROR
					ticks += 6;
					write(address, ror(read(zpx())));

				case 0x7e:
					// ROR
					ticks += 7;

					write(address, ror(read(abx())));

				case 0x90:
					// BCC
					ticks += 2;
					branch(!cf);

				case 0xb0:
					// BCS
					ticks += 2;
					branch(cf);

				case 0xd0:
					// BNE
					ticks += 2;
					branch(!zf);

				case 0xf0:
					// BEQ
					ticks += 2;
					branch(zf);

				case 0x10:
					// BPL
					ticks += 2;
					branch(!nf);

				case 0x30:
					// BMI
					ticks += 2;
					branch(nf);

				case 0x50:
					// BVC
					ticks += 2;
					branch(!of);

				case 0x70:
					// BVS
					ticks += 2;
					branch(of);

				case 0x4c:
					// JMP
					ticks += 3;
					value = read(abs());
					pc = address;

				case 0x6c:
					// JMP
					ticks += 5;
					value = read(ind());
					pc = address;

				case 0xa2:
					// LDX
					ticks += 2;
					x = imm();
					zf = x == 0;
					nf = x & 0x80 == 0x80;

				case 0xa6:
					// LDX
					ticks += 3;
					x = read(zpg());
					zf = x == 0;
					nf = x & 0x80 == 0x80;

				case 0xae:
					// LDX
					ticks += 4;
					x = read(abs());
					zf = x == 0;
					nf = x & 0x80 == 0x80;

				case 0xb6:
					// LDX
					ticks += 4;
					x = read(zpy());
					zf = x == 0;
					nf = x & 0x80 == 0x80;

				case 0xbe:
					// LDX
					ticks += 4;
					x = read(abyPb());
					zf = x == 0;
					nf = x & 0x80 == 0x80;

				case 0xa0:
					// LDY
					ticks += 2;
					y = imm();
					zf = y == 0;
					nf = y & 0x80 == 0x80;

				case 0xa4:
					// LDY
					ticks += 3;
					y = read(zpg());
					zf = y == 0;
					nf = y & 0x80 == 0x80;

				case 0xac:
					// LDY
					ticks += 4;
					y = read(abs());
					zf = y == 0;
					nf = y & 0x80 == 0x80;

				case 0xb4:
					// LDY
					ticks += 4;
					y = read(zpx());
					zf = y == 0;
					nf = y & 0x80 == 0x80;

				case 0xbc:
					// LDY
					ticks += 4;
					y = read(abxPb());
					zf = y == 0;
					nf = y & 0x80 == 0x80;

				case 0x48:
					// PHA
					ticks += 3;
					pushStack(a);

				case 0x08:
					// PHP
					ticks += 3;
					pushStatus();

				case 0x28:
					// PLP
					ticks += 4;
					delayInterrupt();
					popStatus();

				case 0x68:
					// PLA
					ticks += 4;
					a = popStack();
					setFlags(a);

				case 0xe6:
					// INC
					ticks += 5;
					write(address, inc(read(zpg())));

				case 0xee:
					// INC
					ticks += 6;
					write(address, inc(read(abs())));

				case 0xf6:
					// INC
					ticks += 6;
					write(address, inc(read(zpx())));

				case 0xfe:
					// INC
					ticks += 7;
					write(address, inc(read(abx())));

				case 0xe8:
					// INX
					ticks += 2;
					x = (x + 1) & 0xff;
					setFlags(x);

				case 0xc8:
					// INY
					ticks += 2;
					y = (y + 1) & 0xff;
					setFlags(y);

				case 0xc6:
					// DEC
					ticks += 5;
					write(address, dec(read(zpg())));

				case 0xce:
					// DEC
					ticks += 6;
					write(address, dec(read(abs())));

				case 0xd6:
					// DEC
					ticks += 6;
					write(address, dec(read(zpx())));

				case 0xde:
					// DEC
					ticks += 7;
					write(address, dec(read(abx())));

				case 0xca:
					// DEX
					ticks += 2;
					setFlags(x = (x - 1) & 0xff);

				case 0x88:
					// DEY
					ticks += 2;
					setFlags(y = (y - 1) & 0xff);

				case 0xaa:
					// TAX
					ticks += 2;
					setFlags(x = a);

				case 0xa8:
					// TAY
					ticks += 2;
					setFlags(y = a);

				case 0xba:
					// TSX
					ticks += 2;
					setFlags(x = sp);

				case 0x98:
					// TYA
					ticks += 2;
					setFlags(a = y);

				case 0x9a:
					// TXS
					ticks += 2;
					sp = x;

				case 0x8a:
					// TXA
					ticks += 2;
					setFlags(a = x);

				case 0x1a, 0x3a, 0x5a, 0x7a, 0xda, 0xea, 0xfa:
					// NOOP
					ticks += 2;

				case 0x04, 0x14, 0x34, 0x44, 0x54, 0x64, 0x74, 0x80,
					0x82, 0x89, 0xc2, 0xd4, 0xe2, 0xf4:
					// IGN1
					ticks += 3;
					pc += 1;

				case 0x0c, 0x1c, 0x3c, 0x5c, 0x7c, 0xdc, 0xfc:
					// IGN2
					ticks += 4;
					pc += 2;

				case 0xa3:
					// LAX
					ticks += 6;
					x = read(inx());
					setFlags(a = x);

				case 0xa7:
					// LAX
					ticks += 3;
					x = read(zpg());
					setFlags(a = x);

				case 0xab:
					// LAX
					ticks += 2;
					x = imm();
					setFlags(a = x);

				case 0xaf:
					// LAX
					ticks += 4;
					x = read(abs());
					setFlags(a = x);

				case 0xb3:
					// LAX
					ticks += 5;
					x = read(inyPb());
					setFlags(a = x);

				case 0xb7:
					// LAX
					ticks += 4;
					x = read(zpy());
					setFlags(a = x);

				case 0xbf:
					// LAX
					ticks += 4;
					x = read(abyPb());
					setFlags(a = x);

				case 0x83:
					// SAX
					ticks += 6;
					value = read(inx());
					write(address, x & a);

				case 0x87:
					// SAX
					ticks += 3;
					value = read(zpg());
					write(address, x & a);

				case 0x8f:
					// SAX
					ticks += 4;
					value = read(abs());
					write(address, x & a);

				case 0x97:
					// SAX
					ticks += 4;
					value = read(zpy());
					write(address, x & a);

				case 0x23:
					// RLA
					ticks += 8;
					write(address, rla(read(inx())));

				case 0x27:
					// RLA
					ticks += 5;
					write(address, rla(read(zpg())));

				case 0x2f:
					// RLA
					ticks += 6;
					write(address, rla(read(abs())));

				case 0x33:
					// RLA
					ticks += 8;
					write(address, rla(read(iny())));

				case 0x37:
					// RLA
					ticks += 6;
					write(address, rla(read(zpx())));

				case 0x3b:
					// RLA
					ticks += 7;
					write(address, rla(read(aby())));

				case 0x3f:
					// RLA
					ticks += 7;
					write(address, rla(read(abx())));

				case 0x63:
					// RRA
					ticks += 8;
					value = read(inx());
					write(address, rra(read(inx())));

				case 0x67:
					// RRA
					ticks += 5;
					write(address, rra(read(zpg())));

				case 0x6f:
					// RRA
					ticks += 6;
					write(address, rra(read(abs())));

				case 0x73:
					// RRA
					ticks += 8;
					write(address, rra(read(iny())));

				case 0x77:
					// RRA
					ticks += 6;
					write(address, rra(read(zpx())));

				case 0x7b:
					// RRA
					ticks += 7;
					write(address, rra(read(aby())));

				case 0x7f:
					// RRA
					ticks += 7;
					write(address, rra(read(abx())));

				case 0x03:
					// SLO
					ticks += 8;
					write(address, slo(read(inx())));

				case 0x07:
					// SLO
					ticks += 5;
					write(address, slo(read(zpg())));

				case 0x0f:
					// SLO
					ticks += 6;
					write(address, slo(read(abs())));

				case 0x13:
					// SLO
					ticks += 8;
					write(address, slo(read(iny())));

				case 0x17:
					// SLO
					ticks += 6;
					write(address, slo(read(zpx())));

				case 0x1b:
					// SLO
					ticks += 7;
					write(address, slo(read(aby())));

				case 0x1f:
					// SLO
					ticks += 7;
					write(address, slo(read(abx())));

				case 0x43:
					// SRE
					ticks += 8;
					write(address, sre(read(inx())));

				case 0x47:
					// SRE
					ticks += 5;
					write(address, sre(read(zpg())));

				case 0x4f:
					// SRE
					ticks += 6;
					write(address, sre(read(abs())));

				case 0x53:
					// SRE
					ticks += 8;
					write(address, sre(read(iny())));

				case 0x57:
					// SRE
					ticks += 6;
					write(address, sre(read(zpx())));

				case 0x5b:
					// SRE
					ticks += 7;
					write(address, sre(read(aby())));

				case 0x5f:
					// SRE
					ticks += 7;
					write(address, sre(read(abx())));

				case 0xc3:
					// DCP
					ticks += 8;
					write(address, dcp(read(inx())));

				case 0xc7:
					// DCP
					ticks += 5;
					write(address, dcp(read(zpg())));

				case 0xcf:
					// DCP
					ticks += 6;
					write(address, dcp(read(abs())));

				case 0xd3:
					// DCP
					ticks += 8;
					write(address, dcp(read(iny())));

				case 0xd7:
					// DCP
					ticks += 6;
					write(address, dcp(read(zpx())));

				case 0xdb:
					// DCP
					ticks += 7;
					write(address, dcp(read(aby())));

				case 0xdf:
					// DCP
					ticks += 7;
					write(address, dcp(read(abx())));

				case 0xe3:
					// ISC
					ticks += 8;
					value = (read(inx()) + 1) & 0xff;
					write(address, value);
					sbc(value);

				case 0xe7:
					// ISC
					ticks += 5;
					value = (read(zpg()) + 1) & 0xff;
					write(address, value);
					sbc(value);

				case 0xef:
					// ISC
					ticks += 6;
					value = (read(abs()) + 1) & 0xff;
					write(address, value);
					sbc(value);

				case 0xf3:
					// ISC
					ticks += 8;
					value = (read(iny()) + 1) & 0xff;
					write(address, value);
					sbc(value);

				case 0xf7:
					// ISC
					ticks += 6;
					value = (read(zpx()) + 1) & 0xff;
					write(address, value);
					sbc(value);

				case 0xfb:
					// ISC
					ticks += 7;
					value = (read(aby()) + 1) & 0xff;
					write(address, value);
					sbc(value);

				case 0xff:
					// ISC
					ticks += 7;
					value = (read(abx()) + 1) & 0xff;
					write(address, value);
					sbc(value);

				case 0x00:
					// BRK
					ticks += 7;
					dummyRead(pc++);
					breakInterrupt();

				case 0x4b:
					// ALR
					ticks += 2;
					a &= imm();
					cf = a & 1 != 0;
					a >>= 1;
					a &= 0x7f;
					setFlags(a);

				case 0x0b:
					// ANC
					ticks += 2;
					a &= imm();
					cf = nf = a & 0x80 == 0x80;
					zf = a == 0;

				case 0x2b:
					// ANC
					ticks += 2;
					a &= imm();
					cf = nf = a & 0x80 == 0x80;
					zf = a == 0;

				case 0x6b:
					// ARR
					ticks += 2;
					a = (((imm() & a) >> 1) | (cf ? 0x80 : 0x00));
					zf = a == 0;
					nf = a & 0x80 == 0x80;
					cf = a & 0x40 == 0x40;
					of = a & 0x20 == 0x20 != cf;

				case 0xcb:
					// AXS
					ticks += 2;
					x = (a & x) - imm();
					cf = (x >= 0);
					setFlags(x);

				case 0x9c:
					// SYA
					ticks += 5;
					abs();
					value = (y & ((address >> 8) + 1)) & 0xff;
					var tmp = (address - x) & 0xff;
					if (x + tmp <= 0xff)
					{
						write(address, value);
					}
					else
					{
						write(address, read(address));
					}

				case 0x9e:
					// SXA
					ticks += 5;
					abs();
					value = (x & ((address >> 8) + 1)) & 0xff;
					var tmp = (address - y) & 0xff;
					if (y + tmp <= 0xff)
					{
						write(address, value);
					}
					else
					{
						write(address, read(address));
					}

				case 0x93:
					// AHX
					ticks += 6;
					ahx(iny());

				case 0x9f:
					// AHX
					ticks += 5;
					ahx(aby());

				case 0x02, 0x12, 0x22, 0x32, 0x42, 0x52, 0x62, 0x72,
					0x92, 0xb2, 0xd2, 0xf2:
					// KIL

				default:
					throw "Invalid instruction: $" + StringTools.hex(byte);
			}

#if cputrace
			Sys.print("\n");
#end

			tick(ticks);
			pc &= 0xffff;
		}
	}

	inline function ora(value:Int)
	{
		a |= value;
		setFlags(a);
	}

	inline function and(value:Int)
	{
		a &= value;
		setFlags(a);
	}

	inline function eor(value:Int)
	{
		a = value ^ a;
		setFlags(a);
	}

	inline function asl(value:Int)
	{
		cf = value & 0x80 != 0;
		value = (value << 1) & 0xff;
		setFlags(value);
		return value;
	}

	inline function lsr(value:Int)
	{
		cf = value & 1 != 0;
		value = value >> 1;
		setFlags(value);
		return value;
	}

	inline function rol(value:Int)
	{
		var new_cf = value & 0x80 != 0;
		value = ((value << 1) + (cf ? 1 : 0)) & 0xff;
		cf = new_cf;
		setFlags(value);
		return value;
	}

	inline function ror(value)
	{
		var new_cf = value & 1 != 0;
		value = (value >> 1) & 0xff;
		value += cf ? 0x80 : 0;
		cf = new_cf;
		setFlags(value);
		return value;
	}

	inline function branch(cond:Bool):Void
	{
		if (cond)
		{
			addTicks(1);
			pc = rel();
		}
		else
		{
			++pc;
		}
	}

	inline function cmp(cmpTo:Int, value:Int):Void
	{
		var tmp = cmpTo - value;
		if (tmp < 0)
			tmp += 0xff + 1;

		cf = cmpTo >= value;
		zf = cmpTo == value;
		nf = tmp & 0x80 == 0x80;
	}

	inline function adc(value:Int):Int
	{
		var tmp = value + a + (cf ? 1 : 0);
		cf = (tmp >> 8 != 0);
		of = (((a ^ value) & 0x80) == 0)
				&& (((a ^ tmp) & 0x80) != 0);
		a = tmp & 0xff;

		setFlags(a);

		return a;
	}

	inline function sbc(value:Int):Int
	{
		var tmp = a - value - (cf ? 0 : 1);
		cf = (tmp >> 8 == 0);
		of = (((a ^ value) & 0x80) != 0)
				&& (((a ^ tmp) & 0x80) != 0);
		a = tmp & 0xff;

		setFlags(a);

		return a;
	}

	inline function inc(value:Int)
	{
		value = (value + 1) & 0xff;
		setFlags(value);
		return value;
	}

	inline function dec(value:Int)
	{
		value = (value - 1) & 0xff;
		setFlags(value);
		return value;
	}

	inline function rla(value:Int)
	{
		value = rol(value);
		and(value);
		return value;
	}

	inline function rra(value:Int)
	{
		value = ror(value);
		adc(value);
		return value;
	}

	inline function slo(value:Int)
	{
		cf = value & 0x80 != 0;
		value = (value << 1) & 0xff;
		a |= value;
		setFlags(a);
		return value;
	}

	inline function sre(value:Int)
	{
		cf = value & 1 != 0;
		value = value >> 1;
		a = value ^ a;
		setFlags(a);
		return value;
	}

	inline function dcp(value:Int)
	{
		value = (value - 1) & 0xff;
		var tmp = a - value;
		if (tmp < 0) tmp += 0xff + 1;
		cf = a >= value;
		zf = a == value;
		nf = tmp & 0x80 == 0x80;
		return value;
	}

	inline function ahx(addr:Int)
	{
		var value = (a & x & ((addr >> 8) + 1)) & 0xff;
		var tmp = (addr - y) & 0xff;
		if (y + tmp <= 0xff)
		{
			write(addr, value);
		}
		else
		{
			write(addr, read(address));
		}
	}

	inline function imm()
	{
		return address = readpc();
	}

	inline function zpg()
	{
		return address = readpc();
	}

	inline function zpx()
	{
		return address = (readpc() + x) & 0xff;
	}

	inline function zpy()
	{
		return address = (readpc() + y) & 0xff;
	}

	inline function rel()
	{
		address = getSigned(readpc());
		address = (address + pc) & 0xffff;
		if ((address & 0xff00) != (pc & 0xff00)) ticks += 1;
		return address;
	}

	inline function ind()
	{
		address = readpc() | (readpc() << 8);
		var next_addr = address + 1;
		if (next_addr & 0xff == 0)
		{
			next_addr -= 0x0100;
		}
		return address = ((read(address) & 0xff) | (read(next_addr) << 8)) & 0xffff;
	}

	inline function inx()
	{
		address = readpc();
		address += x;
		address &= 0xff;
		return address = ((read(address) & 0xff) | (read((address+1) & 0xff) << 8)) & 0xffff;
	}

	inline function iny()
	{
		address = readpc();
		return address = (((read(address) & 0xff) | (read((address+1) & 0xff) << 8)) + y) & 0xffff;
	}

	inline function inyPb()
	{
		address = readpc();
		address = (read(address) & 0xff) | (read((address+1) & 0xff) << 8);
		// new page
		if (address&0xff00 != (address+y)&0xff00) ticks += 1;
		return address = (address + y) & 0xffff;
	}

	inline function abs()
	{
		return address = (readpc() | (readpc() << 8)) & 0xffff;
	}

	inline function abx()
	{
		return address = ((readpc() | (readpc() << 8)) + x) & 0xffff;
	}

	inline function abxPb()
	{
		address = readpc() | (readpc() << 8);
		// new page
		if (address&0xff00 != (address+x)&0xff00) ticks += 1;
		return address = (address + x) & 0xffff;
	}

	inline function aby()
	{
		return address = ((readpc() | (readpc() << 8)) + y) & 0xffff;
	}

	inline function abyPb()
	{
		address = readpc() | (readpc() << 8);
		// new page
		if (address&0xff00 != (address+y)&0xff00) ticks += 1;
		return address = (address + y) & 0xffff;
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

	inline function read(addr:Int):Int
	{
		tick(1);
		return memory.read(addr & 0xffff) & 0xff;
	}

	inline function readpc()
	{
		return read(pc++);
	}

	inline function dummyRead(addr:Int):Void
	{
		read(addr);
	}

	inline function write(addr:Int, data:Int):Void
	{
		tick(1);
		memory.write(addr & 0xffff, data & 0xff);
	}

	inline function doNmi()
	{
		pushStack(pc >> 8);
		pushStack(pc & 0xff);
		pushStack(statusFlag);
		pc = read(0xfffa) | (read(0xfffb) << 8);
		addTicks(7);
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

	inline function addTicks(ticks:Int)
	{
		cycles += ticks;
		apuCycles += ticks;
		cycleCount += ticks;
	}

	inline function tick(ticks:Int)
	{
		cycles += ticks;
		apuCycles += ticks;
		cycleCount += ticks;
		this.ticks -= ticks;
	}

	inline function setFlags(value:Int)
	{
		zf = value == 0;
		nf = value & 0x80 == 0x80;
	}

	inline function getSigned(byte:Int):Int
	{
		byte &= 0xff;
		return (byte & 0x80 != 0) ? -((~(byte - 1)) & 0xff) : byte;
	}
}
