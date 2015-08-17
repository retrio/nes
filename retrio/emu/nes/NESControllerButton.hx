package retrio.emu.nes;


@:enum
abstract NESControllerButton(Int) from Int to Int
{
	public static var buttons = [Up,Down,Left,Right,A,B,Select,Start];
	public static var buttonNames:Map<Int, String> = [
		Up => "Up",
		Down => "Down",
		Left => "Left",
		Right => "Right",
		A => "A",
		B => "B",
		Select => "Select",
		Start => "Start",
	];

	var A = 0;
	var B = 1;
	var Select = 2;
	var Start = 3;
	var Up = 4;
	var Down = 5;
	var Left = 6;
	var Right = 7;
}
