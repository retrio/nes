package strafe.emu.nes;


// http://www.obelisk.demon.co.uk/6502/addressing.html
@:enum
abstract AddressingMode(Int) from Int to Int
{
	var Accumulator = 1;
	var Immediate = 2;
	var ZeroPage = 3;
	var ZeroPageX = 4;
	var ZeroPageY = 5;
	var Relative = 6;
	var Absolute = 7;
	var AbsoluteX = 8;
	var AbsoluteY = 9;
	var Indirect = 10;
	var IndirectX = 11;
	var IndirectY = 12;

	public static var addressingModeNames = [
		Accumulator => "Accumulator",
		Immediate => "Immediate",
		ZeroPage => "ZeroPage",
		ZeroPageX => "ZeroPageX",
		ZeroPageY => "ZeroPageY",
		Relative => "Relative",
		Absolute => "Absolute",
		AbsoluteX => "AbsoluteX",
		AbsoluteY => "AbsoluteY",
		Indirect => "Indirect",
		IndirectX => "IndirectX",
		IndirectY => "IndirectY",
	];
}
