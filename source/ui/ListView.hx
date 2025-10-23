package ui;

import data.SongData;
import data.SongTree;
import flixel.FlxG;
import flixel.util.FlxTimer;
import haxe.Exception;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.Label;
import haxe.ui.containers.TreeView;
import haxe.ui.containers.TreeViewNode;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.TreeViewEvent;
import haxe.ui.events.UIEvent;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.filesystem.File;
import ui.FilterDropdown;

@:build(haxe.ui.ComponentBuilder.build('assets/data/list-view.xml'))
class ListView extends VBox
{
	static var library:Array<SongData> = null;
	static var favorites:Array<String> = [];
	
	var tree:Array<SongTree> = null;
	public var selectedSong(default, null):SongData = null;
	
	public function new(?selectedSong:SongData)
	{
		this.selectedSong = selectedSong;
		super();
		
		DropDownBuilder.HANDLER_MAP.set("filterDropDown", Type.getClassName(FilterDropDown));
		
		registerEvent(UIEvent.SHOWN, function onShown(e)
		{
			checkSavedDirectory();
			
			filtersDropDown.onClick = function (e)
			{
				filtersDropDown.onClick = null;
				FilterDropDown.view.favBox.onChange = onSortChange;
				FilterDropDown.view.wavegroupBox.onChange = onSortChange;
				FilterDropDown.view.monoBox.onChange = onSortChange;
			}
			sortBy.onChange = onSortChange;
		});
	}
	
