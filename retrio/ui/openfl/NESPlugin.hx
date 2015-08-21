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
import flash.utils.Endian;
import retrio.config.GlobalSettings;
import retrio.emu.nes.NES;
import retrio.emu.nes.Palette;


@:access(retrio.emu.nes.NES)
class NESPlugin extends EmulatorPlugin
{
	static var _name:String = "nes";

	static inline var AUDIO_BUFFER_SIZE = 0x800;
	static var _registered = Shell.registerPlugin(_name, new NESPlugin());

	var loopStart:Int = 0;
	var loopEnd:Int = 0;
	var clipRect:Rectangle = new Rectangle();

	var clipTop(default, set):Int = 0;
	var clipBottom(default, set):Int = 0;
	var clipLeft(default, set):Int = 0;
	var clipRight(default, set):Int = 0;
	function set_clipTop(y:Int)
	{
		clipTop = y;
		setClip();
		emu.height = NES.HEIGHT - clipTop - clipBottom;
		return y;
	}
	function set_clipBottom(y:Int)
	{
		clipBottom = y;
		setClip();
		emu.height = NES.HEIGHT - clipTop - clipBottom;
		return y;
	}
	function set_clipLeft(x:Int)
	{
		clipLeft = x;
		emu.width = NES.WIDTH - clipLeft - clipRight;
		return x;
	}
	function set_clipRight(x:Int)
	{
		clipRight = x;
		emu.width = NES.WIDTH - clipLeft - clipRight;
		return x;
	}
	function setClip()
	{
		loopStart = clipTop*256;
		loopEnd = (240-(clipBottom))*256;
		r.height = 240-clipBottom-clipTop;
		bmpData.fillRect(bmpData.rect, 0xff000000);
	}

	var _stage(get, never):flash.display.Stage;
	inline function get__stage() return Lib.current.stage;

	var nes:NES;

	var bmp:Bitmap;
	var canvas:BitmapData;
	var bmpData:BitmapData;
	var m:Matrix = new Matrix();
	var pixels:ByteArray = new ByteArray();
	var frameCount = 0;
	var r = new Rectangle(0, 0, 256, 240);

	public function new()
	{
		super();

		controllers = new Vector(2);

		this.emu = this.nes = new NES();
		this.settings = GlobalSettings.settings.concat(
			retrio.emu.nes.Settings.settings
		).concat(
			NESControls.settings(this)
		);
		extensions = nes.extensions;

		bmpData = new BitmapData(256, 240, false, 0);

		pixels.endian = Endian.BIG_ENDIAN;
		pixels.clear();
		for (i in 0 ... 256*240*4)
			pixels.writeByte(0);

		clipTop = 8;
		clipBottom = 8;
		clipLeft = 0;
		clipRight = 0;
	}

	override public function resize(width:Int, height:Int)
	{
		if (width == 0 || height == 0)
			return;

		if (bmp != null)
		{
			removeChild(bmp);
			canvas.dispose();
			bmp = null;
			canvas = null;
		}

		initScreen(width, height);
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

			var bm = nes.buffer;
			for (i in loopStart ... loopEnd) // 256 x 240
			{
				Memory.setI32((i-loopStart)*4, Palette.getColor(bm.get(i)));
			}

			pixels.position = 0;

			bmpData.lock();
			canvas.lock();
			bmpData.setPixels(r, pixels);
			canvas.draw(bmpData, m, null, null, clipRect, smooth);
			canvas.unlock();
			bmpData.unlock();
		}
	}

	override public function activate()
	{
		Memory.select(pixels);
	}

	override public function deactivate()
	{
		nes.apu.buffer.clear();
		nes.saveSram();
	}

	function initScreen(width:Int, height:Int)
	{
		canvas = new BitmapData(width, height, false, 0);
		bmp = new Bitmap(canvas);
		addChildAt(bmp, 0);

		var w = (256-clipLeft-clipRight);
		var h = (240-clipTop-clipBottom);
		var sx = canvas.width / w, sy = canvas.height / h;
		m.setTo(sx, 0, 0, sy, -clipLeft*sx, 0);

		clipRect.width = canvas.width;
		clipRect.height = canvas.height;

		initialized = true;
	}

	override public function capture()
	{
		var capture = new BitmapData(bmpData.width, bmpData.height - clipTop - clipBottom);
		capture.copyPixels(bmpData, capture.rect, new flash.geom.Point());
		return capture;
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
