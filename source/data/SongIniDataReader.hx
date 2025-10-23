package data;

class DataReader
{
	static public function parse(data:UnicodeString, fields:Map<String, { name:String, type:FieldType }>, ?errors:Array<ParseError>):Any
	{
		// convert \r\n to \n
		final lines = data.split("\r\n").join("\n").split("\n");
		final varMap = new Map<String, UnicodeString>();
		errors = errors ?? [];
		while (lines.length > 0)
		{
			final line = lines.shift().split(" = ");
			if (line.length == 1 || line[1].length == 0)
				continue;
			
			// varMap[StringTools.trim(line[0])] = StringTools.trim(line[1]);
			varMap[line[0]] = line[1];
		}
		
		final result:Any = {};
		
		for (id=>value in varMap)
		{
			if (fields.exists(id))
			{
				final parsedValue:Any = switch fields[id].type
				{
					case NONE: null;
					case STRING:
						value;
					case BOOL:
						getBool(value);
					case INT16|INT32|INT64:
						getInt(value);
					case UINT16|UINT32|UINT64:
						getUint(value);
					case FLOAT|DOUBLE:
						getFloat(value);
					case INT64_ARRAY:
						getIntArray(value);
				}
				
				if (parsedValue != null)
					Reflect.setField(result, fields[id].name, parsedValue);
				else
					errors.push(TYPE(fields[id].type, id, value));
			}
			else
				errors.push(UNDEFINED(id, value));
		}
		
		return result;
	}
	
	static final intReg = ~/^-?\d+$/;
	static function getInt(value:String):Null<Int>
	{
		if (intReg.match(value) == false)
			return null;
		
		return Std.parseInt(value);
	}
	
	static final uintReg = ~/^\d+$/;
	static function getUint(value:String):Null<UInt>
	{
		if (uintReg.match(value) == false)
			return null;
		
		return Std.parseInt(value);
	}
	
	static final floatReg = ~/^(?:0|(-?[1-9]\d*\.?\d*)|(-?0?\.\d+))$/;
	static function getFloat(value:String):Null<Float>
	{
		if (floatReg.match(value) == false)
			return null;
		
		return Std.parseFloat(value);
	}
	
	static final boolReg = ~/^(?:True|False|0|1)$/;
	static function getBool(value:String):Null<Bool>
	{
		if (boolReg.match(value) == false)
			return null;
		
		return value == "True" || value == "1";
	}
	
	
	static function getIntArray(value:String):Null<Array<Int>>
	{
		throw "Int arrays not yet implemented";
	}
}

typedef FieldData = { name: String, type:Type }

enum ParseError
{
	TYPE(type:FieldType, field:String, value:UnicodeString);
	UNDEFINED(field:String, value:UnicodeString);
	DUPLICATE(field:String, value1:UnicodeString, value2:UnicodeString);
}

enum abstract SongRating(Int) from Int
{
	var UNSPECIFIED;
	var FAMILY_FRIENDLY;
	var SUPERVISION_RECOMMENDED;
	var MATURE;
	var NO_RATING;
}

enum FieldType
{
	NONE;
	STRING;
	BOOL;
	FLOAT;
	DOUBLE;
	INT16;
	INT32;
	INT64;
	UINT16;
	UINT32;
	UINT64;
	INT64_ARRAY;
}




