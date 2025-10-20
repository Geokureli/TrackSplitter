package states;

import data.SongData;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Exception;
import haxe.io.Path;
import haxe.ui.containers.TreeView;
import haxe.ui.containers.TreeViewNode;
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
				
				selectDirectory(directory);
				saveDirectory(directory);
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
				if (songs.length == 0)
					loadInfoText.text = 'No songs found at ${directory.nativePath}';
				else
				{
					library = songs;
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
		sortLibrary();
	}
	
	@:bind(sortBy, UIEvent.CHANGE)
	function onSortChange(e)
	{
		if (library != null)
		{
			songList.clearNodes();
			sortLibrary();
		}
	}
	
	function sortLibrary()
	{
		final sortOrders = (sortBy.selectedItem.text:String).toLowerCase().split("/");
		function getGroupNode(song:SongData)
		{
			var groupNode:TreeViewNode = null;
			for (i=>sorter in sortOrders)
			{
				final value = switch sorter
				{
					case "artist": song.data.artist;
					case "title" : song.data.name;
					case "album" : song.data.album;
					case "year"  : '${song.data.year}';
					case "genre" : song.data.genre;
					default: throw 'Unexpected sorter: sorter';
				}
				
				if (value == null || value == "")
					return null;
				
				if (groupNode != null)
				{
					groupNode = groupNode.findNode(value, 'label')
						?? groupNode.addNode({ label:value, count:0 });
				}
				else
				{
					groupNode = songList.findNode(value, 'label')
						?? songList.addNode({ label:value, count:0 });
				}
			}
			
			return groupNode;
		}
		
		for (song in library)
		{
			if (showNode(song) == false)
				continue;
			
			final groupNode = getGroupNode(song);
			if (groupNode == null)
				continue;
			
			final node = groupNode.addNode({ artist: song.data.artist, title:song.data.name, favorite:false });
		}
		
		// TODO: update group counts
	}
	
	function showNode(song:SongData)
	{
		if (filterFavs.selected)
			return false; // TODO: save and check favs 
		
		return true;
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