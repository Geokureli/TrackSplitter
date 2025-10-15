package;

import flixel.FlxGame;

class Main extends openfl.display.Sprite
{
	public function new()
	{
		super();
		// addChild(new FlxGame(0, 0, states.ListState));
		addChild(new FlxGame(0, 0, states.BrowseState));
	}
}
