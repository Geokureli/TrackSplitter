package data;

import flixel.util.FlxTimer;
import haxe.Exception;
import haxe.Timer;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.filesystem.File;
import openfl.media.Sound;
import openfl.utils.Assets;
import openfl.utils.ByteArray;
import openfl.utils.Future;

typedef SongDataSave =
{
	final path:String;
	final data:SongIniSave;
	final tracks:Array<String>;
	final album:Null<String>;
}

class SongData
{
	public final file:File;
	public final data:SongIniData;
	public final tracks:Array<String>;
	public final album:Null<String>;
	public final saveKey:String;
	public final isWaveGroup:Bool;
	public final isMono:Bool;
	public final isEmpty:Bool;
	public var isFavorite:Bool;
	var trackLoadState = TrackLoadState.UNSTARTED;
	var albumArt:Future<BitmapData> = null;
		
	public function new (file, data, tracks, album, favorite = false)
	{
		this.file = file;
		this.data = data;
		this.tracks = tracks;
		this.album = album;
		saveKey = '${data.artist}-${data.album}-${data.name}-${data.charter}';
		isWaveGroup = data.artist.toLowerCase().indexOf("wavegroup") != -1;
		isFavorite = favorite;
		isMono = tracks.length == 1;
		isEmpty = tracks.length == 0;
	}
	
	public function toSave():SongDataSave
	{
		return
			{ path  : file.nativePath
			, data  : data.toSave()
			, tracks: tracks
			, album : album
			}
	}
	
	public function loadAlbumArt()
	{
		final key = '${data.artist}-${data.album}';
		if (album == null)
		{
			trace('Missing albumArt $key');
			return null;
		}
		
		if (albumArt == null)
		{
			if (Assets.cache.hasBitmapData(key))
			{
				albumArt = Future.withValue(Assets.cache.getBitmapData(key));
				return albumArt;
			}
			
			final path = '${file.nativePath}/${album}';
			trace('loading album art $key: $path');
			albumArt = BitmapData.loadFromFile(path);
			albumArt.onComplete(function (bmd)
			{
				trace('loaded album art $key');
				Assets.cache.setBitmapData(key, bmd);
			});
		}
		
		return albumArt;
	}
	
	public function loadTracks(onComplete:(Map<String, LoadResult<Sound>>)->Void, ?onProgress:(loaded:Int, current:String)->Void)
	{
		switch trackLoadState
		{
			case LOADED(results):
				onComplete(results);
				return;
			case LOADING(completeCallback, progressCallback):
				completeCallback.push(function(results)
				{
					onComplete(results);
				});
				
				if (onProgress != null)
				{
					progressCallback.push(function(numLoaded, current)
					{
						onProgress(numLoaded, current);
					});
				}
				return;
			case UNSTARTED:
				// keep going
		}
		
		final completeCallbacks = [onComplete];
		final progressCallbacks = onProgress != null ? [onProgress] : [];
		trackLoadState = LOADING(completeCallbacks, progressCallbacks);
		
		onComplete = function (results)
		{
			trackLoadState = LOADED(results);
			for (callback in completeCallbacks)
				callback(results);
		}
		
		onProgress = function (numLoaded, current)
		{
			for (callback in progressCallbacks)
				callback(numLoaded, current);
		}
		
		final sounds = new Map<String, LoadResult<Sound>>();
		var index = 0;
		var loadNext:()->Void = null;
		function add(track, result)
		{
			sounds[track] = result;
			trace('$track loaded ${result.match(SUCCESS(_)) ? "" : "un"}successfully ${index + 1}/${tracks.length}');
			if (++index == tracks.length)
				onComplete(sounds);
			else
				haxe.Timer.delay(()->loadNext(), 1);
		}
		
		loadNext = function ()
		{
			final track = tracks[index];
			final path = new File(Path.normalize(file.nativePath + "/" + track));
			
			trace('Loading $track: ${path.nativePath}');
			if (onProgress != null)
				onProgress(index, track);
			
			if (Assets.cache.hasSound(path.nativePath))
			{
				add(track, SUCCESS(Assets.cache.getSound(path.nativePath)));
				return;
			}
			
			if (false == path.exists)
			{
				add(track, LOAD_ERROR('No file ${path.nativePath} exists'));
				return;
			}
			
			switch path.extension
			{
				case "ogg":
					final future = Sound.loadFromFile(path.nativePath);
					future.onComplete(function (sound)
					{
						Assets.cache.setSound(path.nativePath, sound);
						add(track, SUCCESS(sound));
					});
					future.onError((error)->add(track, LOAD_ERROR(error)));
				case "opus":
					loadFile(path, (result)->switch result
					{
						case SUCCESS(data):
							var result:LoadResult<Sound> = null;
							try
							{
								result = SUCCESS(hxopus.Opus.toOpenFL(data));
							}
							catch(e)
							{
								result = PARSE_FAIL(e);
							}
							add(track, result);
						case PARSE_FAIL(exception):
							throw 'Unexpected parse failure exception: "$exception"';
						case LOAD_ERROR(error):
							add(track, LOAD_ERROR(error));
					});
				default:
			}
		}
		loadNext();
	}
	
