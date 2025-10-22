package data;

import flixel.util.FlxTimer;
import haxe.Exception;
import haxe.Timer;
import haxe.io.Path;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.filesystem.File;
import openfl.media.Sound;
import openfl.utils.ByteArray;

typedef SongDataSave =
{
	path:String,
	data:SongIniSave,
	tracks:Array<String>
}

class SongData
{
	public final file:File;
	public final data:SongIniData;
	public final tracks:Array<String>;
	
	public function new (file, data, tracks)
	{
		this.file = file;
		this.data = data;
		this.tracks = tracks;
	}
	
	public function toSave():SongDataSave
	{
		return
			{ path  : file.nativePath
			, data  : data.toSave()
			, tracks: tracks
			}
	}
	
	public function loadTracks(onComplete:(Map<String, Sound>)->Void)
	{
		final sounds = new Map<String, Sound>();
		var soundsLeft = tracks.length;
		function add(track, sound)
		{
			// trace('$track loaded. ${soundsLeft - 1} left');
			sounds[track] = sound;
			if (--soundsLeft == 0)
				onComplete(sounds);
		}
		
		for (track in tracks)
		{
			final path = new File(Path.normalize(file.nativePath + "/" + track));
			// trace('Loading track: $track');
			switch path.extension
			{
				case "ogg":
					final future = Sound.loadFromFile(track);
					future.onComplete(add.bind(track, _));
				case "opus":
					loadFile(path, (result)->switch result
					{
						case SUCCESS(data):
							add(track, hxopus.Opus.toOpenFL(data));
						case PARSE_FAIL(exception):
							throw exception;
						case IO_ERROR(error):
							throw error.toString();
					});
				default:
			}
			
		}
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
			
			try
			{
				callback(SUCCESS(file.data));
			}
			catch(e)
			{
				callback(PARSE_FAIL(e));
			}
		}
		
		onError = function (e:IOErrorEvent)
		{
			removeListeners();
			callback(IO_ERROR(e));
		}
		
