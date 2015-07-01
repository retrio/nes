import retrio.ui.openfl.KeyboardController;
import retrio.FileWrapper;
import retrio.ui.openfl.NESPlugin;
import retrio.ui.openfl.Shell;
import retrio.emu.nes.Button;


class Main extends retrio.ui.openfl.Shell
{
	function new()
	{
		super();

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

		var plugin = new NESPlugin();
		var controller = new retrio.ui.openfl.KeyboardController();

		var keyDefaults:Map<Button, Int> = [
			A => 76,
			B => 75,
			Select => 9,
			Start => 13,
			Up => 87,
			Down => 83,
			Left => 65,
			Right => 68
		];
		for (btn in keyDefaults.keys())
			controller.defineKey(keyDefaults[btn], btn);

		plugin.addController(controller);

		loadPlugin(plugin);
	}
}
