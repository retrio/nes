package strafe.emu.nes;


@:enum
abstract MirrorMode(Int) from Int to Int
{
	var H_MIRROR = 1;
	var V_MIRROR = 2;
	var SS_MIRROR0 = 3;
	var SS_MIRROR1 = 4;
	var FOUR_SCREEN_MIRROR = 5;
}
