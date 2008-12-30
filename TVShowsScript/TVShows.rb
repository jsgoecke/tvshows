#!/usr/bin/env ruby

# This file is part of the TVShows source code.
# http://tvshows.sourceforge.net
# It may be used under the terms of the GNU General Public License.

# Required files
requires = [
	'set',
	'open-uri',
	'socket',
	File.join(File.dirname(__FILE__), 'TVShowsConstants.rb'),
	File.join(File.dirname(__FILE__), 'lib/simple-rss.rb'),
	File.join(File.dirname(__FILE__), 'lib/plist.rb')
]

# Helper functions
def die(message)
	$stderr.puts "TVShows Error: #{message}"
	exit(-1)
end
def printError(message)
	$stderr.puts "TVShows Error: #{message}"
end
def printException(exception)
	$stderr.puts "TVShows Error: #{exception.inspect}\n\t#{exception.backtrace.join("\n\t")}"
end

# Load required files
requires.each { |r|
	begin
		die("could not load #{r}") unless require r
	rescue => e
		printException(e)
	end
}


# The parent class for any episode object
# Note that you must subclass it to make it usefull
class Episode
	
	attr_reader :publishedTime
	
	def initialize(show,torrentURL,publishedTime)
		@show = show
		@torrentURL = torrentURL
		@publishedTime = publishedTime
	end
	
	def download
		path = File.join(@show.preferences[PREFS_TORRENT_FOLDER],torrentFile)
		file = File.new(path,'w')
		open(@torrentURL) { |data| file.write(data.read) }
		file.close
		`open \"#{path}\"` if ( @show.preferences[PREFS_AUTOMATICALLY_OPEN_TORRENT] )
		return true
	rescue => e
		printException(e)
		return false
	end
	
end


# Represents an episode classified by a season number and an episode number
# For example, "Lost"
class EpisodeWithSeasonAndEpisode < Episode
	
	attr_reader :season, :episode, :quality
	
	def initialize(show,torrentURL,publishedTime,season,episode,quality)
		super(show,torrentURL,publishedTime)
		@season = season
		@episode = episode
		@quality = quality
	end
	
	def torrentFile
		name = @show.humanName.gsub("/"," ").gsub(":"," ").gsub("."," ")
		return "#{name} #{'%02d' % @season.to_s}x#{'%02d' % @episode.to_s}.torrent"
	end
	
	def inspect
		"[Season #{@season},Episode #{@episode},Quality #{@quality}]"
	end
	
end 


# Represents an episode classified by a date
# For example, "The Daily Show"
class EpisodeWithDate < Episode
	
	attr_reader :date, :quality
	
	def initialize(show,torrentURL,publishedTime,date,quality)
		super(show,torrentURL,publishedTime)
		@date = date
		@quality = quality
	end
	
	def torrentFile
		name = @show.humanName.gsub("/"," ").gsub(":"," ").gsub("."," ")
		return "#{name} #{@date.strftime('%Y-%m-%d')}.torrent"
	end
	
end


# Represents an episode with no classification
# For example "Discovery Channel"
class EpisodeWithTitle < Episode
	
	attr_reader :title
	
	def initialize(show,torrentURL,publishedTime,title)
		super(show,torrentURL,publishedTime)
		@title = title
	end
	
	def torrentFile
		name = @show.humanName.gsub("/"," ").gsub(":"," ").gsub("."," ")
		title = @title.gsub("/"," ").gsub(":"," ").gsub("."," ")
		return "#{name} #{@title}.torrent"
	end
end


