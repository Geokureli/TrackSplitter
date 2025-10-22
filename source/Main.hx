package;

import data.SongData;
import flixel.FlxG;
import haxe.ui.HaxeUIApp;
import haxe.ui.events.MouseEvent;
import ui.ListView;
import ui.PlayView;

class Main extends openfl.display.Sprite
{
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
        app.ready(function() {
            // app.addComponent(new ui.BrowseView());
			createList(app);

            app.start();
        });
	}
	
	function createList(app:HaxeUIApp, ?song)
	{
		final listView = new ListView(song);
		listView.confirmTrackBtn.registerEvent(MouseEvent.CLICK, function (e)
		{
			final song = listView.selectedSong;
			app.removeComponent(listView);
			createPlay(app, song);
		});
		app.addComponent(listView);
	}
	
	function createPlay(app:HaxeUIApp, song:SongData)
	{
		final playView = new PlayView(song);
		playView.backBtn.registerEvent(MouseEvent.CLICK, function (e)
		{
			app.removeComponent(playView);
			createList(app, song);
		});
		app.addComponent(playView);
	}
}