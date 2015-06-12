import haxe.xml.Fast;
import sys.io.File;
import sys.FileSystem;
import strafe.FileWrapper;
import strafe.emu.nes.NES;
import strafe.emu.nes.Palette;


class Test
{
	static inline var framesPerCycle = 60;
	static inline var maxCyclesWithoutChange = 20;

	static function main()
	{
		var testData = File.getContent("tests.xml");
		var fast = new Fast(Xml.parse(testData).firstElement());
		var romDir = fast.has.dir ? fast.att.dir : "assets/roms/test/";

		if (!FileSystem.exists("test_results"))
			FileSystem.createDirectory("test_results");
		else
		{
			for (file in FileSystem.readDirectory("test_results"))
				if (StringTools.endsWith(file, ".nes.png"))
					FileSystem.deleteFile("test_results/" + file);
		}

		var hashes:Map<String, String> = new Map();
		var prevResults:Map<String, String> = new Map();
		if (FileSystem.exists("test_results/.last"))
		{
			var resultsFile = File.read("test_results/.last");
			var line:String;
			try
			{
				while ((line = resultsFile.readLine()) != null)
				{
					var parts = line.split(":");
					if (parts.length == 3)
					{
						var name = parts[0];
						var hash = parts[1];
						prevResults[name] = hash;
					}
				}
			}
			catch (e:haxe.io.Eof) {}
			resultsFile.close();
		}

		var resultsFile = File.write("test_results/.last");

		var successes = 0;
		var failures:Array<String> = [];
		var i:Int = 0;

		for (test in fast.nodes.test)
		{
			++i;
			var rom = test.att.rom;
			var hash = test.has.hash ? test.att.hash : null;

			var nes = new NES();
			var f = FileWrapper.read(romDir + (StringTools.endsWith(romDir, "/") ? "" : "/") + rom);
			nes.loadGame(f);

			Sys.println("\n>> Running test " + rom + (hash == null ? " (NO HASH)" : "") + "...");
			var cycles = 0;
			var success = false;
			var currentHash = "";
			var lastHash = "";

			var withoutChange = Math.max(maxCyclesWithoutChange,
				test.has.frames ? (Std.parseInt(test.att.frames)/framesPerCycle) : 0);

			while (cycles < maxCyclesWithoutChange)
			{
				for (i in 0 ... framesPerCycle)
				{
					try
					{
						nes.frame();
					}
					catch(e:Dynamic)
					{
						Sys.println("ERROR: " + e);
						break;
					}
				}


				currentHash = haxe.crypto.Sha1.encode(nes.ppu.bitmap.toString());
				if (hash != null && currentHash == hash)
				{
					success = true;
					break;
				}
				else if (currentHash != lastHash)
				{
					lastHash = currentHash;
					cycles = 0;
				}
				++cycles;
			}

			hashes[rom] = currentHash;
			if (prevResults.exists(rom) && prevResults[rom] != currentHash)
			{
				Sys.println("=> changed from last run: " + prevResults[rom]);
			}
			resultsFile.writeString(rom + ":" + currentHash + "\n" + ":" + (success ? "PASS" : "FAIL"));

			if (success)
			{
				Sys.println("passed!");
				++successes;
			}
			else
			{
				Sys.println("FAILED!");
				Sys.println(currentHash);

				var resultImg = "test_results/" + StringTools.lpad(Std.string(i), "0", 3) + "-" + rom + ".png";

				var bm = nes.ppu.bitmap;
				var bo = new haxe.io.BytesOutput();
				for (i in 0 ... 256 * 240)
				{
					var c = Palette.getColor(bm.get(i));
					bo.writeByte((c & 0xFF0000) >> 16);
					bo.writeByte((c & 0xFF00) >> 8);
					bo.writeByte((c & 0xFF));
				}
				var bytes = bo.getBytes();
				var handle = sys.io.File.write(resultImg);
				new format.png.Writer(handle).write(format.png.Tools.buildRGB(256, 240, bytes));
				handle.close();

				Sys.println(resultImg);

				failures.push(rom);
			}
		}

		resultsFile.close();

		Sys.println("\n\n*** FINISHED ***\n");
		Sys.println("Succeeded:  " + successes);
		Sys.println("Failed:     " + failures.length);
		Sys.println(failures.join(' '));
	}
}
