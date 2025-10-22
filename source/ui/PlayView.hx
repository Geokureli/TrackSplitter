package ui;

import data.SongData;
import flixel.sound.FlxDjTrack;
import haxe.io.Path;
import haxe.ui.containers.HBox;
import haxe.ui.containers.VBox;
import haxe.ui.events.DragEvent;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import openfl.events.Event;
import openfl.media.Sound;

@:build(haxe.ui.ComponentBuilder.build('assets/data/play-view.xml'))
class PlayView extends VBox
{
	final track = new FlxDjTrack();
	final items = new Array<ChannelItem>();
	var draggingPlayhead = false;
	
	public function new(song:SongData)
	{
		super();
		
		titleText.text = song.data.name;

		registerEvent(UIEvent.SHOWN, function (e)
		{
			song.loadTracks(function (sounds)
			{
				for (track=>sound in sounds)
					addChannel(sound, track);
			});
			onLoad();
		});
		
		addEventListener(Event.ENTER_FRAME, update);
	}
	
	function onLoad()
	{
		loadAnim.hide();
		channelList.show();
		
		playhead.max = track.length;
		playhead.registerEvent(DragEvent.DRAG_START, (_)->draggingPlayhead = true);
		playhead.registerEvent(DragEvent.DRAG_END, function (e)
		{
			draggingPlayhead = false;
			track.time = playhead.pos;
		});
		
		onBtn.show();
		onBtn.registerEvent(MouseEvent.CLICK, function (_)
		{
			for (item in items)
				item.volume.pos = item.volume.max;
		});
		
		offBtn.show();
		offBtn.registerEvent(MouseEvent.CLICK, function (_)
		{
			for (item in items)
				item.volume.pos = 0;
		});
		
		masterVolume.show();
		masterVolume.registerEvent(DragEvent.DRAG, (_)->track.volume = masterVolume.pos / masterVolume.max);
		
		playBtn.show();
		playBtn.registerEvent(MouseEvent.CLICK, function (_)
		{
			if (track.playing)
			{
				track.pause();
				playBtn.text = ">";//"▶";
			}
			else
			{
				track.play();
				playBtn.text = "||";//"▮▮";
			}
		});
		
		restartBtn.show();
		restartBtn.registerEvent(MouseEvent.CLICK, function (_)
		{
			playBtn.text = "||";//"▮▮";
			track.play(true);
		});
	}
	
	function addChannel(sound:Sound, name:String)
	{
		final channel = track.add(name, sound);
		var item:ChannelItem = null;
		item = new ChannelItem(name, (volume)->channel.fadeTo(0.05, volume), ()->setFocus(item));
		items.push(item);
		channelList.addComponent(item);
	}
	
	function setFocus(focusItem:ChannelItem)
	{
		for (item in items)
		{
			if (item != focusItem)
			{
				item.volume.pos = 0;
				item.mute.text = "Unmute";
			}
		}
		
		if (focusItem.volume.pos == 0)
		{
			focusItem.volume.pos = focusItem.volume.max;
			focusItem.mute.text = "Mute";
		}
	}
	
	function update(_)
	{
		if (track.playing && false == draggingPlayhead)
		{
			// trace('range: ${playhead.min}<->${playhead.max} - ${track.time}');
			playhead.pos = track.time;
		}
	}
}

@:xml('<?xml version="1.0" encoding="utf-8" ?>
<hbox width="100%">
	<label id="nameText" width="124" verticalAlign="center" />
	<slider id="volume" pos="100" verticalAlign="center" width="100%" />
	<button id="mute" text="Mute"  width="80" />
	<button id="focus" text="Focus" width="80" />
</hbox>
')
class ChannelItem extends HBox
{
	public function new(name:String, onVolumeChange:(Float)->Void, onFocusClick:()->Void)
	{
		super();
		
		nameText.text = name;
		volume.registerEvent(UIEvent.CHANGE, (_)->onVolumeChange(volume.pos / volume.max));
		focus.registerEvent(MouseEvent.CLICK, (_)->onFocusClick());
	}
	
	@:bind(mute, MouseEvent.CLICK)
	function onToggleVolumeClick(e)
	{
		if (mute.text == "Mute")
		{
			mute.text = "Unmute";
			volume.pos = 0;
		}
		else
		{
			mute.text = "Mute";
			volume.pos = volume.max;
		}
	}
}