		file.addEventListener(Event.COMPLETE, onLoad);
		file.addEventListener(IOErrorEvent.IO_ERROR, onError);
		file.load();
	}
	
	static public function fromSave(data:SongDataSave)
	{
		return new SongData(new File(data.path), SongIniData.fromSave(data.data), data.tracks);
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
		return new SongData(file, data, tracks);
	}
	
	static function getTracksInFolder(files:Array<File>)
	{
		final tracks = [];
		
		for (file in files)
		{
			switch (Path.extension(file.name))
			{
				case "ogg" | "opus":
					tracks.push(file.name);
			}
		}
		
		return tracks;
	}
	
	static public function scanForSongs(directory:File, onComplete:(songs:Array<SongData>)->Void, ?onProgress:SongScanProgressCallback)
	{
		final startTime = Timer.stamp();
		var numFoldersChecked = 0;
		final songs = new Array<SongFile>();
		addSongs(directory, songs, function progressCallback (folders)
		{
			numFoldersChecked = folders;
			if (onProgress != null)
				onProgress(folders, 0, 0, 0, Timer.stamp() - startTime);
		});
		trace('Found ${songs.length} file(s) in ${Timer.stamp() - startTime}s');
		
		final successList:Array<SongData> = [];
		final ioErrorList:Array<IOErrorEvent> = [];
		final parseFailList:Array<Exception> = [];
		
		var frameStartTime = Timer.stamp();
		var numUnloaded = songs.length;
		var index = 0;
		function doNext()
		{
			var frameLoadCount = 50;
			while (index < songs.length && frameLoadCount-- > 0)
			// while (index < songs.length)
			{
				final song = songs[index++];
				loadSong(song, function (result)
				{
					switch result
					{
						case SUCCESS(data):
							successList.push(data);
							final name = data.data.name.toString();
							// trace('Loaded "$name", ${numUnloaded - 1} left');
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
					
					if (onProgress != null)
						onProgress(numFoldersChecked, successList.length, ioErrorList.length, parseFailList.length, Timer.stamp() - startTime);
					
					if (--numUnloaded == 0)
						onComplete(successList);
				});
			}
			
			if (index < songs.length)
			{
				frameStartTime = haxe.Timer.stamp();
				FlxTimer.wait(0, doNext);
			}
		}
		doNext();
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

// typedef SongScanCompleteCallback = (successList:Array<SongData>, ioErrorList:Array<IOErrorEvent>, parseFailList:Array<Exception>)->Void;
typedef SongScanProgressCallback = (numFolders:Int, successCount:Int, ioErrorCount:Int, parseFailList:Int, time:Float)->Void;

enum SongFile
{
	FOLDER(folder:File, ini:File);
	SNG(file:File);
	ZIP(file:File);
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
			;
	}
	
	
	static final boolReg = ~/^(?:True|False|0|1)$/;
	static final intReg = ~/-?\d+/;
	
	static public function fromFile(data:UnicodeString, backupName:String):SongIniData
	{
		final lines = data.split("\r\n").join("\n").split("\n");
		final varMap = new Map<String, UnicodeString>();
		final errors = new Array<UnicodeString>();
		
		while (lines.length > 0)
		{
			final line = lines.shift().split(" = ");
			if (line.length == 1 || line[1].length == 0)
				continue;
			
			// varMap[StringTools.trim(line[0])] = StringTools.trim(line[1]);
			varMap[line[0]] = line[1];
		}
		
		if (false == varMap.exists("name"))
			varMap["name"] = '[$backupName]';
		
		function getString(name:String, backup = "")
		{
			if (false == varMap.exists(name))
				return backup;
			
			final result = varMap[name];
			varMap.remove(name);
			return result;
		}
		
		function getBool(name:String, backup = false):Bool
		{
			if (false == varMap.exists(name))
				return backup;
			
			final value = varMap[name];
			varMap.remove(name);
			
			if (boolReg.match(value) == false)
			{
				errors.push('Expected field "$name" to be a Bool, found: "$value"');
				return backup;
			}
			
			return value == "True" || value == "1";
		}
		
		function getInt(name:String, backup = 0):Int
		{
			if (false == varMap.exists(name))
				return backup;
			
			final value = varMap[name];
			varMap.remove(name);
			
			if (intReg.match(value) == false)
			{
				errors.push('Expected field "$name" to be an Int, found: "$value"');
				return backup;
			}
			
			return Std.parseInt(intReg.matched(0));
		}
		
		final nameRaw          = getString("name"               , null);
		final artist           = getString("artist"             );
		final album            = getString("album"              );
		final genre            = getString("genre"              );
		final year             = getString("year"               );
		final icon             = getString("icon"               );
		final charter          = getString("charter"            );
		final proDrums         = getBool  ("pro_drums"          );
		final loadingPhrase    = getString("loading_phrase"     );
		final albumTrack       = getInt   ("album_track"        , -1);
		final songLength       = getInt   ("song_length"        );
		
		// unused
		final fiveLaneDrums    = getBool  ("five_lane_drums"    );
		final sysExSlider      = getBool  ("sysex_slider"       );
		final sysExHighHatCtrl = getBool  ("sysex_high_hat_ctrl");
		final sysExRimshot     = getBool  ("sysex_rimshot"      );
		final sysExOpenBass    = getBool  ("sysex_open_bass"    );
		final diffBand         = getInt   ("diff_band"          );
		final diffGuitar       = getInt   ("diff_guitar"        );
		final diffVocals       = getInt   ("diff_vocals"        );
		final diffDrums        = getInt   ("diff_drums"         );
		final diffBass         = getInt   ("diff_bass"          );
		final diffKeys         = getInt   ("diff_keys"          );
		final diffGuitarReal   = getInt   ("diff_guitar_real"   );
		final diffVocalsHarm   = getInt   ("diff_vocals_harm"   );
		final diffDrumsReal    = getInt   ("diff_drums_real"    );
		final diffBassReal     = getInt   ("diff_bass_real"     );
		final diffKeysReal     = getInt   ("diff_keys_real"     );
		final diffDance        = getInt   ("diff_dance"         );
		final diffGuitarCoop   = getInt   ("diff_guitar_coop"   );
		final diffRhythm       = getInt   ("diff_rhythm"        );
		final diffBassReal22   = getInt   ("diff_bass_real_22"  );
		final diffGuitarReal22 = getInt   ("diff_guitar_real_22");
		final bannerLinkA      = getString("banner_link_a"      );
		final linkNameA        = getString("link_name_a"        );
		final bannerLinkB      = getString("banner_link_b"      );
		final linkNameB        = getString("link_name_b"        );
		final video            = getString("video"              );
		final videoStartTime   = getInt   ("video_start_time"   );
		final previewStartTime = getInt   ("preview_start_time" );
		final diffDrumsRealPs  = getInt   ("diff_drums_real_ps" );
		final diffKeysRealPs   = getInt   ("diff_keys_real_ps"  );
		final delay            = getInt   ("delay"              );
		final diffGuitarGhl    = getInt   ("diff_guitarghl"     );
		final diffBassGhl      = getInt   ("diff_bassghl"       );
		final track            = getInt   ("track"              , -1);
		final playlistTrack    = getInt   ("playlist_track"     , -1);
		final modChart         = getInt   ("modchart"           );
		final multiplierNote   = getInt   ("multiplier_note"    );
		final drumFallbackBlue = getBool  ("drum_fallback_blue" );
		final lastPlay         = getString("last_play"          );
		
		for (key=>value in varMap)
			errors.push('Unused field: $key = $value');
		
		return
			{ name         : nameRaw + (errors.length > 0 ? '(${errors.length}!)': '')
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
			};
	}
	
	public function toSave():SongIniSave
	{
		return 
			{ name          : name
			, artist        : artist
			, album         : album
			, genre         : genre
			, year          : year
			, icon          : icon
			, charter       : charter
			, proDrums     : proDrums
			, loadingPhrase: loadingPhrase
			, albumTrack   : albumTrack
			, songLength   : songLength
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
	};

enum LoadResult<T>
{
	SUCCESS(data:T);
	PARSE_FAIL(e:Exception);
	IO_ERROR(error:IOErrorEvent);
}

enum LoadIniResult
{
	SUCCESS(data:SongIniData);
	PARSE_FAIL(name:String, e:Exception);
	IO_ERROR(name:String, error:IOErrorEvent);
}