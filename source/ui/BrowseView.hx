package ui;

import data.SongData;
import haxe.ui.events.MouseEvent;
import openfl.events.Event;
import openfl.net.FileFilter;
import openfl.net.FileReference;
import ui.PlayView;

@:xml('<?xml version="1.0" encoding="utf-8" ?>
<vbox width="100%" height="100%">
	<menubar width="100%">
		<menu text="File">
			<menuitem id="loadBtn" text="Open File" shortcutText="Ctrl+O" />
		</menu>
		<box width="100%"/>
		<button id="backBtn" text="Back" hidden="true"/>
	</menubar>
	<box id="infoBox" height="100%" horizontalAlign="center">
		<hbox verticalAlign="center">
			<label  id="infoText" text="No song loaded, select File > Open File and select a song.ini" verticalAlign="center" />
		</hbox>
	</box>
</vbox>
')
class BrowseView extends haxe.ui.containers.VBox
{
	public var songView:PlayView = null;
	
	public function new (?song:SongData)
	{
		super();
		
		onSongChoose(song);
	}
    
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
		// infoText.text = file.name;
		@:privateAccess final path = file.__path;
		SongData.loadPath(path, (result)->switch result
		{
			case SUCCESS(song):
				onSongChoose(song);
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
	
	public function onSongChoose(song:SongData)
	{
		if (songView != null)
		{
			removeComponent(songView);
			songView.disposeComponent();
		}
		infoBox.hide();
		addComponent(songView = new PlayView(data));
		songView.backBtn.hide();
	}
}