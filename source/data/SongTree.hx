package data;


@:using(data.SongTree.SortUtils)
enum SongTree
{
	Branch(name:String, members:Array<SongTree>);
	Leaf(data:SongData, value:String);
}

@:using(data.SongTree.SortUtils)
enum abstract SortName(String)
{
	var Artist = "Artist";
	var Title = "Title";
	var Album = "Album";
	var Artist_Album = "Artist/Album";
	var Year = "Year";
	var Genre = "Genre";
}

@:using(data.SongTree.SortUtils)
enum abstract SortGroup(String)
{
	var ARTIST_INITIAL = "artist_initial";
	var TITLE_INITIAL = "title_initial";
	var ALBUM_INITIAL = "album_initial";
	var ARTIST = "artist";
	var TITLE = "title";
	var ALBUM = "album";
	var YEAR = "year";
	var DECADE = "decade";
	var GENRE = "genre";
}

class SortUtils
{
	static public function createTree(sorter:SortName, library:Array<SongData>)
	{
		final sortGroups = getSortGroups(sorter);
		
		final tree = new Array<SongTree>();
		
		function getGroupBranch(song:SongData)
		{
			var parentGroup:Array<SongTree> = tree;
			for (i=>sorter in sortGroups)
			{
				final value = getSortGroupValue(sorter, song);
				
				if (value == null || value == "")
					return null;
				
				var parent:Array<SongTree> = null;
				for (item in parentGroup)
				{
					switch item
					{
						case Leaf(_, _): throw "Sorting error: expected Branch, found Leaf";
						case Branch(name, subMembers):
							
							if (name.toUpperCase() == value.toUpperCase())
							{
								parent = subMembers;
								break;
							}
					}
					
				}
				
				if (parent == null)
				{
					parent = [];
					parentGroup.push(Branch(value, parent));
				}
					
				parentGroup = parent;
			}
			
			return parentGroup;
		}
		
		for (song in library)
		{
			final groupNode = getGroupBranch(song);
			if (groupNode == null)
				continue;
			
			groupNode.push(Leaf(song, sorter.getSortValue(song)));
		}
		
		sortMembers(tree);
		
		return tree;
	}
	
	static public function findSongNode(tree:Array<SongTree>, song:SongData, sortName:SortName):Null<SongTree>
	{
		final sortGroups = getSortGroups(sortName);
		var branch = tree;
		for (sorter in sortGroups)
		{
			final value = getSortGroupValue(sorter, song).toUpperCase();
			var nextBranch = null;
			for (member in branch)
			{
				switch member
				{
					case Leaf(_, _):
					case Branch(name, members):
						if (name.toUpperCase() == value)
						{
							nextBranch = members;
							break;
						}
				}
			}
			
			if (nextBranch == null)
				return null;
			
			branch = nextBranch;
		}
		
		for (member in branch)
		{
			switch member
			{
				case Branch(_, _):
				case Leaf(leafSong, _):
					if (song == leafSong)
						return member;
			}
		}
		
		return null;
	}
	
	static public function findSongPath(tree:Array<SongTree>, song:SongData, sortName:SortName):Null<Array<String>>
	{
		final path = new Array<String>();
		final sortGroups = getSortGroups(sortName);
		var branch = tree;
		for (sorter in sortGroups)
		{
			final value = getSortGroupValue(sorter, song).toUpperCase();
			var nextBranch = null;
			for (member in branch)
			{
				switch member
				{
					case Leaf(_, _):
					case Branch(name, members):
						if (name.toUpperCase() == value)
						{
							path.push(name);
							nextBranch = members;
							break;
						}
				}
			}
			
			if (nextBranch == null)
				return null;
			
			branch = nextBranch;
		}
		return path;
	}
	
	static public function getSortGroups(sorter:SortName)
	{
		return switch sorter
		{
			case Artist: [ARTIST_INITIAL, ARTIST];
			case Title: [TITLE_INITIAL];
			case Year: [DECADE, YEAR];
			case Album: [ALBUM_INITIAL, ALBUM];
			case Artist_Album: [ARTIST_INITIAL, ARTIST, ALBUM];
			case Genre: [GENRE];
			case unexpected: throw 'Unexpected sorter: $unexpected';
		}
	}
	
	static public function getSortValue(sorter:SortName, song:SongData)
	{
		return getSortGroupValue(getSortGroups(sorter).pop(), song);
	}
	
	static public function getArtistNameSorter(artist:String)
	{
		if (artist.toUpperCase().indexOf("THE ") == 0)
			return artist.substr(4);
		
		return artist;
	}
	
	static final dateReg = ~/(?:19|20)\d{2}/;
	static public function getYearSorter(date:String)
	{
		if (false == dateReg.match(date))
			return "";
		
		return dateReg.matched(0);
	}
	
	static public function getDecadeSorter(date:String)
	{
		final year = getYearSorter(date);
		if (year == "" || year == null)
			return year;
		
		return '${Math.floor(Std.parseInt(year) / 10) * 10}';
	}
	
	static public function getSortGroupValue(sorter:SortGroup, song:SongData)
	{
		return switch sorter
		{
			case ARTIST_INITIAL: getArtistNameSorter(song.data.artist).charAt(0);
			case TITLE_INITIAL : song.data.name.charAt(0);
			case ALBUM_INITIAL : song.data.album.charAt(0);
			case ARTIST: song.data.artist;
			case TITLE : song.data.name;
			case ALBUM : song.data.album;
			case DECADE: getDecadeSorter(song.data.year);
			case YEAR  : '${getYearSorter(song.data.year)}';
			case GENRE : song.data.genre;
		}
	}
	
	static public function sort(tree:SongTree)
	{
		switch tree
		{
			case Leaf(_, members):
			case Branch(_, members):
				sortMembers(members);
		}
	}
	
	static public function sortMembers(members:Array<SongTree>)
	{
		members.sort(treeSorter);
		for (member in members)
		{
			switch member
			{
				case Leaf(_, members):
				case Branch(_, members):
					sortMembers(members);
			}
		}
	}
	
	static public function treeSorter(a:SongTree, b:SongTree)
	{
		function compareString(a:String, b:String)
		{
			final aUp = getArtistNameSorter(a).toUpperCase();
			final bUp = getArtistNameSorter(b).toUpperCase();
			if (aUp > bUp)
				return 1;
			if (aUp < bUp)
				return -1;
			return 0;
		}
		
		return switch [a, b]
		{
			case [Branch(valueA, _), Branch(valueB, _)]: compareString(valueA, valueB);
			case [Leaf  (_, valueA), Branch(valueB, _)]: compareString(valueA, valueB);
			case [Branch(valueA, _), Leaf  (_, valueB)]: compareString(valueA, valueB);
			case [Leaf  (songA, valueA), Leaf  (songB, valueB)]: 
				final sort = compareString(valueA, valueB);
				if (sort != 0)
					return sort;
				
				return compareString(songA.data.name, songB.data.name);
		}
	}
}