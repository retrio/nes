package retrio.ui.openfl;

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
import retrio.emu.nes.NES;
import retrio.emu.nes.Palette;


class NESPlugin extends EmulatorPlugin
{
	var loopStart:Int = 0;
	var loopEnd:Int = 0;
	var clipTop(default, set):Int = 0;
	var clipBottom(default, set):Int = 0;
	function set_clipTop(y:Int)
	{
		clipTop = y;
		setClip();
		return y;
	}
	function set_clipBottom(y:Int)
	{
		clipBottom = y;
		setClip();
		return y;
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
		this.emu = this.nes = new NES();
		extensions = nes.extensions;

		_stage.quality = flash.display.StageQuality.LOW;
		bmpData = new BitmapData(256, 240, false, 0);

		pixels.endian = Endian.BIG_ENDIAN;
		pixels.clear();
		for (i in 0 ... 256*240*4)
			pixels.writeByte(0);

		Memory.select(pixels);

		clipTop = 8;
		clipBottom = 8;
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
			nes.frame();

			if (frameSkip > 0)
			{
				var skip = frameCount > 0;
				frameCount = (frameCount + 1) % (frameSkip + 1);
				if (skip) return;
			}

			var bm = nes.buffer;
			//for (i in 0 ... loopStart) Memory.setI32(i*4, 0);
			for (i in loopStart ... loopEnd) // 256 x 240
			{
				Memory.setI32((i-loopStart)*4, Palette.getColor(bm.get(i)));
			}
			//for (i in loopEnd ... 256*240) Memory.setI32(i*4, 0);
		}

		pixels.position = 0;
		bmpData.setPixels(r, pixels);
		canvas.draw(bmpData, m);
	}

	function initScreen(width:Int, height:Int)
	{
		canvas = new BitmapData(width, height, false, 0);
		bmp = new Bitmap(canvas);
		addChild(bmp);

		var sx = canvas.width / 256, sy = canvas.height / (240-clipTop-clipBottom);
		m.setTo(sx, 0, 0, sy, 0, 0);

		initialized = true;
	}

	override public function capture()
	{
		var capture = new BitmapData(bmpData.width, bmpData.height - clipTop - clipBottom);
		capture.copyPixels(bmpData, capture.rect, new flash.geom.Point());
		return capture;
	}
}