	static public function loadFile(file:File, callback:(LoadResult<ByteArray>)->Void)
	{
		var onLoad:(Event)->Void = null;
		var onError:(IOErrorEvent)->Void = null;
		function removeListeners()
		{
			file.removeEventListener(Event.COMPLETE, onLoad);
			file.removeEventListener(IOErrorEvent.IO_ERROR, onError);
		}
		
		onLoad = function (e:Event)
		{
			removeListeners();
			callback(SUCCESS(file.data));
		}
		
		onError = function (e:IOErrorEvent)
		{
			removeListeners();
			callback(LOAD_ERROR(e));
		}
		
		file.addEventListener(Event.COMPLETE, onLoad);
		file.addEventListener(IOErrorEvent.IO_ERROR, onError);
		file.load();
	}
	
	static public function fromSave(data:SongDataSave)
	{
		return new SongData(new File(data.path), SongIniData.fromSave(data.data), data.tracks, data.album);
	}
	
	static public function fromFile(songFile:SongFile, data:SongIniData)
	{
		final file = switch songFile
		{
			case FOLDER(folder, _): folder;
			case SNG(file): file;
			case ZIP(file): file;
		}
		
		final data = data;
		final tracks = switch songFile
		{
			case FOLDER(folder, _): getTracksInFolder(folder.getDirectoryListing());
			case SNG(_): []; // TODO:
			case ZIP(_): []; // TODO:
		}
		final album = switch songFile
		{
			case FOLDER(folder, _): getAlbumInFolder(folder.getDirectoryListing());
			case SNG(_): null; // TODO:
			case ZIP(_): null; // TODO:
		}
		return new SongData(file, data, tracks, album);
	}
	
	static function getTracksInFolder(files:Array<File>)
	{
		final tracks = [];
		
		for (file in files)
		{
			if (file.name.substr(0, 2) == "._")
			{
				#if delete._files
				file.deleteFile();
				trace('deleting ${file.name}');
				#else
				trace('ignoring ${file.name}');
				#end
				continue;
			}
			
			switch (Path.extension(file.name))
			{
				case "ogg" | "opus":
					tracks.push(file.name);
			}
		}
		
		return tracks;
	}
	
	static function getAlbumInFolder(files:Array<File>)
	{
		for (file in files)
		{
			switch (Path.withoutDirectory(file.name))
			{
				case "album.jpg" | "album.png":
					return file.name;
			}
		}
		
		return null;
	}
	
	static public function scanForSongs(directory:File, onComplete:(songs:Array<SongData>)->Void, ?onProgress:(SongScanProgress)->Void)
	{
		final startTime = Timer.stamp();
		final songs = new Array<SongFile>();
		
		final progress:SongScanProgress =
		{
			numFiles: 0,
			successCount: 0,
			ioErrorCount: 0,
			parseFailCount: 0,
			time: 0,
			status: "Scanning for songs..."
		}
		
		addSongs(directory, songs, function progressCallback (folders)
		{
			progress.numFiles = folders;
			if (onProgress != null)
			{
				progress.time = Timer.stamp() - startTime;
				onProgress(progress);
			}
		});
		trace('Found ${songs.length} file(s) in ${Timer.stamp() - startTime}s');
		
		final successList:Array<SongData> = [];
		final ioErrorList:Array<IOErrorEvent> = [];
		final parseFailList:Array<Exception> = [];
		
		var frameStartTime = Timer.stamp();
		var index = 0;
		function doNextSet()
		{
			final maxIndex = index + 50;
			function doNext()
			{
				final song = songs[index];
				
				if (onProgress != null)
				{
					progress.successCount = successList.length;
					progress.ioErrorCount = ioErrorList.length;
					progress.parseFailCount = parseFailList.length;
					progress.time = Timer.stamp() - startTime;
					progress.status = 'Parsing ${song.getFile().nativePath}';
					onProgress(progress);
				}
				
				loadSong(song, function (result)
				{
					switch result
					{
						case SUCCESS(data):
							successList.push(data);
						case INI_FAIL(IO_ERROR(_, error)):
							ioErrorList.push(error);
							trace('ioError - $song: $error');
						case INI_FAIL(PARSE_FAIL(name, exception)):
							parseFailList.push(exception);
							trace('$name: ${exception.message}');
						case INI_FAIL(SUCCESS(_)):
							throw "Unexpected loadSong result, please report this issue";
						case MISSING:
							throw 'Tried to load nonexistent song';
						case UNSUPPORTED(SNG(file)):
							trace('Unsupported song file "${file.nativePath}"');
						case UNSUPPORTED(ZIP(file)):
							trace('Unsupported song file "${file.nativePath}"');
						case UNSUPPORTED(FOLDER(file, _)):
							throw 'Unexpected loadSong result on ${file.nativePath}, please report this issue';
					}
					
					++index;
					if (index == songs.length)
						onComplete(successList);
					else
					{
						if (index >= maxIndex || (haxe.Timer.stamp() - frameStartTime) > 2 / 60)
						{
							frameStartTime = haxe.Timer.stamp();
							FlxTimer.wait(0, doNextSet);
						}
						else
							doNext();
					}
				});
			}
			doNext();
		}
		doNextSet();
	}
	
