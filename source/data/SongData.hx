package data;

import flixel.FlxG;
import flixel.util.FlxTimer;
import haxe.Exception;
import haxe.Timer;
import haxe.io.Path;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.filesystem.File;

class SongData
{
	public final file:File;
	public final data:SongIniData;
	public final tracks:Array<String>;
	
	public function new (file:SongFile, data:SongIniData)
	{
		this.file = switch file
		{
			case FOLDER(folder, _): folder;
			case SNG(file): file;
			case ZIP(file): file;
		}
		this.data = data;
		this.tracks = switch file
		{
			case FOLDER(folder, _): getTracksInFolder(folder.getDirectoryListing());
			case SNG(_): []; // TODO:
			case ZIP(_): []; // TODO:
		}
	}
	
	static function getTracksInFolder(files:Array<File>)
	{
		final tracks = [];
		
		for (file in files)
		{
			if (Path.extension(file.name) == "ogg")
				tracks.push(file.name);
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
	
	static public function loadPath(path:String, onComplete:(LoadSongResult)->Void)
	{
		loadFile(new File(path), onComplete);
	}
	
	static public function loadFile(file:File, onComplete:(LoadSongResult)->Void)
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
							onComplete(SUCCESS(new SongData(song, data)));
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

class SongIniData
{
	public final name            :UnicodeString; // name   
	public final artist          :UnicodeString; // artist 
	public final album           :UnicodeString; // album  
	public final genre           :UnicodeString; // genre  
	public final year            :Int          ; // year   
	public final icon            :String       ; // icon   
	public final charter         :UnicodeString; // charter
	public final proDrums        :Bool         ; // "pro_drums"          
	public final fiveLaneDrums   :Bool         ; // "five_lane_drums"    
	public final sysExSlider     :Bool         ; // "sysex_slider"       
	public final sysExHighHatCtrl:Bool         ; // "sysex_high_hat_ctrl"
	public final sysExRimshot    :Bool         ; // "sysex_rimshot"      
	public final sysExOpenBass   :Bool         ; // "sysex_open_bass"    
	public final diffBand        :Int          ; // "diff_band"          
	public final diffGuitar      :Int          ; // "diff_guitar"        
	public final diffVocals      :Int          ; // "diff_vocals"        
	public final diffDrums       :Int          ; // "diff_drums"         
	public final diffBass        :Int          ; // "diff_bass"          
	public final diffKeys        :Int          ; // "diff_keys"          
	public final diffGuitarReal  :Int          ; // "diff_guitar_real"   
	public final diffVocalsHarm  :Int          ; // "diff_vocals_harm"   
	public final diffDrumsReal   :Int          ; // "diff_drums_real"    
	public final diffBassReal    :Int          ; // "diff_bass_real"     
	public final diffKeysReal    :Int          ; // "diff_keys_real"     
	public final diffDance       :Int          ; // "diff_dance"         
	public final diffGuitarCoop  :Int          ; // "diff_guitar_coop"   
	public final diffRhythm      :Int          ; // "diff_rhythm"        
	public final diffBassReal22  :Int          ; // "diff_bass_real_22"  
	public final diffGuitarReal22:Int          ; // "diff_guitar_real_22"
	public final loadingPhrase   :UnicodeString; // "loading_phrase"     
	public final bannerLinkA     :String       ; // "banner_link_a"      
	public final linkNameA       :String       ; // "link_name_a"        
	public final bannerLinkB     :String       ; // "banner_link_b"      
	public final linkNameB       :String       ; // "link_name_b"        
	public final video           :String       ; // "video"              
	public final videoStartTime  :Int          ; // "video_start_time"   
	public final previewStartTime:Int          ; // "preview_start_time" 
	public final diffDrumsRealPs :Int          ; // "diff_drums_real_ps" 
	public final diffKeysRealPs  :Int          ; // "diff_keys_real_ps"  
	public final delay           :Int          ; // "delay"
	public final diffGuitarGhl   :Int          ; // "diff_guitarghl"     
	public final diffBassGhl     :Int          ; // "diff_bassghl"       
	public final track           :Int          ; // "track"              
	public final albumTrack      :Int          ; // "album_track"        
	public final playlistTrack   :Int          ; // "playlist_track"     
	public final songLength      :Int          ; // "song_length"        
	public final modChart        :Int          ; // "modchart"           
	public final multiplierNote  :Int          ; // "multiplier_note"    
	public final drumFallbackBlue:Bool         ; // "drum_fallback_blue" 
	public final lastPlay        :String       ; // "last_play" 
	
	public final errors:haxe.ds.ReadOnlyArray<UnicodeString> = [];
	
	static final boolReg = ~/^(?:True|False|0|1)$/;
	static final intReg = ~/-?\d+/;
	public function new (data:UnicodeString, backupName:String)
	{
		final lines = data.split("\r\n").join("\n").split("\n");
		final varMap = new Map<String, UnicodeString>();
		final errors:Array<UnicodeString> = cast errors;
		
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
			
			return Std.parseInt(value);
		}
		
		final nameRaw = getString("name"               , null);
		artist           = getString("artist"             );
		album            = getString("album"              );
		genre            = getString("genre"              );
		year             = getInt   ("year"               );
		icon             = getString("icon"               );
		charter          = getString("charter"            );
		proDrums         = getBool  ("pro_drums"          );
		fiveLaneDrums    = getBool  ("five_lane_drums"    );
		sysExSlider      = getBool  ("sysex_slider"       );
		sysExHighHatCtrl = getBool  ("sysex_high_hat_ctrl");
		sysExRimshot     = getBool  ("sysex_rimshot"      );
		sysExOpenBass    = getBool  ("sysex_open_bass"    );
		diffBand         = getInt   ("diff_band"          );
		diffGuitar       = getInt   ("diff_guitar"        );
		diffVocals       = getInt   ("diff_vocals"        );
		diffDrums        = getInt   ("diff_drums"         );
		diffBass         = getInt   ("diff_bass"          );
		diffKeys         = getInt   ("diff_keys"          );
		diffGuitarReal   = getInt   ("diff_guitar_real"   );
		diffVocalsHarm   = getInt   ("diff_vocals_harm"   );
		diffDrumsReal    = getInt   ("diff_drums_real"    );
		diffBassReal     = getInt   ("diff_bass_real"     );
		diffKeysReal     = getInt   ("diff_keys_real"     );
		diffDance        = getInt   ("diff_dance"         );
		diffGuitarCoop   = getInt   ("diff_guitar_coop"   );
		diffRhythm       = getInt   ("diff_rhythm"        );
		diffBassReal22   = getInt   ("diff_bass_real_22"  );
		diffGuitarReal22 = getInt   ("diff_guitar_real_22");
		loadingPhrase    = getString("loading_phrase"     );
		bannerLinkA      = getString("banner_link_a"      );
		linkNameA        = getString("link_name_a"        );
		bannerLinkB      = getString("banner_link_b"      );
		linkNameB        = getString("link_name_b"        );
		video            = getString("video"              );
		videoStartTime   = getInt   ("video_start_time"   );
		previewStartTime = getInt   ("preview_start_time" );
		diffDrumsRealPs  = getInt   ("diff_drums_real_ps" );
		diffKeysRealPs   = getInt   ("diff_keys_real_ps"  );
		delay            = getInt   ("delay"              );
		diffGuitarGhl    = getInt   ("diff_guitarghl"     );
		diffBassGhl      = getInt   ("diff_bassghl"       );
		track            = getInt   ("track"              , -1);
		albumTrack       = getInt   ("album_track"        , -1);
		playlistTrack    = getInt   ("playlist_track"     , -1);
		songLength       = getInt   ("song_length"        );
		modChart         = getInt   ("modchart"           );
		multiplierNote   = getInt   ("multiplier_note"    );
		drumFallbackBlue = getBool  ("drum_fallback_blue" );
		lastPlay         = getString("last_play"          );
		
		for (key=>value in varMap)
			errors.push('Unused field: $key = $value');
		
		name = nameRaw + (errors.length > 0 ? '(${errors.length}!)': '');
		// trace('$name:${errors.join("\n")}');
	}
	
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
			+ '\n, five_lane_drums    : $fiveLaneDrums   '
			+ '\n, sysex_slider       : $sysExSlider     '
			+ '\n, sysex_high_hat_ctrl: $sysExHighHatCtrl'
			+ '\n, sysex_rimshot      : $sysExRimshot    '
			+ '\n, sysex_open_bass    : $sysExOpenBass   '
			+ '\n, diff_band          : $diffBand        '
			+ '\n, diff_guitar        : $diffGuitar      '
			+ '\n, diff_vocals        : $diffVocals      '
			+ '\n, diff_drums         : $diffDrums       '
			+ '\n, diff_bass          : $diffBass        '
			+ '\n, diff_keys          : $diffKeys        '
			+ '\n, diff_guitar_real   : $diffGuitarReal  '
			+ '\n, diff_vocals_harm   : $diffVocalsHarm  '
			+ '\n, diff_drums_real    : $diffDrumsReal   '
			+ '\n, diff_bass_real     : $diffBassReal    '
			+ '\n, diff_keys_real     : $diffKeysReal    '
			+ '\n, diff_dance         : $diffDance       '
			+ '\n, diff_guitar_coop   : $diffGuitarCoop  '
			+ '\n, diff_rhythm        : $diffRhythm      '
			+ '\n, diff_bass_real_22  : $diffBassReal22  '
			+ '\n, diff_guitar_real_22: $diffGuitarReal22'
			+ '\n, loading_phrase     : "$loadingPhrase" '
			+ '\n, banner_link_a      : "$bannerLinkA"   '
			+ '\n, link_name_a        : "$linkNameA"     '
			+ '\n, banner_link_b      : "$bannerLinkB"   '
			+ '\n, link_name_b        : "$linkNameB"     '
			+ '\n, video              : "$video"         '
			+ '\n, video_start_time   : $videoStartTime  '
			+ '\n, preview_start_time : $previewStartTime'
			+ '\n, diff_drums_real_ps : $diffDrumsRealPs '
			+ '\n, diff_keys_real_ps  : $diffKeysRealPs  '
			+ '\n, delay              : $delay           '
			+ '\n, diff_guitarghl     : $diffGuitarGhl   '
			+ '\n, diff_bassghl       : $diffBassGhl     '
			+ '\n, album_track        : $albumTrack      '
			+ '\n, playlist_track     : $playlistTrack   '
			+ '\n, song_length        : $songLength      '
			+ '\n, modchart           : $modChart        '
			+ '\n, multiplier_note    : $multiplierNote  '
			+ '\n, drum_fallback_blue : $drumFallbackBlue'
			;
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
				callback(SUCCESS(new SongIniData(file.data.toString(), songName)));
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

enum LoadIniResult
{
	SUCCESS(data:SongIniData);
	PARSE_FAIL(name:String, e:Exception);
	IO_ERROR(name:String, error:IOErrorEvent);
}