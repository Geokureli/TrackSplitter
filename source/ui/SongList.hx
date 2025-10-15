package ui;

import data.SongData;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteContainer;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import openfl.display.BitmapData;

class SongList extends FlxSpriteContainer
{
	final list:FlxTypedSpriteContainer<SongListItem>;
	
	public function new (x = 0.0, y = 0.0, width:Int, data:Array<SongData>, onSelect:(SongData)->Void)
	{
		super(x, y);
		
		add(list = new FlxTypedSpriteContainer());
		function onClick(item:SongListItem) onSelect(item.song);
		var nextY = 0.0;
		for (song in data)
		{
			final item = new SongListItem(0, nextY, width, song, onClick);
			list.add(item);
			nextY += item.height + 2;
		}
		
		// final cam = new FlxCamera(x, y, width, FlxG.height - y);
		// cam.bgColor = 0x0;
		// FlxG.cameras.add(cam, false);
		// this.camera = cam;
	}
}

class SongListItem extends FlxTypedButton<ItemLabel>
{
	public final song:SongData;
	
	public function new (x = 0.0, y = 0.0, width:Float, song:SongData, onSelect:(SongListItem)->Void)
	{
		this.song = song;
		super(x, y, ()->onSelect(this));
		
		final w = Std.int(width);
		makeGraphic(w, 20, 0xFF0080ff);
		label = new ItemLabel(w, song);
	}
}

class ItemLabel extends FlxSpriteContainer
// class ItemLabel extends FlxText
{
	public function new (width:Int, song:SongData)
	{
		final label = '${song.data.artist} - ${song.data.name}';
		super(0, 0);
		
		final name = new FlxText(0, 0, width, label);
		add(name);
		// super(0, 0, 0, label);
	}
}