	function checkSavedDirectory()
	{
		#if save.erase
		FlxG.save.erase();
		return;
		#end
		
		final saveData:SaveData = FlxG.save.data;
		if (saveData.favs != null)
			favorites = saveData.favs;
		
		final savedPath = saveData.path;
		if (savedPath != null)
		{
			if (saveData.songs != null)
			{
				onLibraryLoad(saveData.songs.map((s)->SongData.fromSave(s)));
				return;
			}
			
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
				FlxTimer.wait(0.001, ()->loadLibrary(file, onLibraryLoad));
			}
		}
		else
		{
			#if save.defaultPath
			final directory = '${haxe.macro.Compiler.getDefine("save.defaultPath")}';
			final file = new File(haxe.io.Path.normalize(directory));
			if (file.exists)
				loadLibrary(file, onLibraryLoad);
			#end
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
				
				loadLibrary(directory, onLibraryLoad);
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
	
	function loadLibrary(directory:File, onComplete:(Array<SongData>)->Void)
	{
		if (library != null)
		{
			onComplete(library);
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
					saveLibrary(directory, songs);
				}
				
				onComplete(songs);
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
	
	function onLibraryLoad(songs:Array<SongData>)
	{
		loadInfoText.text = '';
		loadInfoText.hide();
		
		library = songs;
		for (song in library)
		{
			if (favorites.contains(song.saveKey))
				song.isFavorite = true;
		}
		
		sortLibrary();
	}
	
	function onSortChange(e)
	{
		if (library != null)
			filterNodes();
	}
	
	function sortLibrary()
	{
		songList.clearNodes();
		final sorter:SortName = sortBy.selectedItem.text;
		tree = sorter.createTree(library);
		final selectedPath = selectedSong == null ? null : SortUtils.findSongPath(tree, selectedSong, sorter);
		
		// trace(tree.length, songList.getNodes().length, haxe.CallStack.callStack());
		createNodes(tree, songList.addNode, selectedPath);
		filterNodes();
	}
	
	function createNodes(members:Array<SongTree>, addFunc:(Any)->TreeViewNode, ?selectedPath:Array<String>)
	{
		final selected = selectedPath == null ? null : selectedPath.shift();
		for (member in members)
		{
			switch member
			{
				case Branch(name, subMembers):
					final node = addFunc({ label: name, count: subMembers.length, members:subMembers });
					node.expandable = true;
					if (selected != null && selected == name)
					{
						// expand now and create sub-nodes
						node.expanded = true;
						createNodes(subMembers, node.addNode, selectedPath);
					}
					else
					{
						// create sub-nodes when expanded
						songList.registerEvent(TreeViewEvent.NODE_EXPANDED, function onExpand(e)
						{
							if (node == e.node)
							{
								node.unregisterEvent(TreeViewEvent.NODE_EXPANDED, onExpand);
								createNodes(subMembers, node.addNode);
								filterSubNodes(node.getNodes(), FilterDropDown.filterFunc);
							}
						});
					}
				case Leaf(song, _):
					final fav = favorites.contains(song.saveKey);
					final node = addFunc({ artist: song.data.artist, title:song.data.name, favorite:fav, song:song });
					final favBox = node.findComponent("favorite", CheckBox);
					if (favBox == null)
						throw "could not find favorite";
					else
						favBox.registerEvent(UIEvent.CHANGE, function (e)
						{
							song.isFavorite = favBox.selected;
							if (favBox.selected && false == favorites.contains(song.saveKey))
								favorites.push(song.saveKey);
							else if (false == favBox.selected)
								favorites.remove(song.saveKey);
						});
					
					if (song == selectedSong)
					{
						if (songList.isReady)
							songList.selectedNode = node;
						else
							songList.registerEvent(UIEvent.READY, (_)->songList.selectedNode = node);
					}
			}
		}
	}
	
	function filterNodes()
	{
		#if debug
		FilterDropDown.logFiltered(library);
		#end
		filterSubNodes(songList.getNodes(), FilterDropDown.filterFunc);
	}
	
	function filterSubNodes(nodes:Array<TreeViewNode>, filter:(SongData)->Bool):Int
	{
		var count = 0;
		for (node in nodes)
		{
			if (node.expandable)
			{
				final nodeData:{ label:String, count:Int, members:Array<SongTree> } = node.data;
				final subCount = if (node.expanded)
					filterSubNodes(node.getNodes(), filter);
				else
					Lambda.fold(nodeData.members, (member, count)->count + member.countFiltered(filter), 0);
				
				// trace('${nodeData.label} - count: $subCount');
				nodeData.count = subCount;
				node.hidden = subCount == 0;
				count += subCount;
			}
			else
			{
				final nodeData:{ artist: String, title:String, favorite:Bool, song:SongData } = node.data;
				final showNode = filter(nodeData.song);
				if (showNode)
					count++;
				// else
				// 	trace('hiding node ${nodeData.artist} - ${nodeData.title}');
				node.hidden = false == showNode;
			}
		}
		return count;
	}
	
	function saveLibrary(directory:File, songs:Array<SongData>)
	{
		final data:SaveData = FlxG.save.data;
		data.path = directory.nativePath;
		data.songs = songs.map((s)->s.toSave());
		data.favs = favorites;
		FlxG.save.flush();
	}
	
	@:bind(songList, UIEvent.CHANGE)
	function onSelectNode(_)
	{
		// trace("change");
		final node = songList.selectedNode;
		if (node == null || node.expandable)
		{
			selectedSong = null;
			artistText.text = '-';
			albumText.text = '-';
			yearText.text = '-';
			genreText.text = '-';
			timeText.text = '-';
			confirmTrackBtn.disabled = true;
			albumArt.hidden = true;
			if (node != null)
				node.expanded = true;
		}
		else
		{
			final song = Lambda.find(library, function (s)
			{
				return node.findComponent("artist", Label).text == s.data.artist
					&& node.findComponent("title", Label).text == s.data.name;
			});
			
			if (song == null)
				throw "Error selecting song";
			
			song.loadTracks(function (results)
			{
				// TODO: play preview
			});
			selectedSong = song;
			artistText.text = song.data.artist;
			albumText.text = song.data.album;
			yearText.text = '${song.data.year}';
			genreText.text = song.data.genre;
			timeText.text = getTime(song.data.songLength);
			confirmTrackBtn.disabled = false;
			
			if (song.album != null)
			{
				final album = song.loadAlbumArt();
				album.onComplete(function (bitmapData)
				{
					if (selectedSong == song)
					{
						albumArt.hidden = false;
						// albumArt.removeChildren();
						// albumArt.addChild(new openfl.display.Bitmap(bitmapData));
						albumArt.resource = bitmapData;
						trace('displaying album art');
					}
				});
			}
			else
			{
				albumArt.hidden = true;
			}
		}
	}
	
	function getTime(ms:Int)
	{
		final totalSeconds:Int = Math.round(ms / 1000);
		final minutes = Std.int(totalSeconds / 60);
		final seconds = totalSeconds % 60;
		return '$minutes:${seconds < 10 ? '0':''}$seconds';
	}
}

typedef SaveData =
{
	var path:Null<String>;
	var songs:Null<Array<SongDataSave>>;
	var favs:Null<Array<String>>;
};
