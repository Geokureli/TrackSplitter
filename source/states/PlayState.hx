package states;

import data.SongData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteContainer;
import flixel.sound.FlxDjTrack.FlxTypedDjTrack;
import flixel.sound.FlxDjTrack;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxSignal;
import flixel.util.typeLimit.NextState;
import haxe.io.Path;
import openfl.media.Sound;

class PlayState extends flixel.FlxState
{
	public final track:FlxDjTrack;
	public var ui:TrackUI;
	
	public function new(song:SongData, backState:NextState)
	{
		super();
		bgColor = 0xFF808080;
		
		track = new FlxDjTrack();
		function onLoad()
		{
			add(track);
			add(ui = new TrackUI(track, song.data.name, ()->track.play(), ()->track.play(true)));
			ui.screenCenter();
		}
		
		var soundsLeft = song.tracks.length;
		for (trackPath in song.tracks)
		{
			final future = Sound.loadFromFile(Path.normalize(song.file.nativePath + "/" + trackPath));
			future.onComplete(function (sound)
			{
				track.add(trackPath, sound);
				if (--soundsLeft == 0)
					onLoad();
			});
		}
		
		add(new FlxButton(10, 10, "Back to Library", ()->FlxG.switchState(backState)));
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
	}
}

private class TrackUI extends FlxSpriteContainer
{
	public final track:FlxDjTrack;
	
	final channels = new FlxTypedSpriteContainer<ChannelUI>();
	final name:String;
	final label:FlxText;
	final playhead:Playhead;
	
	public function new (track, name:String, onPlay:()->Void, onRestart:()->Void)
	{
		this.track = track;
		this.name = name;
		super();
		
		var y = 0.0;
		final gap = 4;
		
		label = new FlxText(0, y, ChannelUI.LABEL_WIDTH, name);
		add(label);
		
		final playBtn = new FlxButton(0, y, "Play", onPlay);
		playBtn.x = label.x + label.width;
		label.y = playBtn.y + (playBtn.height - label.height) / 2;
		add(playBtn);
		
		final restartBtn = new FlxButton(0, y, "Restart", onRestart);
		restartBtn.x = playBtn.x + playBtn.width + ChannelUI.BUTTON_GAP;
		label.y = restartBtn.y + (restartBtn.height - label.height) / 2;
		add(restartBtn);
		
		y += playBtn.height + gap;
		
		playhead = new Playhead(1, y + 1, Std.int(this.width) - 2);
		playhead.onDrag.add(onPlayheadDrag);
		add(playhead);
		
		y += playhead.height + gap;
		
		final allOnBtn = new FlxButton(0, y, "All on", allOnClick);
		allOnBtn.x = ChannelUI.LABEL_WIDTH;
		add(allOnBtn);
		
		final allOffBtn = new FlxButton(0, y, "All off", allOffClick);
		allOffBtn.x = allOnBtn.x + allOnBtn.width + ChannelUI.BUTTON_GAP;
		add(allOffBtn);
		
		y += allOnBtn.height + gap;
		
		for (id=>channel in track.channels)
		{
			if (channel.syncMode.match(ONCE))
			{
				final button = new ChannelUI(0, y, track, id);
				channels.add(button);
				y += button.height + gap;
			}
		}
		
		final margin = 3;
		final loopLabel = new FlxText(0, y - margin, "Sub-loops");
		loopLabel.x = (channels.width - loopLabel.width) / 2;
		loopLabel.exists = false;
		y += loopLabel.height + gap - margin * 2;
		
		for (id=>channel in track.channels)
		{
			if (channel.syncMode.match(LOOP(_)))
			{
				final button = new ChannelUI(0, y, track, id);
				channels.add(button);
				y += button.height + gap;
				loopLabel.exists = true;
			}
		}
		
		add(channels);
		add(loopLabel);
	}
	
	function allOnClick()
	{
		for (id=>channel in track.channels)
		{
			if (channel.syncMode.match(ONCE) && channel.volume != 1.0)
				channel.fadeTo(ChannelUI.fadeTime, 1.0);
		}
	}
	
