package states;

import data.SongData;
import flixel.FlxG;
import flixel.util.FlxColor;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;
import openfl.events.Event;
import openfl.net.FileFilter;
import openfl.net.FileReference;

class BrowseState extends flixel.FlxState
{

	override public function create():Void
	{
		// FlxG.cameras.bgColor = FlxColor.WHITE;
		
		add(new BrowseView());
	}
}

@:xml('<?xml version="1.0" encoding="utf-8" ?>
<vbox width="100%" height="100%">
    <box height="100%" horizontalAlign="center">
        <hbox verticalAlign="center">
            <button id="loadBtn" text="Load Song" />
            <label  id="infoText" text="Select an .ini file to play a song" verticalAlign="center" />
        </hbox>
    </box>
</vbox>
')
class BrowseView extends VBox
{
	@:bind(loadBtn, MouseEvent.CLICK)
	function onLoadClick(e)
	{
		var fr:FileReference = new FileReference();
		fr.addEventListener(Event.SELECT, (_)->onSelect(fr), false, 0, true);
		fr.addEventListener(Event.CANCEL, (_)->infoText.text = "Cancelled!", false, 0, true);
		fr.browse([new FileFilter("Clone hero songs", "*.ini;*.sng;*.zip")]);
	}

	function onSelect(file:FileReference)
	{
		infoText.text = file.name;
		@:privateAccess final path = file.__path;
		SongData.loadPath(path, (result)->switch result
		{
			case SUCCESS(data):
				FlxG.switchState(()->new PlayState(data, BrowseState.new));
			case INI_FAIL(IO_ERROR(_, _)):
				infoText.text = 'Error loading $path';
			case INI_FAIL(PARSE_FAIL(name, exception)):
				infoText.text = 'Error parsing $name: "${exception.message}"';
			case INI_FAIL(SUCCESS(_)):
				infoText.text = "Unexpected loadSong result, please report this issue";
			case MISSING:
				infoText.text = 'Tried to load nonexistent song "$path"';
			case UNSUPPORTED(song):
				infoText.text = 'unsupported song file "$song"';
		});
	}
}