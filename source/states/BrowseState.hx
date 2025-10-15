package states;

import data.SongData;
import flash.events.Event;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxMath;
import flixel.system.FlxAssets;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import openfl.display.Loader;
import openfl.display.LoaderInfo;
import openfl.net.FileFilter;
import openfl.net.FileReference;

class BrowseState extends FlxState
{
	var text:FlxText;
	var browseButton:FlxButton;

	override public function create():Void
	{
		FlxG.cameras.bgColor = FlxColor.WHITE;
		
		final MARGIN = 10;
		final GAP = 15;
		
		browseButton = new FlxButton(MARGIN, MARGIN, "Open Song", onClick);
		add(browseButton);

		final x = browseButton.width + GAP;
		text = new FlxText(x, MARGIN, Std.int(FlxG.width - x - MARGIN), "Click the button to load a song!");
		text.setFormat(null, 16, FlxColor.BLACK, LEFT);
		add(text);
	}

	function onClick()
	{
		var fr:FileReference = new FileReference();
		fr.addEventListener(Event.SELECT, (_)->onSelect(fr), false, 0, true);
		fr.addEventListener(Event.CANCEL, (_)->text.text = "Cancelled!", false, 0, true);
		fr.browse([new FileFilter("Clone hero songs", "*.ini;*.sng;*.zip")]);
	}

	function onSelect(file:FileReference)
	{
		text.text = file.name;
		@:privateAccess final path = file.__path;
		SongData.loadPath(path, (result)->switch result
		{
			case SUCCESS(data):
				FlxG.switchState(()->new PlayState(data, BrowseState.new));
			case INI_FAIL(IO_ERROR(_, _)):
				text.text = 'Error loading $path';
			case INI_FAIL(PARSE_FAIL(name, exception)):
				text.text = 'Error parsing $name: "${exception.message}"';
			case INI_FAIL(SUCCESS(_)):
				text.text = "Unexpected loadSong result, please report this issue";
			case MISSING:
				text.text = 'Tried to load nonexistent song "$path"';
			case UNSUPPORTED(song):
				text.text = 'unsupported song file "$song"';
		});
	}
}