# Represents a show
# For example "Friends"
class Show
	
	attr_reader :exactName, :humanName, :preferences

	def initialize(params,preferences)
		@params = params
		@preferences = preferences
		@type = params[SHOW_TYPE]
		@exactName = params[SHOW_EXACTNAME]
		@humanName = params[SHOW_HUMANNAME]
	
		case @type
		when TYPE_SEASONEPISODE
			@season = params[SHOW_SEASON]
			@episode = params[SHOW_EPISODE]
		when TYPE_DATE
			@date = params[SHOW_DATE]
		when TYPE_TIME
			@time = params[SHOW_TIME]
		end		
	end

	def getNewEpisodes
		begin
			case @type
			when TYPE_SEASONEPISODE
				@params[SHOW_SEASON], @params[SHOW_EPISODE] = getNewEpisodesWithKey([@season,@episode]){ |ep| [ep.season,ep.episode] }
			when TYPE_DATE
				@params[SHOW_DATE] = getNewEpisodesWithKey(@date){ |ep| ep.date }
			when TYPE_TIME
				@params[SHOW_TIME] = getNewEpisodesWithKey(@time){ |ep| ep.publishedTime }
			end
		rescue => e
			printException(e)
		end
		return @params
	end

	def parseRSSFeed
		begin
			rawEpisodes = SimpleRSS.parse(open(FEED % @exactName,"User-Agent"=>"TVShows/#{@preferences['PREFS_SCRIPTVERSION']}"))
		rescue SocketError => e
			printError "(SocketError, #{e.inspect}) unable to contact tvrss.net, are you connected to the internet?"
			return nil
		rescue Exception => e
			printError "(Exception, #{e.inspect}) unable to parse RSS feed, skipping."
			return nil
		end
		flatEpisodes = []
		
		case @type
		when TYPE_SEASONEPISODE
			rawEpisodes.items.each do |episode|
				seasonNoMatch = /Season\s*:\ ([0-9]*?);/.match(episode.description)
				episodeNoMatch = /Episode\s*:\ ([0-9]*?)$/.match(episode.description)
				if ( seasonNoMatch.nil? or episodeNoMatch.nil? ) then
					printError "unable to match season and/or episode for #{episode.description}"
				else
					quality = 0
					catch (:found) do
						QUALITIES.reverse.each_with_index { |regexes,i|
							i = QUALITIES.length - i - 1
							regexes.each { |regex|
								if ( !(regex =~ episode.title).nil? ) then
									quality = i
									throw :found
								end
							}
						}
					end
					flatEpisodes << EpisodeWithSeasonAndEpisode.new(
						self,
						episode.link,
						episode.pubDate,
						seasonNoMatch[1].to_i,
						episodeNoMatch[1].to_i,
						quality
					)
				end
			end
		when TYPE_DATE
			rawEpisodes.items.each do |episode|
				dateMatch = /Episode\s*Date:\s*([0-9\-]+)$/.match(episode.description)
				if ( dateMatch.nil? ) then
					printError "unable to match date for #{episode.description}"
				else
					quality = 0
					catch (:found) do
						QUALITIES.reverse.each_with_index { |regexes,i|
							i = QUALITIES.length - i - 1
							regexes.each { |regex|
								if ( !(regex =~ episode.title).nil? ) then
									quality = i
									throw :found
								end
							}
						}
					end
					flatEpisodes << EpisodeWithDate.new(
						self,
						episode.link,
						episode.pubDate,
						Time.parse(dateMatch[1]),
						quality
					)
				end
			end
		when TYPE_TIME
			rawEpisodes.items.each do |episode|
				titleMatch = /Show\s*Title\s*:\s*(.*?);/.match(episode.description)
				if ( titleMatch.nil? ) then
					printError "unable to match title for #{episode.description}"
					title = ""
				else
					title = titleMatch[1]
				end	

				flatEpisodes << EpisodeWithTitle.new(
					self,
					episode.link,
					episode.pubDate,
					title
				)
			end
		end
		
		return flatEpisodes
	end

	def getNewEpisodesWithKey(minKey)

		downloadedEpisodeKeys = []

		# Stupid DateTime class !
		if ( minKey.instance_of?(DateTime) ) then
			minKey = Time.parse(minKey.to_s)
		end

		# Flat list of all the episodes listed in the RSS feed
		flatEpisodes = parseRSSFeed
		return minKey if flatEpisodes.nil?

		# What's the best quality available for the last 7 episodes ?
		bestQuality = flatEpisodes.sort_by{|ep| ep.publishedTime}.last(7).max{|a,b| a.quality <=> b.quality}.quality
		wantedQuality = [bestQuality,@preferences[PREFS_QUALITY]].min
		@qualityDelay = 6*3600*wantedQuality

		# Group episodes by key
		groupedEpisodes = flatEpisodes.to_set.classify{ |ep| yield(ep) } #[ep.season,ep.episode]
		
		# Get the unseen episodes only		
		newEpisodes = groupedEpisodes.reject{ |k,v| (k <=> minKey) <= 0 } # ie, k <= minKey

		# First try : download the episodes for which we have the wanted quality
		newEpisodes.each_pair{ |k,episodes|	
			if ( episode = episodes.find{ |ep| ep.quality == wantedQuality } ) then
				if ( episode.download ) then
					downloadedEpisodeKeys << k
				end
			end
		}

		# Second try : download the episodes for which the quality delay has expired, with the best guess for quality
		newEpisodes.each_pair{ |k,episodes|
			if ( !downloadedEpisodeKeys.include?(k) ) then
				minPublishedTime = episodes.min{ |ep1,ep2| ep1.publishedTime <=> ep2.publishedTime }.publishedTime
				if ( (Time.now-minPublishedTime) > @qualityDelay ) then
					
					# Try to best match the wanted quality
					episode = episodes.reject{ |ep| ep.quality > wantedQuality }.sort_by{ |ep| ep.quality }.last
					episode = episodes.sort_by{ |ep| ep.quality }.first if ( episodes.nil? ) 
					
					if ( !episode.nil? ) then
						if ( episode.download ) then
							downloadedEpisodeKeys << k
						end
					end
					
				end
			end
		}

		if downloadedEpisodeKeys.length > 0 then
			return downloadedEpisodeKeys.sort.last
		end
		return minKey

	end
	
