package states;

import data.SongData;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Exception;
import haxe.io.Path;
import haxe.ui.containers.TreeView;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.filesystem.File;
import ui.SongList;

class ListState extends flixel.FlxState
{
	override public function create():Void
	{
		// FlxG.cameras.bgColor = FlxColor.WHITE;
		
		add(new ListView());
	}
}

@:build(haxe.ui.ComponentBuilder.build('assets/data/list-view.xml'))
class ListView extends VBox
{
	static var library:Array<SongData> = null;
	
	public function new()
	{
		super();
		
		registerEvent(UIEvent.SHOWN, function onShown(e)
		{
			checkSavedDirectory();
			trace((loadInfoText.style.color:FlxColor).toHexString());
		});
	}
	
	function checkSavedDirectory()
	{
		final savedPath = (cast FlxG.save.data: SaveData).path;
		if (savedPath != null)
		{
			final file = new File(savedPath);
			loadInfoText.style.color = 0xAAAAAA;
			loadInfoText.text = 'Loading $savedPath';
			if (false == file.exists)
			{
				loadInfoText.style.color = 0xFF0000;
				loadInfoText.text = '$savedPath does not exist: ';
			}
			else if (false == file.isDirectory)
			{
				loadInfoText.style.color = 0xFF0000;
				loadInfoText.text = '$savedPath is not a folder';
			}
			else
			{
				// let one frame draw before loading
				FlxTimer.wait(0.001, ()->selectDirectory(file));
			}
		}
		else
		{
			// loadInfoText.text = "No directory selected";
			// loadInfoText.color = 0xFF808080;
		}
	}
	
	@:bind(loadBtn, MouseEvent.CLICK)
	function onClickChoose(e)
	{
		final directory:File = File.documentsDirectory;
		try
		{
			var onBrowseComplete:(Event)->Void = null;
			var onBrowseCancel:(Event)->Void = null;
			function removeListeners()
			{
				directory.removeEventListener(Event.COMPLETE, onBrowseComplete);
				directory.removeEventListener(Event.COMPLETE, onBrowseCancel);
			}
			
			onBrowseComplete = function (e:Event)
			{
				removeListeners();
				
				songList.clearNodes();
				library = null;
				
				saveDirectory(directory);
				selectDirectory(directory);
			}
			
			onBrowseCancel = function (e:Event)
			{
				removeListeners();
			}
			
			directory.addEventListener(Event.SELECT, onBrowseComplete);
			directory.addEventListener(Event.CANCEL, onBrowseCancel);
			directory.browseForDirectory("Select Directory");
		}
		catch (error)
		{
			trace("Failed:", error.message);
		}
	}
	
	function selectDirectory(directory:File)
	{
		if (library != null)
		{
			onLibraryLoad();
			return;
		}
		
		loadInfoText.show();
		loadInfoText.text = 'Loading songs from ${directory.nativePath}}';
		
		SongData.scanForSongs(directory, 
			function onLoad(songs)
			{
				library = songs;
				
				if (library.length == 0)
					loadInfoText.text = 'No songs found at ${directory.nativePath}';
				else
				{
					loadInfoText.text = '';
					loadInfoText.hide();
				}
				
				onLibraryLoad();
			},
			function onProgress(files, successCount, ioErrorCount, parseFailCount, time)
			{
				loadInfoText.text
					= '$files files(s) found'
					+ '\n$successCount song(s) loaded'
					+ '\n$parseFailCount invalid song(s)'
					+ '\n$ioErrorCount error(s) in ${time}s'
					;
			}
		);
	}
	
	function onLibraryLoad()
	{
		loadInfoText.hidden = false;
		for (song in library)
		{
			songList.addNode({ artist: song.data.artist, title:song.data.name, favorite:false });
		}
	}
	
	function saveDirectory(directory:File)
	{
		(cast FlxG.save.data:SaveData).path = directory.nativePath;
		FlxG.save.flush();
	}
	
}

typedef SaveData =
{
	var path:Null<String>;
};