typedef SongIniDataRaw =
{ album                               : UnicodeString
, album_track                         : Int
, artist                              : UnicodeString
, background                          : String
, banner_link_a                       : String
, banner_link_b                       : String
, bass_type                           : Int
, boss_battle                         : Bool
, cassettecolor                       : Int
, charter                             : UnicodeString
, charter_bass                        : UnicodeString
, charter_drums                       : UnicodeString
, charter_elite_drums                 : UnicodeString
, charter_guitar                      : UnicodeString
, charter_keys                        : UnicodeString
, charter_lower_diff                  : UnicodeString
, charter_pro_bass                    : UnicodeString
, charter_pro_keys                    : UnicodeString
, charter_pro_guitar                  : UnicodeString
, charter_vocals                      : UnicodeString
, count                               : Int
, cover                               : UnicodeString
, credit_album_art_designed_by        : UnicodeString
, credit_arranged_by                  : UnicodeString
, credit_composed_by                  : UnicodeString
, credit_courtesy_of                  : UnicodeString
, credit_engineered_by                : UnicodeString
, credit_license                      : UnicodeString
, credit_mastered_by                  : UnicodeString
, credit_mixed_by                     : UnicodeString
, credit_other                        : UnicodeString
, credit_performed_by                 : UnicodeString
, credit_produced_by                  : UnicodeString
, credit_published_by                 : UnicodeString
, credit_written_by                   : UnicodeString
, dance_type                          : Int
, delay                               : Int
, diff_band                           : Int
, diff_bass                           : Int
, diff_bass_real                      : Int
, diff_bass_real_22                   : Int
, diff_bassghl                        : Int
, diff_dance                          : Int
, diff_drums                          : Int
, diff_drums_real                     : Int
, diff_drums_real_ps                  : Int
, diff_guitar                         : Int
, diff_guitar_coop                    : Int
, diff_guitar_coop_ghl                : Int
, diff_guitar_real                    : Int
, diff_guitar_real_22                 : Int
, diff_guitarghl                      : Int
, diff_keys                           : Int
, diff_keys_real                      : Int
, diff_keys_real_ps                   : Int
, diff_rhythm                         : Int
, diff_rhythm_ghl                     : Int
, diff_vocals                         : Int
, diff_vocals_harm                    : Int
, drum_fallback_blue                  : Bool
, early_hit_window_size               : UnicodeString
, eighthnote_hopo                     : Bool
, end_events                          : Bool
, eof_midi_import_drum_accent_velocity: Int
, eof_midi_import_drum_ghost_velocity : Int
, five_lane_drums                     : Bool
, frets                               : UnicodeString
, genre                               : UnicodeString
, guitar_type                         : Int
, hopo_frequency                      : Int
, hopofreq                            : Int
, icon                                : UnicodeString
, keys_type                           : Int
, kit_type                            : Int
, link_name_a                         : UnicodeString
, link_name_b                         : UnicodeString
, link_bandcamp                       : UnicodeString
, link_bluesky                        : UnicodeString
, link_facebook                       : UnicodeString
, link_instagram                      : UnicodeString
, link_spotify                        : UnicodeString
, link_twitter                        : UnicodeString
, link_other                          : UnicodeString
, link_youtube                        : UnicodeString
, loading_phrase                      : UnicodeString
, location                            : UnicodeString
, lyrics                              : Bool
, modchart                            : Bool
, multiplier_note                     : Int
, name                                : UnicodeString
, playlist                            : UnicodeString
, playlist_track                      : Int
, preview                             : Array<Int>
, preview_end_time                    : Int
, preview_start_time                  : Int
, pro_drums                           : Bool
, rating                              : SongRating
, real_bass_22_tuning                 : Int
, real_bass_tuning                    : Int
, real_guitar_22_tuning               : Int
, real_guitar_tuning                  : Int
, real_keys_lane_count_left           : Int
, real_keys_lane_count_right          : Int
, scores                              : UnicodeString
, scores_ext                          : UnicodeString
, song_length                         : Int
, sub_genre                           : UnicodeString
, sub_playlist                        : UnicodeString
, sustain_cutoff_threshold            : Int
, sysex_high_hat_ctrl                 : Bool
, sysex_open_bass                     : Bool
, sysex_pro_slide                     : Bool
, sysex_rimshot                       : Bool
, sysex_slider                        : Bool
, tags                                : UnicodeString
, tutorial                            : Bool
, unlock_completed                    : Int
, unlock_id                           : UnicodeString
, unlock_require                      : UnicodeString
, unlock_text                         : UnicodeString
, version                             : Int
, video                               : UnicodeString
, video_end_time                      : Int
, video_loop                          : Bool
, video_start_time                    : Int
, vocal_gender                        : Int
, year                                : UnicodeString
}