end


# The main class
class TVShows
	
	def initialize(preferencesFile,showsFile)
		die("can't reach tvrss.net, are you connected to the internet?") unless isConnectedToTheInternet
		
		@showsFile = showsFile
		@preferencesFile = preferencesFile
		
		# Make sure these file exist
		die("Could not find \"#{preferencesFile}\"") unless ( File.exists?(preferencesFile) )
		die("Could not find \"#{showsFile}\"") unless ( File.exists?(showsFile) ) 

		# Convert from binary to xml
		`plutil -convert xml1 \"#{preferencesFile}\"`
		`plutil -convert xml1 \"#{showsFile}\"`
		
		# Parse
		@preferences = Plist::parse_xml(preferencesFile)
		@showsplist = Plist::parse_xml(showsFile)
		@shows = @showsplist[SHOWS_SHOWS]
		die("Could not parse \"#{preferencesFile}\"") if ( @preferences.nil? )
		die("Could not parse \"#{showsFile}\"") if ( @shows.nil? )
		
		# Stop now if disabled (should not happen)
		die("TVShows is disabled.") if ( !@preferences[PREFS_IS_ENABLED] )
		
		# Torrent download folder
		@preferences[PREFS_TORRENT_FOLDER] = File.expand_path(@preferences[PREFS_TORRENT_FOLDER])
		die("Non-existent folder \"#{@preferences[PREFS_TORRENT_FOLDER]}\"") unless ( File.exists?(@preferences[PREFS_TORRENT_FOLDER]) )
		
		# Maintenance
		deleteLogFile(File.dirname(showsFile))
		checkForUpdates
	end
	
	def isConnectedToTheInternet
		3.times {
			return true if ( ping )
			sleep(5)
		}
		return false
	end
	
	def ping
		TCPSocket.new("www.tvrss.net",80)
		return true
	rescue Exception => e
		return false
	end
	
	def deleteLogFile(root)
		logFile = File.join(root, 'TVShows.log')
		if ( File.exists?(logFile) and File.size(logFile) > 524288 ) then
			File.delete(logFile)
			FileUtils.touch(logFile)
		end
	end
	
	def checkForUpdates
		
		if ( !@preferences[PREFS_LASTVERSIONCHECK] ) then
			@preferences[PREFS_LASTVERSIONCHECK] = Time.new
			savePrefs
		end
		
		if ( @preferences[PREFS_LASTVERSIONCHECK].instance_of?(DateTime) )
			@preferences[PREFS_LASTVERSIONCHECK] = Time.parse(@preferences[PREFS_LASTVERSIONCHECK].to_s)
		end
		
		# Check for update every week
		if ( (Time.new - @preferences[PREFS_LASTVERSIONCHECK]) > 3600*24*7 ) then
			@preferences[PREFS_LASTVERSIONCHECK] = Time.new
			savePrefs
			begin
				require "rexml/document"
				if ( REXML::Document.new(open(VERSIONCHECK_URL)).elements.to_a("rss/channel/item/enclosure").first.attributes["sparkle:version"] > @preferences[PREFS_SCRIPTVERSION] ) then
					`open -a TVShows`
					exit(0)
				end
			rescue => e
			end
		end

	end
	
	def savePrefs
		@preferences.save_plist(@preferencesFile)
	end
	
	def getNewEpisodes
		@shows.each_with_index { |params,i|
			begin
				if ( params.has_key?(SHOW_SUBSCRIBED) and params[SHOW_SUBSCRIBED] ) then
					@shows[i] = Show.new(params,@preferences).getNewEpisodes
				end
			rescue => e
				printError("Error with %s, skipping." % params[SHOW_HUMANNAME])
				printException(e)
			end
		}
		@showsplist[SHOWS_SHOWS] = @shows
		@showsplist.save_plist(@showsFile)
	end
	
end

if ( ARGV.length != 2 ) then
	ARGV[0] = File.expand_path("~/Library/Preferences/net.sourceforge.tvshows.plist")
	ARGV[1] = File.expand_path("~/Library/Application Support/TVShows/TVShows.plist")
end

TVShows.new(ARGV[0],ARGV[1]).getNewEpisodes

# launchd requires us to be alive for at least 10 seconds
sleep(10)

exit(0)
