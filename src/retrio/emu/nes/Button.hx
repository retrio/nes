package retrio.emu.nes;


@:enum
abstract Button(Int) from Int to Int
{
	public static var buttons = [Up,Down,Left,Right,A,B,Select,Start];

	var A = 0;
	var B = 1;
	var Select = 2;
	var Start = 3;
	var Up = 4;
	var Down = 5;
	var Left = 6;
	var Right = 7;
}