	function allOffClick()
	{
		for (id=>channel in track.channels)
		{
			if (channel.syncMode.match(ONCE) && channel.volume != 0.0)
				channel.fadeTo(ChannelUI.fadeTime, 0.0);
		}
	}
	
	function onPlayheadDrag(ratio:Float)
	{
		track.time = (track.duration * ratio);
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		label.text = '$name: ${Math.floor(track.volume * 100)}';
		
		for (channel in channels)
			channel.label.text = '${channel.id}: ${Math.floor(100 * track.getChannelVolume(channel.id))}';
		
		playhead.setPlayPosition(track.time / track.duration);
	}
}

private class ChannelUI extends FlxSpriteContainer
{
	static public inline var LABEL_WIDTH = 400;
	static public inline var BUTTON_GAP = 4;
	static public var fadeTime = 0.25;
	
	public final label:FlxText;
	public final toggleBtn:FlxButton;
	public final focusBtn:FlxButton;
	public final id:String;
	
	public function new (x = 0.0, y = 0.0, track:FlxDjTrack, id:String)
	{
		this.id = id;
		super();
		
		label = new FlxText(0, 0, LABEL_WIDTH, '$id: 0');
		
		toggleBtn = new FlxButton(label.width, 0, "toggle", function()
		{
			if (track.getChannelVolume(id) == 0)
				track.fadeChannelIn(id, fadeTime);
			else
				track.fadeChannelOut(id, fadeTime);
		});
		
		focusBtn = new FlxButton(toggleBtn.x + toggleBtn.width + BUTTON_GAP, 0, "focus", ()->track.fadeChannelFocus(id, fadeTime));
		
		label.y = toggleBtn.y + (toggleBtn.height - label.height) / 2;
		add(label);
		add(toggleBtn);
		add(focusBtn);
		
		this.x = x;
		this.y = y;
	}
}

private class Playhead extends FlxSpriteContainer
{
	public var onDrag = new FlxTypedSignal<(Float)->Void>();
	
	final bg:FlxSprite;
	final inner:FlxSprite;
	final handle:FlxSprite;
	var dragging = false;
	
	var thickness(get, never):Float;
	inline function get_thickness() return bg.height / 2;
	
	public function new (x = 0.0, y = 0.0, width:Int, thickness = 7, inset = 1)
	{
		super(x, y);
		
		if (thickness <= inset)
			throw 'playhead thickness cannot be $thickness with an inset of $inset';
		
		bg = new FlxSprite(0, 0);
		bg.makeGraphic(width, thickness, 0xFF000000);
		add(bg);
		
		inner = new FlxSprite(inset, inset);
		inner.makeGraphic(width - (inset * 2), thickness - (inset * 2), 0xFFffffff);
		inner.origin.x = 0;
		add(inner);
		
		final OUTSET = 1;
		handle = new FlxSprite(thickness, -OUTSET);
		handle.makeGraphic(thickness + (2 * OUTSET), thickness + (2 * OUTSET), 0xFFa0a0a0);
		handle.offset.x = handle.origin.x;
		add(handle);
	}
	
	public function setPlayPosition(ratio:Float)
	{
		inner.scale.x = ratio;
		if (!dragging)
			handle.x = this.x + thickness + (bg.width - thickness * 2) * ratio;
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(bg))
			dragging = true;
		
		if (dragging)
		{
			handle.x = FlxG.mouse.x;
			if (handle.x < bg.x + thickness)
				handle.x = bg.x + thickness;
			
			if (handle.x > bg.x + bg.width - thickness)
				handle.x = bg.x + bg.width - thickness;
		}
		
		if (FlxG.mouse.justReleased)
		{
			dragging = false;
			final ratio = (handle.x - (bg.x + thickness)) / (bg.width - 2 * thickness);
			setPlayPosition(ratio);
			onDrag.dispatch(ratio);
		}
	}
}