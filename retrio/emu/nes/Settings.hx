package retrio.emu.nes;


@:enum
abstract Settings(String) from String to String
{
	var Ch1Volume = "Pulse 1";
	var Ch2Volume = "Pulse 2";
	var Ch3Volume = "Triangle";
	var Ch4Volume = "Noise";
	var Ch5Volume = "DMC";

	public static var settings:Array<SettingCategory> = [
		{
			name: 'NES', settings: [
			],
		},
		{
			name: 'NES Audio', settings: [
				new Setting(Ch1Volume, IntValue(0,100), 100),
				new Setting(Ch2Volume, IntValue(0,100), 100),
				new Setting(Ch3Volume, IntValue(0,100), 100),
				new Setting(Ch4Volume, IntValue(0,100), 100),
				new Setting(Ch5Volume, IntValue(0,100), 100),
			]
		},
	];
}
