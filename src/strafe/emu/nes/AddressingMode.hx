package strafe.emu.nes;


// http://www.obelisk.demon.co.uk/6502/addressing.html
@:enum
abstract AddressingMode(Int) from Int to Int
{
	static inline var pos:Int = 0x8;
	var Accumulator = 0x01<<pos;
	var Immediate = 0x02<<pos;
	var ZeroPage = 0x03<<pos;
	var ZeroPageX = 0x04<<pos;
	var ZeroPageY = 0x05<<pos;
	var Relative = 0x06<<pos;
	var Absolute = 0x07<<pos;
	var AbsoluteX = 0x08<<pos;
	var AbsoluteY = 0x09<<pos;
	var Indirect = 0x10<<pos;
	var IndirectX = 0x11<<pos;
	var IndirectY = 0x12<<pos;

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
