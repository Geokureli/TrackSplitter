package states;

import data.SongData;
import flixel.FlxG;
import flixel.input.actions.FlxActionManager.ActionSetJson;
import flixel.text.FlxInputText;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxTimer;
import haxe.Exception;
import haxe.io.Path;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.filesystem.File;
import ui.SongList;

class ListState extends flixel.FlxState
{
	static var library:Array<SongData> = null;
	
	final pathText:FlxText;
	final statusText:FlxText;
	var list:Null<SongList>;
	
	public function new ()
	{
		super();
		bgColor = 0xFFffffff;
		
		final MARGIN = 10;
		final GAP = 10;
		
		final setPathButton = new FlxButton(MARGIN, MARGIN, "Choose Folder", onClickChoose);
		add(setPathButton);
		
		pathText = new FlxText(setPathButton.x + setPathButton.width + GAP, MARGIN, 0, "No directory selected");
		add(pathText);
		statusText = new FlxText(MARGIN, pathText.y + pathText.height + GAP, 0, "");
		statusText.color = 0xFF000000;
		add(statusText);
		
		checkSavedDirectory();
	}
	
	function checkSavedDirectory()
	{
		final savedPath = (cast FlxG.save.data: SaveData).path;
		if (savedPath != null)
		{
			final file = new File(savedPath);
			pathText.text = savedPath;
			if (false == file.exists)
			{
				pathText.color = 0xFFff0000;
				statusText.text = "Saved directory does not exist";
			}
			else if (false == file.isDirectory)
			{
				pathText.color = 0xFFff0000;
				statusText.text = "Saved directory is not a folder";
			}
			else
			{
				pathText.color = 0xFF000000;
				// let one frame draw before loading
				FlxTimer.wait(0.001, ()->selectDirectory(file));
			}
		}
		else
		{
			pathText.text = "No directory selected";
			pathText.color = 0xFF808080;
		}
	}
	
	function onClickChoose()
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
				
				statusText.text = "Directory found, loading song data...";
				
				if (list != null)
				{
					remove(list);
					list.destroy();
				}
				
				library = null;
				saveDirectory(directory);
				selectDirectory(directory);
			}
			
			onBrowseCancel = function (e:Event)
			{
				removeListeners();
				statusText.text = "File browser cancelled";
			}
			
			directory.addEventListener(Event.SELECT, onBrowseComplete);
			directory.addEventListener(Event.CANCEL, onBrowseCancel);
			directory.browseForDirectory("Select Directory");
			statusText.text = "File browser opened";
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
		
		pathText.color = 0xFF000000;
		pathText.text = directory.nativePath;
		
		SongData.scanForSongs(directory, 
			function onLoad(songs)
			{
				library = songs;
				onLibraryLoad();
			},
			function onProgress(files, successCount, ioErrorCount, parseFailCount, time)
			{
				statusText.text = '$files files(s) found, $successCount song(s) loaded, $parseFailCount invalid song(s), $ioErrorCount error(s) in ${time}s';
			}
		);
	}
	
	function onLibraryLoad()
	{
		list = new SongList(10, statusText.y + statusText.height, FlxG.width - 20, library, onSelectSong);
		add(list);
	}
	
	function saveDirectory(directory:File)
	{
		(cast FlxG.save.data:SaveData).path = directory.nativePath;
		FlxG.save.flush();
	}
	
	
	function onSelectSong(song:SongData)
	{
		FlxG.switchState(()->new PlayState(song, ListState.new));
	}
}

typedef SaveData =
{
	var path:Null<String>;
};
