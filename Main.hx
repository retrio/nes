import retrio.io.FileWrapper;
import retrio.ui.openfl.NESPlugin;
import retrio.ui.openfl.Shell;
import retrio.ui.openfl.controllers.KeyboardController;
import retrio.emu.nes.NESControllerButton;


class Main extends retrio.ui.openfl.Shell
{
	function new()
	{
		super(retrio.io.IO.defaultIO);

#if (cpp && profile)
		cpp.vm.Profiler.start();
	}

	var _profiling:Bool = true;
	var _f = 0;
	override public function update(e:Dynamic)
	{
		super.update(e);

		if (_profiling)
		{
			_f++;
			trace(_f);
			if (_f >= 60*15)
			{
				trace("DONE");
				cpp.vm.Profiler.stop();
				_profiling = false;
			}
		}
#end
	}

	static function main()
	{
		var m = new Main();
	}

	override function onStage(e:Dynamic)
	{
		super.onStage(e);

		KeyboardController.init();

		var controller = new KeyboardController();
		var keyDefaults = retrio.ui.openfl.NESControls.defaultBindings[KeyboardController.name];
		for (btn in keyDefaults.keys())
			controller.define(keyDefaults[btn], btn);

		loadPlugin("nes");
		addController(controller, 0);
	}
}