class SongIniDataReader
{
	static final iniFields = 
		[ "album"                                => { name: "album"                                , type: STRING }
		, "album_track"                          => { name: "album_track"                          , type: INT32  }
		, "track"                                => { name: "album_track"                          , type: INT32  }
		, "artist"                               => { name: "artist"                               , type: STRING }
		
		, "background"                           => { name: "background"                           , type: STRING }
		, "banner_link_a"                        => { name: "banner_link_a"                        , type: STRING }
		, "banner_link_b"                        => { name: "banner_link_b"                        , type: STRING }
		, "bass_type"                            => { name: "bass_type"                            , type: UINT32 }
		, "boss_battle"                          => { name: "boss_battle"                          , type: BOOL   }
		
		, "cassettecolor"                        => { name: "cassettecolor"                        , type: UINT32 }
		, "charter"                              => { name: "charter"                              , type: STRING }
		, "charter_bass"                         => { name: "charter_bass"                         , type: STRING }
		, "charter_drums"                        => { name: "charter_drums"                        , type: STRING }
		, "charter_elite_drums"                  => { name: "charter_elite_drums"                  , type: STRING }
		, "charter_guitar"                       => { name: "charter_guitar"                       , type: STRING }
		, "charter_keys"                         => { name: "charter_keys"                         , type: STRING }
		, "charter_lower_diff"                   => { name: "charter_lower_diff"                   , type: STRING }
		, "charter_pro_bass"                     => { name: "charter_pro_bass"                     , type: STRING }
		, "charter_pro_keys"                     => { name: "charter_pro_keys"                     , type: STRING }
		, "charter_pro_guitar"                   => { name: "charter_pro_guitar"                   , type: STRING }
		, "charter_venue"                        => { name: "charter_venue"                        , type: STRING }
		, "charter_vocals"                       => { name: "charter_vocals"                       , type: STRING }
		, "count"                                => { name: "count"                                , type: UINT32 }
		, "cover"                                => { name: "cover"                                , type: STRING }
		, "credit_album_art_designed_by"         => { name: "credit_album_art_designed_by"         , type: STRING }
		, "credit_album_art_by"                  => { name: "credit_album_art_designed_by"         , type: STRING }
		, "credit_album_cover"                   => { name: "credit_album_art_designed_by"         , type: STRING }
		, "credit_arranged_by"                   => { name: "credit_arranged_by"                   , type: STRING }
		, "credit_composed_by"                   => { name: "credit_composed_by"                   , type: STRING }
		, "credit_courtesy_of"                   => { name: "credit_courtesy_of"                   , type: STRING }
		, "credit_engineered_by"                 => { name: "credit_engineered_by"                 , type: STRING }
		, "credit_license"                       => { name: "credit_license"                       , type: STRING }
		, "credit_mastered_by"                   => { name: "credit_mastered_by"                   , type: STRING }
		, "credit_mixed_by"                      => { name: "credit_mixed_by"                      , type: STRING }
		, "credit_other"                         => { name: "credit_other"                         , type: STRING }
		, "credit_performed_by"                  => { name: "credit_performed_by"                  , type: STRING }
		, "credit_produced_by"                   => { name: "credit_produced_by"                   , type: STRING }
		, "credit_published_by"                  => { name: "credit_published_by"                  , type: STRING }
		, "credit_written_by"                    => { name: "credit_written_by"                    , type: STRING }
		
		, "dance_type"                           => { name: "dance_type"                           , type: UINT32 }
		, "delay"                                => { name: "delay"                                , type: INT64  }
		, "diff_band"                            => { name: "diff_band"                            , type: INT32  }
		, "diff_bass"                            => { name: "diff_bass"                            , type: INT32  }
		, "diff_bass_real"                       => { name: "diff_bass_real"                       , type: INT32  }
		, "diff_bass_real_22"                    => { name: "diff_bass_real_22"                    , type: INT32  }
		, "diff_bassghl"                         => { name: "diff_bassghl"                         , type: INT32  }
		, "diff_dance"                           => { name: "diff_dance"                           , type: INT32  }
		, "diff_drums"                           => { name: "diff_drums"                           , type: INT32  }
		, "diff_drums_real"                      => { name: "diff_drums_real"                      , type: INT32  }
		, "diff_drums_real_ps"                   => { name: "diff_drums_real_ps"                   , type: INT32  }
		, "diff_elite_drums"                     => { name: "diff_elite_drums"                     , type: INT32  }
		, "diff_guitar"                          => { name: "diff_guitar"                          , type: INT32  }
		, "diff_guitar_coop"                     => { name: "diff_guitar_coop"                     , type: INT32  }
		, "diff_guitar_coop_ghl"                 => { name: "diff_guitar_coop_ghl"                 , type: INT32  }
		, "diff_guitar_real"                     => { name: "diff_guitar_real"                     , type: INT32  }
		, "diff_guitar_real_22"                  => { name: "diff_guitar_real_22"                  , type: INT32  }
		, "diff_guitarghl"                       => { name: "diff_guitarghl"                       , type: INT32  }
		, "diff_keys"                            => { name: "diff_keys"                            , type: INT32  }
		, "diff_keys_real"                       => { name: "diff_keys_real"                       , type: INT32  }
		, "diff_keys_real_ps"                    => { name: "diff_keys_real_ps"                    , type: INT32  }
		, "diff_rhythm"                          => { name: "diff_rhythm"                          , type: INT32  }
		, "diff_rhythm_ghl"                      => { name: "diff_rhythm_ghl"                      , type: INT32  }
		, "diff_vocals"                          => { name: "diff_vocals"                          , type: INT32  }
		, "diff_vocals_harm"                     => { name: "diff_vocals_harm"                     , type: INT32  }
		, "drum_fallback_blue"                   => { name: "drum_fallback_blue"                   , type: BOOL   }
		
		, "early_hit_window_size"                => { name: "early_hit_window_size"                , type: STRING }
		, "eighthnote_hopo"                      => { name: "eighthnote_hopo"                      , type: BOOL   }
		, "end_events"                           => { name: "end_events"                           , type: BOOL   }
		, "eof_midi_import_drum_accent_velocity" => { name: "eof_midi_import_drum_accent_velocity" , type: UINT16 }
		, "eof_midi_import_drum_ghost_velocity"  => { name: "eof_midi_import_drum_ghost_velocity"  , type: UINT16 }
		
		, "five_lane_drums"                      => { name: "five_lane_drums"                      , type: BOOL   }
		, "frets"                                => { name: "frets"                                , type: STRING }
		
		, "genre"                                => { name: "genre"                                , type: STRING }
		, "guitar_type"                          => { name: "guitar_type"                          , type: UINT32 }
		
		, "hopo_frequency"                       => { name: "hopo_frequency"                       , type: INT64  }
		, "hopofreq"                             => { name: "hopofreq"                             , type: INT32  }
		
		, "icon"                                 => { name: "icon"                                 , type: STRING }
		
		, "keys_type"                            => { name: "keys_type"                            , type: UINT32 }
		, "kit_type"                             => { name: "kit_type"                             , type: UINT32 }
		
		, "link_name_a"                          => { name: "link_name_a"                          , type: STRING }
		, "link_name_b"                          => { name: "link_name_b"                          , type: STRING }
		, "link_bandcamp"                        => { name: "link_bandcamp"                        , type: STRING }
		, "link_bluesky"                         => { name: "link_bluesky"                         , type: STRING }
		, "link_facebook"                        => { name: "link_facebook"                        , type: STRING }
		, "link_instagram"                       => { name: "link_instagram"                       , type: STRING }
		, "link_spotify"                         => { name: "link_spotify"                         , type: STRING }
		, "link_twitter"                         => { name: "link_twitter"                         , type: STRING }
		, "link_other"                           => { name: "link_other"                           , type: STRING }
		, "link_youtube"                         => { name: "link_youtube"                         , type: STRING }
		, "loading_phrase"                       => { name: "loading_phrase"                       , type: STRING }
		, "location"                             => { name: "location"                             , type: STRING }
		, "lyrics"                               => { name: "lyrics"                               , type: BOOL   }
		
		, "modchart"                             => { name: "modchart"                             , type: BOOL   }
		, "multiplier_note"                      => { name: "multiplier_note"                      , type: INT32  }
		, "star_power_note"                      => { name: "multiplier_note"                      , type: INT32  }
		
		, "name"                                 => { name: "name"                                 , type: STRING }
		
		, "playlist"                             => { name: "playlist"                             , type: STRING }
		, "playlist_track"                       => { name: "playlist_track"                       , type: INT32  }
		, "preview"                              => { name: "preview"                              , type: INT64_ARRAY }
		, "preview_end_time"                     => { name: "preview_end_time"                     , type: INT64  }
		, "preview_start_time"                   => { name: "preview_start_time"                   , type: INT64  }
		, "pro_drum"                             => { name: "pro_drums"                            , type: BOOL   }
		, "pro_drums"                            => { name: "pro_drums"                            , type: BOOL   }
		
		, "rating"                               => { name: "rating"                               , type: UINT32 }
		, "real_bass_22_tuning"                  => { name: "real_bass_22_tuning"                  , type: UINT32 }
		, "real_bass_tuning"                     => { name: "real_bass_tuning"                     , type: UINT32 }
		, "real_guitar_22_tuning"                => { name: "real_guitar_22_tuning"                , type: UINT32 }
		, "real_guitar_tuning"                   => { name: "real_guitar_tuning"                   , type: UINT32 }
		, "real_keys_lane_count_left"            => { name: "real_keys_lane_count_left"            , type: UINT32 }
		, "real_keys_lane_count_right"           => { name: "real_keys_lane_count_right"           , type: UINT32 }
		
		, "scores"                               => { name: "scores"                               , type: STRING }
		, "scores_ext"                           => { name: "scores_ext"                           , type: STRING }
		, "song_length"                          => { name: "song_length"                          , type: INT64  }
		, "sub_genre"                            => { name: "sub_genre"                            , type: STRING }
		, "sub_playlist"                         => { name: "sub_playlist"                         , type: STRING }
		, "sustain_cutoff_threshold"             => { name: "sustain_cutoff_threshold"             , type: INT64  }
		, "sysex_high_hat_ctrl"                  => { name: "sysex_high_hat_ctrl"                  , type: BOOL   }
		, "sysex_open_bass"                      => { name: "sysex_open_bass"                      , type: BOOL   }
		, "sysex_pro_slide"                      => { name: "sysex_pro_slide"                      , type: BOOL   }
		, "sysex_rimshot"                        => { name: "sysex_rimshot"                        , type: BOOL   }
		, "sysex_slider"                         => { name: "sysex_slider"                         , type: BOOL   }
		
		, "tags"                                 => { name: "tags"                                 , type: STRING }
		, "tutorial"                             => { name: "tutorial"                             , type: BOOL   }
		
		, "unlock_completed"                     => { name: "unlock_completed"                     , type: UINT32 }
		, "unlock_id"                            => { name: "unlock_id"                            , type: STRING }
		, "unlock_require"                       => { name: "unlock_require"                       , type: STRING }
		, "unlock_text"                          => { name: "unlock_text"                          , type: STRING }
		
		, "version"                              => { name: "version"                              , type: UINT32 }
		, "video"                                => { name: "video"                                , type: STRING }
		, "video_end_time"                       => { name: "video_end_time"                       , type: INT64  }
		, "video_loop"                           => { name: "video_loop"                           , type: BOOL   }
		, "video_start_time"                     => { name: "video_start_time"                     , type: INT64  }
		, "vocal_gender"                         => { name: "vocal_gender"                         , type: UINT32 }
		, "vocal_scroll_speed"                   => { name: "vocal_scroll_speed"                   , type: INT16  }
		
		, "year"                                 => { name: "year"                                 , type: STRING }
		];
		
	inline static public function parse(data, ?errors):SongIniDataRaw
	{
		return cast DataReader.parse(data, iniFields, errors);
	}
}