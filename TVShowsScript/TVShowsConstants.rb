# This file is part of the TVShows source code.
# http://tvshows.sourceforge.net
# It may be used under the terms of the GNU General Public License.

PREFS_IS_ENABLED					= "IsEnabled"
PREFS_AUTOMATICALLY_OPEN_TORRENT	= "AutomaticallyOpenTorrent"
PREFS_TORRENT_FOLDER				= "TorrentFolder"
PREFS_QUALITY						= "Quality"
PREFS_SCRIPTVERSION					= "ScriptVersion"
PREFS_LASTVERSIONCHECK				= "SULastCheckTime"

TYPE_SEASONEPISODE					= "SeasonEpisodeType"	# Shows organised by season/episode (eg: Lost)
TYPE_DATE							= "DateType"			# Shows organised by date (eg: The Daily Show)
TYPE_TIME							= "TimeType"			# Shows not organised at all (eg: Dicovery Channel), so we organize them by published time
                            		
SHOWS_SHOWS							= "Shows"
SHOWS_VERSION						= "Version"
SHOW_HUMANNAME						= "HumanName"
SHOW_EXACTNAME						= "ExactName"
SHOW_EPISODE						= "Episode"
SHOW_SEASON							= "Season"
SHOW_SUBSCRIBED						= "Subscribed"
SHOW_DATE							= "Date"
SHOW_TITLE							= "Title"
SHOW_TYPE							= "Type"
SHOW_TIME							= "Time"

FEED = "http://tvrss.net/search/index.php?show_name=%s&show_name_exact=true&mode=rss"
REQUIRED_KEYS = [SHOW_HUMANNAME,SHOW_EXACTNAME,SHOW_SUBSCRIBED,SHOW_TYPE]
QUALITIES = [
	[/\[HD/,/\[DSRIP/,/\[TVRIP/,/\[PDTV/,/\[DVD/],
	[/\[HR/],
	[/\[720p/i]
]

VERSIONCHECK_VERSIONPLIST = "/System/Library/CoreServices/SystemVersion.plist"
#VERSIONCHECK_URL = "http://tvshows.sourceforge.net/checkforupdate.php?v=%s&macosx=%s"
VERSIONCHECK_URL = "http://tvshows.sourceforge.net/appcast.xml"