import strafe.ui.openfl.KeyboardController;
import strafe.FileWrapper;
import strafe.ui.openfl.NESPlugin;
import strafe.ui.openfl.Shell;


class Main extends strafe.ui.openfl.Shell
{
	function new()
	{
		super();

		var fileName = "assets/roms/mario.nes";
		var file = FileWrapper.read(fileName);

		var controller = new strafe.ui.openfl.KeyboardController();

		var plugin = new NESPlugin();
		plugin.loadGame(file);
		plugin.addController(controller);
		plugin.start();

		loadPlugin(plugin);

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
}
