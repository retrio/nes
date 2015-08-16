package retrio.emu.nes;


class NESController
{
	public var controller:IController;
	var _currentBtn = 0;

	public function new() {}

	public function latch()
	{
		_currentBtn = 0;
	}

	public function pop()
	{
		var pressed:Bool = (controller == null) ? false : controller.pressed(_currentBtn);
		// only last bit is significant, but Paperboy needs exactly 0x40 or 0x41
		var val = pressed ? 0x41 : 0x40;
		++_currentBtn;
		_currentBtn &= 7;
		return val;
	}
}