	static public function addSongs(directory:File, list:Array<SongFile>, onProgress:(Int)->Void)
	{
		final files = directory.getDirectoryListing();
		for (file in files)
		{
			final song = getSongFile(file);
			if (song != null)
				onProgress(list.push(song));
			else if (file.isDirectory)
				addSongs(file, list, onProgress);
		}
		
		return list;
	}
	
	static public function loadSongPath(path:String, onComplete:(LoadSongResult)->Void)
	{
		loadSongFile(new File(path), onComplete);
	}
	
	static public function loadSongFile(file:File, onComplete:(LoadSongResult)->Void)
	{
		loadSong(getSongFile(file), onComplete);
	}
	
	static function loadSong(song:SongFile, onComplete:(LoadSongResult)->Void)
	{
		switch song
		{
			case null:
				onComplete(MISSING);
			case FOLDER(folder, ini):
				SongIniData.load(folder.name, ini, function (result)
				{
					switch result
					{
						case SUCCESS(data):
							onComplete(SUCCESS(SongData.fromFile(song, data)));
						case fail:
							onComplete(INI_FAIL(fail));
					}
				});
			// case SNG(file): // TODO:
			// case ZIP(file): // TODO:
			case unsupported:
				onComplete(UNSUPPORTED(unsupported));
		}
	}
	
	static function getSongFileFromPath(path:String)
	{
		return getSongFile(new File(path));
	}
	
	static function getSongFile(file:File):Null<SongFile>
	{
		if (file.isDirectory)
		{
			final iniPath = Path.normalize(file.nativePath) + "/song.ini";
			final ini = new File(iniPath);
			if (ini.exists)
				return FOLDER(file, ini);
			else
				return null;
		}
		
		return switch Path.extension(file.name)
		{
			case "sng": return SNG(file);
			case "zip": return ZIP(file);
			case "ini": return FOLDER(file.parent, file);
			default: null;
		}
	}
}

enum LoadSongResult
{
	SUCCESS(data:SongData);
	INI_FAIL(result:LoadIniResult);
	MISSING;
	UNSUPPORTED(song:SongFile);
}

typedef SongScanProgress =
{
	numFiles:Int,
	successCount:Int,
	ioErrorCount:Int,
	parseFailCount:Int,
	time:Float,
	status:String
}

@:using(data.SongData.SongFileTools)
enum SongFile
{
	FOLDER(folder:File, ini:File);
	SNG(file:File);
	ZIP(file:File);
}

class SongFileTools
{
	static public function getFile(song:SongFile)
	{
		return switch song
		{
			case FOLDER(folder, _): folder;
			case SNG(file): file;
			case ZIP(file): file;
		}
	}
}

@:structInit
class SongIniData
{
	public final name            :UnicodeString; // name
	public final artist          :UnicodeString; // artist
	public final album           :UnicodeString; // album
	public final genre           :UnicodeString; // genre
	public final year            :String       ; // year
	public final icon            :String       ; // icon
	public final charter         :UnicodeString; // charter
	public final proDrums        :Bool         ; // "pro_drums"
	public final loadingPhrase   :UnicodeString; // "loading_phrase"
	public final albumTrack      :Int          ; // "album_track"
	public final songLength      :Int          ; // "song_length"
	public final previewStart    :Int          ; // "preview_start_time"
	public final previewEnd      :Int          ; // "preview_end_time"
	
