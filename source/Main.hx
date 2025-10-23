package;

import data.SongData;
import flixel.FlxG;
import haxe.ui.HaxeUIApp;
import haxe.ui.events.MouseEvent;
import ui.ListView;
import ui.PlayView;

class Main extends openfl.display.Sprite
{
	var listView:ListView;
	public function new()
	{
		super();
		
		final toolkit = haxe.ui.Toolkit;
		toolkit.init();
		toolkit.theme = "dark";
		toolkit.scaleX = toolkit.scaleY = 1;
		
		addChild(new flixel.FlxGame());
		FlxG.mouse.useSystemCursor = true;
		FlxG.autoPause = false;
		
		var app = new HaxeUIApp();
		
        app.ready(function()
		{
			listView = new ListView();
			listView.confirmTrackBtn.registerEvent(MouseEvent.CLICK, function (e)
			{
				final song = listView.selectedSong;
				listView.hide();
				createPlay(app, song);
			});
			app.addComponent(listView);

			app.start();
		});
	}
	
	function createPlay(app:HaxeUIApp, song:SongData)
	{
		final playView = new PlayView(song);
		playView.backBtn.registerEvent(MouseEvent.CLICK, function (e)
		{
			app.removeComponent(playView);
			listView.show();
		});
		app.addComponent(playView);
	}
}