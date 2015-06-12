package strafe.emu.nes;

import haxe.ds.Vector;


class Util
{
	static var _reversedBytes:Vector<Int> = getReversedBytes();

	static inline function getReversedBytes()
	{
		var _reversedBytes = new Vector(0x100);
		for (b in 0 ... 0x100)
		{
			_reversedBytes.set(b,
				((b & 1) << 7) |
				(((b >> 1) & 1) << 6) |
				(((b >> 2) & 1) << 5) |
				(((b >> 3) & 1) << 4) |
				(((b >> 4) & 1) << 3) |
				(((b >> 5) & 1) << 2) |
				(((b >> 6) & 1) << 1) |
				(((b >> 7) & 1))
			);
		}
		return _reversedBytes;
	}

	public static inline function getbit(val:Int, pos:Int):Bool
	{
		return (val & (1 << pos)) != 0;
	}

	public static inline function getbitI(val:Int, pos:Int):Int
	{
		return (val >> pos) & 1;
	}

	public static inline function setbit(val:Int, pos:Int, state:Bool)
	{
		return state ? (val | (1 << pos)) : (val & ~(1 << pos));
	}

	public static inline function reverseByte(b:Int):Int
	{
		return _reversedBytes.get(b & 0xFF);
	}
}