	public function toString()
	{
		return    'name               : "$name"          '
			+ '\n, artist             : "$artist"        '
			+ '\n, album              : "$album"         '
			+ '\n, genre              : "$genre"         '
			+ '\n, year               : $year            '
			+ '\n, icon               : "$icon"          '
			+ '\n, charter            : "$charter"       '
			+ '\n, pro_drums          : $proDrums        '
			+ '\n, loading_phrase     : "$loadingPhrase" '
			+ '\n, album_track        : $albumTrack      '
			+ '\n, song_length        : $songLength      '
			+ '\n, preview_start_time : $previewStart    '
			+ '\n, preview_end_time   : $previewEnd      '
			;
	}
	
	static public function fromFile(data:UnicodeString, backupName:String):SongIniData
	{
		final errors = #if debug [] #else null #end;
		final rawData = SongIniDataReader.parse(data, errors);
		
		return
			{ name         : (rawData.name              ?? "Unknown Name") #if debug + (errors.length > 0 ? '(${errors.length}!)': '') #end
			, artist       : rawData.artist             ?? "Unknown Artist"
			, album        : rawData.album              ?? "Unknown Album"
			, genre        : rawData.genre              ?? "Unknown Genre"
			, charter      : rawData.charter            ?? "Unknown Charter"
			, year         : rawData.year               ?? "####"
			, icon         : rawData.icon               
			, proDrums     : rawData.pro_drums          ?? false
			, loadingPhrase: rawData.loading_phrase     
			, albumTrack   : rawData.album_track        ?? 1
			, songLength   : rawData.song_length        ?? 0
			, previewStart : rawData.preview_start_time ?? 0
			, previewEnd   : rawData.preview_end_time   ?? -1
			};
	}
	
	public function toSave():SongIniSave
	{
		return 
			{ name         : name
			, artist       : artist
			, album        : album
			, genre        : genre
			, year         : year
			, icon         : icon
			, charter      : charter
			, proDrums     : proDrums
			, loadingPhrase: loadingPhrase
			, albumTrack   : albumTrack
			, songLength   : songLength
			, previewStart : previewStart
			, previewEnd   : previewEnd
			};
	}
	
	static public function fromSave(data:SongIniSave):SongIniData
	{
		return 
			{ name         : data.name
			, artist       : data.artist
			, album        : data.album
			, genre        : data.genre
			, year         : data.year
			, icon         : data.icon
			, charter      : data.charter
			, proDrums     : data.proDrums
			, loadingPhrase: data.loadingPhrase
			, albumTrack   : data.albumTrack
			, songLength   : data.songLength
			, previewStart : data.previewStart
			, previewEnd   : data.previewEnd
			};
	}
	
	static public function load(songName:UnicodeString, file:File, callback:(LoadIniResult)->Void)
	{
		var onSongIniLoad:(Event)->Void = null;
		var onSongIniError:(IOErrorEvent)->Void = null;
		function removeListeners()
		{
			file.removeEventListener(Event.COMPLETE, onSongIniLoad);
			file.removeEventListener(IOErrorEvent.IO_ERROR, onSongIniError);
		}
		
		onSongIniLoad = function (e:Event)
		{
			removeListeners();
			
			try
			{
				callback(SUCCESS(SongIniData.fromFile(file.data.toString(), songName)));
			}
			catch(e)
			{
				callback(PARSE_FAIL(songName, e));
			}
		}
		
		onSongIniError = function (e:IOErrorEvent)
		{
			removeListeners();
			callback(IO_ERROR(songName, e));
		}
		
		file.addEventListener(Event.COMPLETE, onSongIniLoad);
		file.addEventListener(IOErrorEvent.IO_ERROR, onSongIniError);
		file.load();
	}
}

typedef SongIniSave = 
	{ name         : String
	, artist       : String
	, album        : String
	, genre        : String
	, year         : String
	, icon         : String
	, charter      : String
	, proDrums     : Bool
	, loadingPhrase: String
	, albumTrack   : Int
	, songLength   : Int
	, previewStart : Int
	, previewEnd   : Int
	};

enum LoadResult<T>
{
	SUCCESS(data:T);
	PARSE_FAIL(e:Exception);
	LOAD_ERROR(error:Any);
}

enum LoadIniResult
{
	SUCCESS(data:SongIniData);
	PARSE_FAIL(name:String, e:Exception);
	IO_ERROR(name:String, error:IOErrorEvent);
}

enum TrackLoadState
{
	UNSTARTED;
	LOADING(onComplete:Array<(result:Map<String, LoadResult<Sound>>)->Void>, onProgress:Array<(numLoaded:Int, current:String)->Void>);
	LOADED(results:Map<String, LoadResult<Sound>>);
}