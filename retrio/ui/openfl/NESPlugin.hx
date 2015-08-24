package retrio.ui.openfl;

import haxe.ds.Vector;
import flash.Lib;
import flash.Memory;
import flash.display.Sprite;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.events.Event;
import flash.events.TimerEvent;
import flash.geom.Rectangle;
import flash.geom.Matrix;
import flash.utils.ByteArray;
import retrio.config.GlobalSettings;
import retrio.emu.nes.NES;
import retrio.emu.nes.Palette;


@:access(retrio.emu.nes.NES)
class NESPlugin extends EmulatorPlugin
{
	static var _name:String = "nes";

	static inline var AUDIO_BUFFER_SIZE = 0x800;
	static var _registered = Shell.registerPlugin(_name, new NESPlugin());

	var _stage(get, never):flash.display.Stage;
	inline function get__stage() return Lib.current.stage;

	var nes:NES;

	var frameCount = 0;

	public function new()
	{
		super();

		controllers = new Vector(2);

		this.emu = this.nes = new NES();
		screenBuffer = new BitmapScreenBuffer(NES.WIDTH, NES.HEIGHT);
		screenBuffer.clipTop = 8;
		screenBuffer.clipBottom = 8;

		this.settings = GlobalSettings.settings.concat(
			retrio.emu.nes.Settings.settings
		).concat(
			NESControls.settings(this)
		);
		extensions = nes.extensions;

		if (Std.is(screenBuffer, Bitmap)) addChildAt(cast(screenBuffer, Bitmap), 0);
	}

	override public function resize(width:Int, height:Int)
	{
		if (width == 0 || height == 0)
			return;

		screenBuffer.resize(width, height);
		initialized = true;
	}

	override public function frame()
	{
		if (!initialized) return;

		if (running)
		{
			super.frame();
			nes.frame(frameRate);

			if (frameSkip > 0)
			{
				frameCount = (frameCount + 1) % (frameSkip + 1);
				if (frameCount > 0) return;
			}

			screenBuffer.render();
		}
	}

	override public function activate()
	{
		super.activate();
	}

	override public function deactivate()
	{
		super.deactivate();
		nes.apu.buffer.clear();
		nes.saveSram();
	}

	var _buffering:Bool = true;
	override public function getSamples(e:Dynamic)
	{
		nes.apu.catchUp();

		var l:Int;
		if (_buffering)
		{
			l = Std.int(Math.max(0, AUDIO_BUFFER_SIZE * 2 - nes.apu.buffer.length));
			if (l <= 0) _buffering = false;
			else l = AUDIO_BUFFER_SIZE;
		}
		else
		{
			// not enough samples; buffer until more arrive
			l = Std.int(Math.max(0, AUDIO_BUFFER_SIZE - nes.apu.buffer.length));
			if (l > 0)
			{
				_buffering = true;
			}
		}

		for (i in 0 ... l)
		{
			e.data.writeDouble(0);
		}

		var s:Float = 0;
		for (i in l ... AUDIO_BUFFER_SIZE)
		{
			e.data.writeFloat(s = (volume * Util.clamp(nes.apu.buffer.pop() * 0xf, 0, 1)));
			e.data.writeFloat(s);
		}
	}

	override public function setSetting(id:String, value:Dynamic):Void
	{
		switch (id)
		{
			default:
				super.setSetting(id, value);
		}
	}
}
