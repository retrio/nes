package strafe.emu.nes;


class NESController
{
	var controller:IController;
	var _currentBtn = 0;

	var keyDefaults:Map<NESControllerButton, Int> = [
		A => 76,
		B => 75,
		Select => 9,
		Start => 13,
		Up => 87,
		Down => 83,
		Left => 65,
		Right => 68
	];

	public function new(controller:IController)
	{
		this.controller = controller;
		//for (btn in defaults.keys())
		//	k.defineKey(defaults[btn], btn);
	}

	public function latch()
	{
		_currentBtn = 0;
	}

	public function pop()
	{
		// only last bit is significant, but Paperboy needs exactly 0x40 or 0x41
		var val = controller.pressed(_currentBtn) ? 0x41 : 0x40;
		++_currentBtn;
		_currentBtn &= 7;
		return val;
	}
}
