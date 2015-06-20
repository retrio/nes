package strafe.emu.nes;

import haxe.ds.Vector;


// http://www.obelisk.demon.co.uk/6502/reference.html
@:enum
abstract OpCode(Int) from Int to Int
{
	var ORA = 0x01;		// logical OR
	var AND = 0x02;		// logical AND
	var EOR = 0x03;		// exclusive or
	var ADC = 0x04;		// add with carry
	var STA = 0x05;		// store accumulator
	var LDA = 0x06;		// load accumulator
	var CMP = 0x07;		// compare
	var SBC = 0x08;		// subtract with carry
	var ASL = 0x09;		// arithmetic shift left
	var ROL = 0x10;		// rotate left
	var LSR = 0x11;		// logical shift right
	var ROR = 0x12;		// rotate right
	var STX = 0x13;		// store X
	var LDX = 0x14;		// load X
	var DEC = 0x15;		// decrement memory
	var INC = 0x16;		// increment memory
	var BIT = 0x17;		// bit test
	var JMP = 0x18;		// jump
	var STY = 0x19;		// store Y
	var LDY = 0x20;		// load Y
	var CPY = 0x21;		// compare Y
	var CPX = 0x22;		// compare X
	var BCC = 0x23;		// branch if carry clear
	var BCS = 0x24;		// branch if carry set
	var BEQ = 0x25;		// branch if equal
	var BMI = 0x26;		// branch if minus
	var BNE = 0x27;		// branch if not equal
	var BPL = 0x28;		// branch if positive
	var BVC = 0x29;		// branch if overflow clear
	var BVS = 0x30;		// branch if overflow set
	var BRK = 0x31;		// force interrupt
	var CLC = 0x32;		// clear carry flag
	var CLD = 0x33;		// clear decimal mode
	var CLI = 0x34;		// clear interrupt disable
	var CLV = 0x35;		// clear overflow flag
	var DEX = 0x36;		// decrement X register
	var DEY = 0x37;		// decrement Y register
	var INX = 0x38;		// increment X register
	var INY = 0x39;		// increment Y register
	var JSR = 0x40;		// jump to subroutine
	var NOP = 0x41;		// no operation
	var IGN1 = 0x42;		// nop +1
	var IGN2 = 0x43;		// nop +2
	var PHA = 0x44;		// push accumulator
	var PHP = 0x45;		// push processor status
	var PLA = 0x46;		// pull accumulator
	var PLP = 0x47;		// pull processor status
	var RTI = 0x48;		// return from interrupt
	var RTS = 0x49;		// return from subroutine
	var SEC = 0x50;		// set carry flag
	var SED = 0x51;		// set decimal flag
	var SEI = 0x52;		// set interrupt disabled
	var TAX = 0x53;		// transfer accumulator to X
	var TAY = 0x54;		// transfer accumulator to Y
	var TSX = 0x55;		// transfer stack pointer to X
	var TSY = 0x56;		// transfer stack pointer to Y
	var TYA = 0x57;		// transfer Y to accumulator
	var TXS = 0x58;		// transfer X to stack pointer
	var TXA = 0x59;		// transfer X to stack pointer

		// unofficial

	var LAX = 0x60;		// load both accumulator and X
	var SAX = 0x61;		// AND, CMP and store
	var RLA = 0x62;		// ROL then AND
	var RRA = 0x63;		// ROR then ADC
	var SLO = 0x64;		// ASL then ORA
	var SRE = 0x65;		// LSR then EOR
	var DCP = 0x66;		// DEC then COMP
	var ISC = 0x67;		// INC then SBC

	var ALR = 0x68;		// AND then LSR
	var ANC = 0x69;		// AND, copy N to C
	var ARR = 0x70;		// AND then ROR
	var AXS = 0x71;		// set X to (acc AND X) - (value w/o borrow)

	var UNKNOWN = 0x0;

	public static var opCodeNames=[
		ORA => "ORA",
		AND => "AND",
		EOR => "EOR",
		ADC => "ADC",
		STA => "STA",
		LDA => "LDA",
		CMP => "CMP",
		SBC => "SBC",
		ASL => "ASL",
		ROL => "ROL",
		LSR => "LSR",
		ROR => "ROR",
		STX => "STX",
		LDX => "LDX",
		DEC => "DEC",
		INC => "INC",
		BIT => "BIT",
		JMP => "JMP",
		STY => "STY",
		LDY => "LDY",
		CPY => "CPY",
		CPX => "CPX",
		BCC => "BCC",
		BCS => "BCS",
		BEQ => "BEQ",
		BMI => "BMI",
		BNE => "BNE",
		BPL => "BPL",
		BVC => "BVC",
		BVS => "BVS",
		BRK => "BRK",
		CLC => "CLC",
		CLD => "CLD",
		CLI => "CLI",
		CLV => "CLV",
		DEX => "DEX",
		DEY => "DEY",
		INX => "INX",
		INY => "INY",
		JSR => "JSR",
		NOP => "NOP",
		IGN1 => "IGN1",
		IGN2 => "IGN2",
		PHA => "PHA",
		PHP => "PHP",
		PLA => "PLA",
		PLP => "PLP",
		RTI => "RTI",
		RTS => "RTS",
		SEC => "SEC",
		SED => "SED",
		SEI => "SEI",
		TAX => "TAX",
		TAY => "TAY",
		TSX => "TSX",
		TSY => "TSY",
		TYA => "TYA",
		TXS => "TXS",
		TXA => "TXA",
		LAX => "LAX",
		SAX => "SAX",
		RLA => "RLA",
		RRA => "RRA",
		SLO => "SLO",
		SRE => "SRE",
		DCP => "DCP",
		ISC => "ISC",

		ALR => "ALR",
		ANC => "ANC",
		ARR => "ARR",
		AXS => "AXS",

		UNKNOWN => "UNKNOWN",
	];

	static var _codes:Vector<OpCode> = new Vector(0x100);
	static var _modes:Vector<AddressingMode> = new Vector(0x100);
	static var _ticks:Vector<Int> = new Vector(0x100);
	static var _initialized = decodeBytes();

	public static inline function getCode(byte:UInt):OpCode return _codes[byte];
	public static inline function getAddressingMode(byte:UInt):AddressingMode return _modes[byte];
	public static inline function getTicks(byte:UInt):Int return _ticks[byte];

	public static inline function decodeBytes():Bool
	{
		for (byte in 0 ... 0x100)
		{
			var code:OpCode = UNKNOWN;
			var mode:AddressingMode = AddressingMode.Absolute;
			var ticks:Int = 2;

			switch(byte)
			{
				// this section auto-generated by parse6502.py
				case 0x00: { code=BRK; ticks=7; }
				case 0x01: { code=ORA; mode=AddressingMode.IndirectX; ticks=6; }
				case 0x05: { code=ORA; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0x06: { code=ASL; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0x08: { code=PHP; ticks=3; }
				case 0x09: { code=ORA; mode=AddressingMode.Immediate; }
				case 0x0A: { code=ASL; mode=AddressingMode.Accumulator; }
				case 0x0D: { code=ORA; ticks=4; }
				case 0x0E: { code=ASL; ticks=6; }
				case 0x10: { code=BPL; mode=AddressingMode.Relative; }
				case 0x11: { code=ORA; mode=AddressingMode.IndirectY; ticks=5; }
				case 0x15: { code=ORA; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0x16: { code=ASL; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0x18: { code=CLC; }
				case 0x19: { code=ORA; mode=AddressingMode.AbsoluteY; ticks=4; }
				case 0x1D: { code=ORA; mode=AddressingMode.AbsoluteX; ticks=4; }
				case 0x1E: { code=ASL; mode=AddressingMode.AbsoluteX; ticks=7; }
				case 0x20: { code=JSR; ticks=6; }
				case 0x21: { code=AND; mode=AddressingMode.IndirectX; ticks=6; }
				case 0x24: { code=BIT; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0x25: { code=AND; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0x26: { code=ROL; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0x28: { code=PLP; ticks=4; }
				case 0x29: { code=AND; mode=AddressingMode.Immediate; }
				case 0x2A: { code=ROL; mode=AddressingMode.Accumulator; }
				case 0x2C: { code=BIT; ticks=4; }
				case 0x2D: { code=AND; ticks=4; }
				case 0x2E: { code=ROL; ticks=6; }
				case 0x30: { code=BMI; mode=AddressingMode.Relative; }
				case 0x31: { code=AND; mode=AddressingMode.IndirectY; ticks=5; }
				case 0x35: { code=AND; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0x36: { code=ROL; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0x38: { code=SEC; }
				case 0x39: { code=AND; mode=AddressingMode.AbsoluteY; ticks=4; }
				case 0x3D: { code=AND; mode=AddressingMode.AbsoluteX; ticks=4; }
				case 0x3E: { code=ROL; mode=AddressingMode.AbsoluteX; ticks=7; }
				case 0x40: { code=RTI; ticks=6; }
				case 0x41: { code=EOR; mode=AddressingMode.IndirectX; ticks=6; }
				case 0x45: { code=EOR; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0x46: { code=LSR; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0x48: { code=PHA; ticks=3; }
				case 0x49: { code=EOR; mode=AddressingMode.Immediate; }
				case 0x4A: { code=LSR; mode=AddressingMode.Accumulator; }
				case 0x4C: { code=JMP; ticks=3; }
				case 0x4D: { code=EOR; ticks=4; }
				case 0x4E: { code=LSR; ticks=6; }
				case 0x50: { code=BVC; mode=AddressingMode.Relative; }
				case 0x51: { code=EOR; mode=AddressingMode.IndirectY; ticks=5; }
				case 0x55: { code=EOR; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0x56: { code=LSR; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0x58: { code=CLI; }
				case 0x59: { code=EOR; mode=AddressingMode.AbsoluteY; ticks=4; }
				case 0x5D: { code=EOR; mode=AddressingMode.AbsoluteX; ticks=4; }
				case 0x5E: { code=LSR; mode=AddressingMode.AbsoluteX; ticks=7; }
				case 0x60: { code=RTS; ticks=6; }
				case 0x61: { code=ADC; mode=AddressingMode.IndirectX; ticks=6; }
				case 0x65: { code=ADC; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0x66: { code=ROR; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0x68: { code=PLA; ticks=4; }
				case 0x69: { code=ADC; mode=AddressingMode.Immediate; }
				case 0x6A: { code=ROR; mode=AddressingMode.Accumulator; }
				case 0x6C: { code=JMP; mode=AddressingMode.Indirect; ticks=5; }
				case 0x6D: { code=ADC; ticks=4; }
				case 0x6E: { code=ROR; ticks=6; }
				case 0x70: { code=BVS; mode=AddressingMode.Relative; }
				case 0x71: { code=ADC; mode=AddressingMode.IndirectY; ticks=5; }
				case 0x75: { code=ADC; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0x76: { code=ROR; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0x78: { code=SEI; }
				case 0x79: { code=ADC; mode=AddressingMode.AbsoluteY; ticks=4; }
				case 0x7D: { code=ADC; mode=AddressingMode.AbsoluteX; ticks=4; }
				case 0x7E: { code=ROR; mode=AddressingMode.AbsoluteX; ticks=7; }
				case 0x81: { code=STA; mode=AddressingMode.IndirectX; ticks=6; }
				case 0x84: { code=STY; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0x85: { code=STA; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0x86: { code=STX; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0x88: { code=DEY; }
				case 0x8A: { code=TXA; }
				case 0x8C: { code=STY; ticks=4; }
				case 0x8D: { code=STA; ticks=4; }
				case 0x8E: { code=STX; ticks=4; }
				case 0x90: { code=BCC; mode=AddressingMode.Relative; }
				case 0x91: { code=STA; mode=AddressingMode.IndirectY; ticks=6; }
				case 0x94: { code=STY; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0x95: { code=STA; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0x96: { code=STX; mode=AddressingMode.ZeroPageY; ticks=4; }
				case 0x98: { code=TYA; }
				case 0x99: { code=STA; mode=AddressingMode.AbsoluteY; ticks=5; }
				case 0x9A: { code=TXS; }
				case 0x9D: { code=STA; mode=AddressingMode.AbsoluteX; ticks=5; }
				case 0xA0: { code=LDY; mode=AddressingMode.Immediate; }
				case 0xA1: { code=LDA; mode=AddressingMode.IndirectX; ticks=6; }
				case 0xA2: { code=LDX; mode=AddressingMode.Immediate; }
				case 0xA4: { code=LDY; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0xA5: { code=LDA; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0xA6: { code=LDX; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0xA8: { code=TAY; }
				case 0xA9: { code=LDA; mode=AddressingMode.Immediate; }
				case 0xAA: { code=TAX; }
				case 0xAC: { code=LDY; ticks=4; }
				case 0xAD: { code=LDA; ticks=4; }
				case 0xAE: { code=LDX; ticks=4; }
				case 0xB0: { code=BCS; mode=AddressingMode.Relative; }
				case 0xB1: { code=LDA; mode=AddressingMode.IndirectY; ticks=5; }
				case 0xB4: { code=LDY; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0xB5: { code=LDA; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0xB6: { code=LDX; mode=AddressingMode.ZeroPageY; ticks=4; }
				case 0xB8: { code=CLV; }
				case 0xB9: { code=LDA; mode=AddressingMode.AbsoluteY; ticks=4; }
				case 0xBA: { code=TSX; }
				case 0xBC: { code=LDY; mode=AddressingMode.AbsoluteX; ticks=4; }
				case 0xBD: { code=LDA; mode=AddressingMode.AbsoluteX; ticks=4; }
				case 0xBE: { code=LDX; mode=AddressingMode.AbsoluteY; ticks=4; }
				case 0xC0: { code=CPY; mode=AddressingMode.Immediate; }
				case 0xC1: { code=CMP; mode=AddressingMode.IndirectX; ticks=6; }
				case 0xC4: { code=CPY; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0xC5: { code=CMP; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0xC6: { code=DEC; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0xC8: { code=INY; }
				case 0xC9: { code=CMP; mode=AddressingMode.Immediate; }
				case 0xCA: { code=DEX; }
				case 0xCC: { code=CPY; ticks=4; }
				case 0xCD: { code=CMP; ticks=4; }
				case 0xCE: { code=DEC; ticks=6; }
				case 0xD0: { code=BNE; mode=AddressingMode.Relative; }
				case 0xD1: { code=CMP; mode=AddressingMode.IndirectY; ticks=5; }
				case 0xD5: { code=CMP; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0xD6: { code=DEC; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0xD8: { code=CLD; }
				case 0xD9: { code=CMP; mode=AddressingMode.AbsoluteY; ticks=4; }
				case 0xDD: { code=CMP; mode=AddressingMode.AbsoluteX; ticks=4; }
				case 0xDE: { code=DEC; mode=AddressingMode.AbsoluteX; ticks=7; }
				case 0xE0: { code=CPX; mode=AddressingMode.Immediate; }
				case 0xE1: { code=SBC; mode=AddressingMode.IndirectX; ticks=6; }
				case 0xE4: { code=CPX; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0xE5: { code=SBC; mode=AddressingMode.ZeroPage; ticks=3; }
				case 0xE6: { code=INC; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0xE8: { code=INX; }
				case 0xE9: { code=SBC; mode=AddressingMode.Immediate; }
				case 0xEA: { code=NOP; }
				case 0xEC: { code=CPX; ticks=4; }
				case 0xED: { code=SBC; ticks=4; }
				case 0xEE: { code=INC; ticks=6; }
				case 0xF0: { code=BEQ; mode=AddressingMode.Relative; }
				case 0xF1: { code=SBC; mode=AddressingMode.IndirectY; ticks=5; }
				case 0xF5: { code=SBC; mode=AddressingMode.ZeroPageX; ticks=4; }
				case 0xF6: { code=INC; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0xF8: { code=SED; }
				case 0xF9: { code=SBC; mode=AddressingMode.AbsoluteY; ticks=4; }
				case 0xFD: { code=SBC; mode=AddressingMode.AbsoluteX; ticks=4; }
				case 0xFE: { code=INC; mode=AddressingMode.AbsoluteX; ticks=7; }

				// the following are unofficial opcodes
				// http://wiki.nesdev.com/w/index.php/Programming_with_unofficial_OpCode

				// NOOP +
				case 0x1A,0x3A,0x5A,0x7A,0xDA,0xFA: {
					code=NOP;
				}
				case 0x80,0x82,0x89,0xC2,0xE2: {
					code=IGN1;
				}
				case 0x04,0x44,0x64: {
					code=IGN1;
					ticks=3;
				}
				case 0x14,0x34,0x54,0x74,0xD4,0xF4: {
					code=IGN1;
					ticks=4;
				}
				case 0x0C: {
					code=IGN2;
					ticks = 4;
				}
				case 0x1C,0x3C,0x5C,0x7C,0xDC,0xFC: {
					code=IGN2;
					// warning: can be 5 ticks if crossing page boundary
					ticks=4;
				}
				// LAX
				case 0xA3: {
					code=LAX;
					mode=AddressingMode.IndirectX;
					ticks=6;
				}
				case 0xA7: {
					code=LAX;
					mode=AddressingMode.ZeroPage;
					ticks=3;
				}
				case 0xAF: {
					code=LAX;
					mode=AddressingMode.Absolute;
					ticks=4;
				}
				case 0xB3: {
					code=LAX;
					mode=AddressingMode.IndirectY;
					ticks=5;
				}
				case 0xB7: {
					code=LAX;
					mode=AddressingMode.ZeroPageY;
					ticks=4;
				}
				case 0xBF: {
					code=LAX;
					mode=AddressingMode.AbsoluteY;
					ticks=4;
				}
				// SAX
				case 0x83: {
					code=SAX;
					mode=AddressingMode.IndirectX;
					ticks=6;
				}
				case 0x87: {
					code=SAX;
					mode=AddressingMode.ZeroPage;
					ticks=3;
				}
				case 0x8F: {
					code=SAX;
					mode=AddressingMode.Absolute;
					ticks=4;
				}
				case 0x97: {
					code=SAX;
					mode=AddressingMode.ZeroPageY;
					ticks=4;
				}
				// SBC
				case 0xEB: { code=SBC; mode=AddressingMode.Immediate; }
				// RLA
				case 0x23: { code=RLA; mode=AddressingMode.IndirectX; ticks=8; }
				case 0x27: { code=RLA; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0x2F: { code=RLA; mode=AddressingMode.Absolute; ticks=6; }
				case 0x33: { code=RLA; mode=AddressingMode.IndirectY; ticks=8; }
				case 0x37: { code=RLA; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0x3B: { code=RLA; mode=AddressingMode.AbsoluteY; ticks=7; }
				case 0x3F: { code=RLA; mode=AddressingMode.AbsoluteX; ticks=7; }
				// RRA
				case 0x63: { code=RRA; mode=AddressingMode.IndirectX; ticks=8; }
				case 0x67: { code=RRA; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0x6F: { code=RRA; mode=AddressingMode.Absolute; ticks=6; }
				case 0x73: { code=RRA; mode=AddressingMode.IndirectY; ticks=8; }
				case 0x77: { code=RRA; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0x7B: { code=RRA; mode=AddressingMode.AbsoluteY; ticks=7; }
				case 0x7F: { code=RRA; mode=AddressingMode.AbsoluteX; ticks=7; }
				// SLO
				case 0x03: { code=SLO; mode=AddressingMode.IndirectX; ticks=8; }
				case 0x07: { code=SLO; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0x0F: { code=SLO; mode=AddressingMode.Absolute; ticks=6; }
				case 0x13: { code=SLO; mode=AddressingMode.IndirectY; ticks=8; }
				case 0x17: { code=SLO; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0x1B: { code=SLO; mode=AddressingMode.AbsoluteY; ticks=7; }
				case 0x1F: { code=SLO; mode=AddressingMode.AbsoluteX; ticks=7; }
				// SRE
				case 0x43: { code=SRE; mode=AddressingMode.IndirectX; ticks=8; }
				case 0x47: { code=SRE; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0x4F: { code=SRE; mode=AddressingMode.Absolute; ticks=6; }
				case 0x53: { code=SRE; mode=AddressingMode.IndirectY; ticks=8; }
				case 0x57: { code=SRE; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0x5B: { code=SRE; mode=AddressingMode.AbsoluteY; ticks=7; }
				case 0x5F: { code=SRE; mode=AddressingMode.AbsoluteX; ticks=7; }
				// DCP
				case 0xC3: { code=DCP; mode=AddressingMode.IndirectX; ticks=8; }
				case 0xC7: { code=DCP; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0xCF: { code=DCP; mode=AddressingMode.Absolute; ticks=6; }
				case 0xD3: { code=DCP; mode=AddressingMode.IndirectY; ticks=8; }
				case 0xD7: { code=DCP; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0xDB: { code=DCP; mode=AddressingMode.AbsoluteY; ticks=7; }
				case 0xDF: { code=DCP; mode=AddressingMode.AbsoluteX; ticks=7; }
				// ISC
				case 0xE3: { code=ISC; mode=AddressingMode.IndirectX; ticks=8; }
				case 0xE7: { code=ISC; mode=AddressingMode.ZeroPage; ticks=5; }
				case 0xEF: { code=ISC; mode=AddressingMode.Absolute; ticks=6; }
				case 0xF3: { code=ISC; mode=AddressingMode.IndirectY; ticks=8; }
				case 0xF7: { code=ISC; mode=AddressingMode.ZeroPageX; ticks=6; }
				case 0xFB: { code=ISC; mode=AddressingMode.AbsoluteY; ticks=7; }
				case 0xFF: { code=ISC; mode=AddressingMode.AbsoluteX; ticks=7; }
				// ALR
				case 0x4B: { code=ALR; mode=AddressingMode.Immediate; ticks=2; }
				// ANC
				case 0x0B: { code=ANC; mode=AddressingMode.Immediate; ticks=2; }
				case 0x2B: { code=ANC; mode=AddressingMode.Immediate; ticks=2; }
				// ARR
				case 0x6B: { code=ARR; mode=AddressingMode.Immediate; ticks=2; }
				// AXS
				case 0xCB: { code=ANC; mode=AddressingMode.Immediate; ticks=2; }

				case 0xAB: { code=LAX; mode=AddressingMode.Immediate; ticks=2; }

				default: code=UNKNOWN;
			}

			_codes[byte] = code;
			_modes[byte] = mode;
			_ticks[byte] = ticks;

		}
		return true;
	}

}
