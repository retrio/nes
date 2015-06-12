package strafe.emu.nes;

import haxe.ds.Vector;


class Palette
{
	static inline var att = 0.7;

	static var _colorCache:Vector<Int> = new Vector(0x200);
	public static inline function getColor(c:Int)
	{
		return _colorCache[c];
	}

	static var _colors = getColors();
	static function getColors() {
		//just or's all the colors with opaque alpha and does the color emphasis calcs
		//This set of colors matches current version of ntsc filter output
		var colorarray = [
			0x606060, 0x09268e, 0x1a11bd, 0x3409b6, 0x5e0982, 0x790939, 0x6f0c09, 0x511f09,
			0x293709, 0x0d4809, 0x094e09, 0x094b17, 0x093a5a, 0x000000, 0x000000, 0x000000,
			0xb1b1b1, 0x1658f7, 0x4433ff, 0x7d20ff, 0xb515d8, 0xcb1d73, 0xc62922, 0x954f09,
			0x5f7209, 0x28ac09, 0x099c09, 0x099032, 0x0976a2, 0x090909, 0x000000, 0x000000,
			0xffffff, 0x5dadff, 0x9d84ff, 0xd76aff, 0xff5dff, 0xff63c6, 0xff8150, 0xffa50d,
			0xccc409, 0x74f009, 0x54fc1c, 0x33f881, 0x3fd4ff, 0x494949, 0x000000, 0x000000,
			0xffffff, 0xc8eaff, 0xe1d8ff, 0xffccff, 0xffc6ff, 0xffcbfb, 0xffd7c2, 0xffe999,
			0xf0f986, 0xd6ff90, 0xbdffaf, 0xb3ffd7, 0xb3ffff, 0xbcbcbc, 0x000000, 0x000000,
		];

		var colors:Vector<Vector<Int>> = new Vector(8);
		for (i in 0 ... colors.length)
			colors[i] = new Vector(colorarray.length);

		for (j in 0 ... colorarray.length)
		{
			var col = colorarray[j];
			var r = r(col);
			var b = b(col);
			var g = g(col);
			colors[0][j] = compose(r, g, b);
			//emphasize red
			colors[1][j] = compose(r, g * att, b * att);
			//emphasize green
			colors[2][j] = compose(r * att, g, b * att);
			//emphasize yellow
			colors[3][j] = compose(r, g, b * att);
			//emphasize blue
			colors[4][j] = compose(r * att, g * att, b);
			//emphasize purple
			colors[5][j] = compose(r, g * att, b);
			//emphasize cyan
			colors[6][j] = compose(r * att, g, b);
			//de-emph all 3 colors
			colors[7][j] = compose(r * att, g * att, b * att);
		}

		for (i in 0 ... 8)
			for (j in 0 ... colorarray.length)
				_colorCache[((i&7) << 6) | j] = colors[i][j];

		return colors;
	}

	static inline function r(col:Int):Int
	{
		return (col >> 16) & 0xff;
	}

	static inline function g(col:Int):Int
	{
		return (col >> 8) & 0xff;
	}

	static inline function b(col:Int):Int
	{
		return col & 0xff;
	}

	static inline function compose(r:Float, g:Float, b:Float)
	{
#if flash
		// store colors as little-endian for flash.Memory
		return (0xff) | ((Std.int(r) & 0xff) << 8) | ((Std.int(g) & 0xff) << 16) | ((Std.int(b) & 0xff) << 24);
#else
		// store colors as big-endian for flash.Memory
		return (0xff000000) | ((Std.int(r) & 0xff) << 16) | ((Std.int(g) & 0xff) << 8) | ((Std.int(b) & 0xff) << 0);
#end
	}
}
