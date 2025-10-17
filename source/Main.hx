package;

import flixel.FlxGame;
import haxe.ui.Toolkit;

class Main extends openfl.display.Sprite
{
	public function new()
	{
		super();
		
		final toolkit = haxe.ui.Toolkit;
		toolkit.init();
		toolkit.theme = "dark";
		toolkit.scaleX = toolkit.scaleY = 1;
		
		addChild(new FlxGame(0, 0, states.ListState));
		// addChild(new FlxGame(0, 0, states.BrowseState));
	}
}
