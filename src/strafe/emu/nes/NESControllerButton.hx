package strafe.emu.nes;


@:enum
abstract NESControllerButton(Int) from Int to Int
{
	var A = 0;
	var B = 1;
	var Select = 2;
	var Start = 3;
	var Up = 4;
	var Down = 5;
	var Left = 6;
	var Right = 7;
}
