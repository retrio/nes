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
			id: "nes", name: 'NES', settings: [
			],
		},
		{
			id: "nesaudio", name: 'NES Audio', settings: [
				new Setting(Ch1Volume, "Pulse 1", IntValue(0,100), 100),
				new Setting(Ch2Volume, "Pulse 2", IntValue(0,100), 100),
				new Setting(Ch3Volume, "Triangle", IntValue(0,100), 100),
				new Setting(Ch4Volume, "Noise", IntValue(0,100), 100),
				new Setting(Ch5Volume, "DMC", IntValue(0,100), 100),
			]
		},
	];
}
