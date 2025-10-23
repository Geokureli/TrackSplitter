package ui;

import data.SongData;
import haxe.ui.components.DropDown;
import haxe.ui.core.Component;
import haxe.ui.events.UIEvent;

class FilterDropDown extends DropDownHandler
{
	static public var view:FilterDropDownView = null;
	
	var _view:FilterDropDownView = null;
	
	override function get_component():Component
	{
		if (_view == null)
		{
			view = _view = new FilterDropDownView();
			_view.id = "filterView";
			
			_view.registerEvent(UIEvent.DESTROY, (_)->view = null);
			_view.favBox.registerEvent(UIEvent.CHANGE, (_)->_filterFunc = createFilter());
			_view.monoBox.registerEvent(UIEvent.CHANGE, (_)->_filterFunc = createFilter());
			_view.wavegroupBox.registerEvent(UIEvent.CHANGE, (_)->_filterFunc = createFilter());
		}
		return _view;
	}
	
	static var _filterFunc:(SongData)->Bool;
	static public var filterFunc(get, never):(SongData)->Bool;
	static function get_filterFunc()
	{
		if (_filterFunc == null)
			_filterFunc = createFilter();
		
		return _filterFunc;
	}
	
	static function createFilter()
	{
		if (view == null)
		{
			return function (s)
			{
				return cullEmpty(s)
					&& cullNonFaved(s, false)
					&& cullWavegroup(s, false) 
					&& cullMono(s, false)
					;
			}
		}
		
		final filters = view.getFilters();
		final cullNonFavedOn = filters.contains(NonFavorite);
		final cullWaveGroupOn = filters.contains(WaveGroup);
		final cullMonoOn = filters.contains(Mono);
		
		return function (s)
		{
			return cullEmpty(s)
				&& cullNonFaved(s, cullNonFavedOn)
				&& cullWavegroup(s, cullWaveGroupOn)
				&& cullMono(s, cullMonoOn)
				;
		}
	}
	
	static function cullEmpty(song:SongData)
	{
		return song.tracks.length > 0;
	}
	
	static function cullNonFaved(song:SongData, filterOn:Bool)
	{
		return song.isFavorite || filterOn == false;
	}
	
	static function cullWavegroup(song:SongData, filterOn:Bool)
	{
		return (false == song.isWaveGroup) || filterOn;
	}
	
	static function cullMono(song:SongData, filterOn:Bool)
	{
		return (false == song.isMono) || filterOn;
	}
	
	static public function logFiltered(songs:Array<SongData>)
	{
		final filters = view == null ? [] : view.getFilters();
		final cullNonFavedOn = filters.contains(NonFavorite);
		final cullWaveGroupOn = filters.contains(WaveGroup);
		final cullMonoOn = filters.contains(Mono);
		
		trace('Culling - $filters'
			+ ', empty: ${Lambda.count(songs, (s)->false == cullEmpty(s))}'
			+ ', Non favorites: ${Lambda.count(songs, (s)->false == cullNonFaved(s, cullNonFavedOn))}'
			+ ', wavegroup: ${Lambda.count(songs, (s)->false == cullWavegroup(s, cullWaveGroupOn))}'
			+ ', mono: ${Lambda.count(songs, (s)->false == cullMono(s, cullMonoOn))}'
			);
	}
}

@:xml('<?xml version="1.0" encoding="utf-8" ?>
<vbox style="padding:10px;spacing:10px;">
	<checkbox id="favBox" text="Favorites" />
	<label text="include"/>
	<checkbox id="wavegroupBox" text="Wavegroup covers" selected="false" />
	<checkbox id="monoBox" text="Show Mono" selected="false" />
</vbox>')
class FilterDropDownView extends haxe.ui.containers.VBox
{
	public function new ()
	{
		super();
	}
	
	public function getFilters()
	{
		final filters = [];
		
		if (favBox.selected)
			filters.push(NonFavorite);
		
		if (wavegroupBox.selected)
			filters.push(WaveGroup);
		
		if (monoBox.selected)
			filters.push(Mono);
		
		return filters;
	}
}

enum Filter
{
    NonFavorite;
    WaveGroup;
    Mono;
}