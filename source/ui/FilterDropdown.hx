package ui;

import haxe.ui.components.DropDown;
import haxe.ui.core.Component;
import haxe.ui.events.UIEvent;


// TODO: improve api, could be simpler
@:access(haxe.ui.core.Component)
class FilterDropDown extends DropDownHandler
{
	public var favorites(get, never):Bool; inline function get_favorites() return _view.filterFav.selected;
	public var ogArtists(get, never):Bool; inline function get_ogArtists() return _view.filterOG.selected;
	
	var _view:FilterDropDownView = null;
	
	override function get_component():Component
	{
		if (_view == null)
		{
			_view = new FilterDropDownView();
			
			function onChange(_)
			{
				_dropdown.dispatch(new UIEvent(UIEvent.CHANGE));
			}
			
			_view.filterFav.registerEvent(UIEvent.CHANGE, onChange);
			_view.filterOG.registerEvent(UIEvent.CHANGE, onChange);
		}
		return _view;
	}
	
	public function getFilters()
	{
		final filters = [];
		
		if (favorites)
			filters.push(Favorite);
		
		if (ogArtists)
			filters.push(OGArtist);
		
		return filters;
	}
}


@:xml('<?xml version="1.0" encoding="utf-8" ?>
<vbox style="padding:10px;spacing:10px;">
	<checkbox id="filterFav" text="Favorites" />
	<checkbox id="filterOG" text="Original Artist" />
</vbox>')
class FilterDropDownView extends haxe.ui.containers.VBox
{
    // public final onFiltersChange:(filters:Array<Filter>)->Void;
    // public var favorites(get, never):Bool; inline function get_favorites() return filterFav.selected;
    // public var ogArtists(get, never):Bool; inline function get_ogArtists() return filterOG.selected;
    
	public function new ()
	{
        // onFiltersChange = onChange;
        super();
    }
    
    // @:bind(applyBtn, MouseEvent.CLICK)
    // public function getFilters()
    // {
    //     final filters = [];
        
    //     if (favorites)
    //         filters.push(Favorite);
        
    //     if (ogArtists)
    //         filters.push(OGArtist);
        
    //     return filters;
    // }
}

enum Filter
{
    Favorite;
    OGArtist;
}