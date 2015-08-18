package retrio.ui.openfl;

import retrio.config.SettingCategory;
import retrio.ui.haxeui.ControllerSettingsPage;
import retrio.ui.openfl.controllers.*;
import retrio.emu.nes.NESControllerButton;


class NESControls
{
	public static var controllerImg:String = "graphics/nes_controls.png";

	// String because Class<IController> can't be used as a map key
	public static var defaultBindings:Map<String, Map<Int, Int>> = [
#if (flash || desktop)
		KeyboardController.name => [
			NESControllerButton.Up => 87,
			NESControllerButton.Down => 83,
			NESControllerButton.Left => 65,
			NESControllerButton.Right => 68,
			NESControllerButton.A => 76,
			NESControllerButton.B => 75,
			NESControllerButton.Select => 9,
			NESControllerButton.Start => 13,
		],
#end
	];

	public static function settings(plugin:NESPlugin):Array<SettingCategory>
	{
		return [
			{id: "Controls", name: "Controls", custom: {
				render:ControllerSettingsPage.render.bind(
					plugin,
					controllerImg,
					NESControllerButton.buttons,
					NESControllerButton.buttonNames,
					ControllerInfo.controllerTypes
				),
				save:ControllerSettingsPage.save.bind(plugin)
			}},
		];
	}
}
