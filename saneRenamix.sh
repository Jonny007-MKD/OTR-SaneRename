#!/bin/bash

### Exit codes:
# 1  : General error (invalid argument option, missing parameter)
# 2  : Specified language not recognized
# 3  : Aborted (Ctrl+C)
# 10 : Series not found in TvDB
# 11 : Series not found in EPG
# 12 : Several possible series found
# 20 : No info for this episode found
# 21 : No episode title found in EPG
# 40 : Downloading EPG data failed
# 41 : Downloading list of episodes from TvDB failed


### What this program does
# Analyze the file name
# Ask TvDB or cache for the ID of the series
# Get EPG from OTR
# Search the episode title in EPG
# Get a list of all episodes from TvDB
# Search the episode in this list
# Print file name with episode and series number

##########
# Config #
##########
apikey="2C9BB45EFB08AD3B"
productname="SaneRename for OTR (ALPHA) v0.4"
lang="de"
debug=false


##########
# Script #
##########

# Print only of not silent
function eecho {
	if [ -z "$silent" ]; then
		echo "$1" "$2" "$3"
	fi
}

function logNexit {
	str="$1 - $file_name - $series_title"
	if [ -f "$PwD/log" ] && ! grep -q "$str" "$PwD/log" ; then
		echo "$str" >> "$PwD/log"
	fi
	exit $1
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    if $wget_running; then
		rm -f $wget_file
	fi
    exit 3
}
wget_running=false;

# Parse the parameters
function funcParam {
	while getopts "df:l:s" optval; do
		case $optval in
			"d")					# Enable debugging
				debug=true;;
			"f")					# Path to file
				path="$OPTARG";;
			"s")					# Silent switch
				silent=1;;
			"l")					# Language
				case "$OPTARG" in
					de*)
						lang="de";;
					en*)
						lang="en";;
					us*)
						lang="en";;
					fr*)
						lang="fr";;
					*)
						echo "Language not recognized: $OPTARG"
						exit 2;;
				esac;;
			"?")					# Help
				echo "Usage: $0 -f pathToAvi [-s] [-l LANG]"
				exit;;
			":")
				echo "No argument value for option $OPTARG"
				exit 1;;
		esac
	done
}

# Print the header
function funcHeader {
	eecho " :: $productname"
	eecho " :: by Leroy Foerster & Jonny007-MKD"
	eecho
}

# Get title, date and time
function funcAnalyzeFilename {
	if $debug; then echo -e "\033[36mfuncAnalyzeFilename\033[37m"; fi;
	local tmp;

	# Remove series and episode information
	if [[ "$file_name" == S[0-9][0-9]_E[0-9][0-9]_* ]]; then			# S00_E00_Series_
		episode_season="${file_name:1:2}"		   # Retreive information
		episode_number="${file_name:5:2}"
		episode_season=${episode_season#0}		   # Remove leading 0
		episode_number=${episode_number#0}
		file_name="${file_name:8}"
	fi

	# Split filename into words, divided by _ (underscores)
	file="${file_name//_/ }"

	file_suffix="${file_name##*.}"							# Get file suffix
	tmp="${file_name//.$file_suffix}"
	case "${tmp##*.}" in									# Prepend special suffixes
		HQ|HD)
			file_suffix="${tmp##*.}.$file_suffix";;
	esac

	firstField="${file%% *}"								# Get the first word
	test $firstField -eq 0 2>/dev/null						# If first word is a number -> cutlist id
	if [ $? -ne 2 ]; then
		file=${file##$firstField }							# remove it
	fi

	file_title=${file%% [0-9][0-9].*}						# Cut off everything after the title: date, hour, sender, ...
	file_sender=${file##*-[0-9][0-9]}						# Cut off everything bevor the sender: title, date, time, ...

	if [[ "$file_title" == *S[0-9][0-9]E[0-9][0-9] ]]; then				# Series_S00E00_
		episode_season="${file_title:(-5):2}"	   # Retreive information
		episode_number="${file_title:(-2):2}"
		episode_season=${episode_season#0}		   # Remove leading 0
		episode_number=${episode_number#0}
		file_title="${file_title:0:-7}"
	fi

	file_date=${file%%$file_sender}							# Cut off the sender
	file_date=${file_date##$file_title }					# Cut off the title, now we do have the date and time
	file_time=${file_date##* }
	file_date=${file_date%% *}

	file_dateInv=$(date +%d.%m.%Y --date="${file_date//./-}")	# Convert YY.MM.DD to DD.MM.YY
	file_time=${file_time/-/:}									# Convert HH-MM to HH:MM
	
	eecho -e "    Work dir:\t$PwD"
	eecho -e "    Datum:\t$file_dateInv"
	eecho -e "    Uhrzeit:\t$file_time"

	funcConvertName "$file_title"
	eecho -e "    Titel:\t$tmp"
}

function funcConvertName {
	if $debug; then echo -e "\033[36mfuncConvertName $1\033[37m"; fi;
	tmp="$1"
	tmp=${tmp// s /\'s }							# Replace a single s with 's
	if [ "$langCurrent" == "de" ]; then
		tmp=${tmp//Ae/Ä}							# Replace umlauts
		tmp=${tmp//Oe/Ö}
		tmp=${tmp//Ue/Ü}
		tmp=${tmp//ae/ä}
		tmp=${tmp//oe/ö}
		tmp=${tmp//ue/ü}
	fi
}

# Get the series ID from TvDB (needed to fetch episodes from TvDB)
function funcGetSeriesId {
	if $debug; then echo -e "\033[36mfuncGetSeriesId\033[37m"; fi;
	local tmp;
	if [ -f "$PwD/series.cache" ]; then								# Search the series cache
		funcGetSeriesIdFromCache "$file_title"
		if [ -z "$series_id" ]; then								# and search the cache with translation
			funcConvertName "$file_title"
			funcGetSeriesIdFromCache "$tmp"
		fi
	fi
	if [ -z "$series_id" ]; then									# Otherwise ask TvDB whether they do know the series
		funcGetSeriesIdFromTvdb "$file_title"
	fi
	if [ -z "$series_id" ]; then									# Otherwise ask TvDB with translation
		funcConvertName "$file_title"
		funcGetSeriesIdFromTvdb "$tmp"
	fi
	if [ -z "$series_id" ]; then									# This series was not found anywhere :(
		eecho -e "    TVDB:\tSeries not found!"
		logNexit 10
	fi

	if [ -n "$series_alias" ]; then
		eecho -e "\t\t\t\tAlias: $series_alias"
	fi
}

# Search the series.cache file for this series and get TvDB series id
function funcGetSeriesIdFromCache {
	if $debug; then echo -e "\033[36mfuncGetSeriesIdFromCache $1\033[37m"; fi;
	local title;
	local tmp;
	title="$1";
	while true; do
		series_id="$(grep "$title|" "$PwD/series.cache")"				# Search for this title in the cache
		if [ -n "$series_id" ]; then									# Stop if we have found something
			series_title_file="${series_id%|_|*}"
			series_title_tvdb="${series_id#*|_|}"
			series_title_tvdb="${series_title_tvdb%|#|*}"
			series_id="${series_id##*|#|}"
			eecho -e "    Cache:\tSeries found.\tID:\t$series_id"
			eecho -e "          \t             \tName:\t$series_title_tvdb"
			break;
		fi
		tmp="${title% *}"												# Shorten the title by one word
		if [ ${#tmp} -le 4 ] || [ "$tmp" == "$title" ]; then			# Too short or was not shortened
			break;
		fi
		title="$(echo $tmp | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"
	done
}

# Search the TvDB for this series and get TvDB series id
function funcGetSeriesIdFromTvdb {
	if $debug; then echo -e "\033[36mfuncGetSeriesIdFromTvdb $1\033[37m"; fi;
	local title;
	local tmp;
	local shorten;
	title="$1";
	shorten=false;

	while true; do
		series_db="https://www.thetvdb.com/api/GetSeries.php?seriesname=${title}&language=$lang"
		wget_file="$PwD/series.xml"
		wget_running=true;
		if $debug; then echo -e "\033[36mwget \"$series_db\" -O \"$wget_file\"\033[37m"; fi;
		wget "$series_db" -O "$wget_file" -o /dev/null
		error=$?
		wget_running=false;
		if [ $error -ne 0 ]; then
			eecho -e "\t\t\tDownloading $series_db failed \(Exit code: $error\)!"
		fi


		tmp="$(grep -i -m 1 -B 3 -A 1 ">$title<" "$wget_file")"
		if [ ${#tmp} -eq 0 ]; then										# No series with this name found
			tmp="$(grep -Pzo "(?s)>langCurrent</language>\n<SeriesName>" "$wget_file")"						# Let's get all series from the query
			if [ $(echo "$tmp" | wc -l) -eq 1 ]; then					# If we only found one series
				tmp="$(grep -Pzo "(?s)<Series>.*?$langCurrent</language>.*?</SeriesName>" "$wget_file")"	# Lets use this one
			else
				eecho -e "    TvDB: $(echo "$tmp" | wc -l) series found with this title ($title)"
				logNexit 12
			fi
		fi
		if [ -n "$tmp" ]; then
			series_id=$(echo "$tmp" | grep "seriesid>")
			series_title_file="$file_title"
			series_title_tvdb=$(echo "$tmp" | grep "SeriesName>")		# Get series name from TvDB
			series_alias=$(echo "$tmp" | grep "AliasNames>")
			series_id=${series_id%<*}									# Remove XML tags
			series_id=${series_id#*>}
			series_title_tvdb=${series_title_tvdb%<*}
			series_title_tvdb=${series_title_tvdb#*>}
			series_alias=${series_alias%<*}
			series_alias=${series_alias#*>}

			echo "$file_title|_|$series_title_tvdb|#|$series_id" >> "$PwD/series.cache"
			eecho -e "    TVDB:\tSeries found.\tID:    $series_id"
			eecho -e "         \t             \tName:  $series_title_tvdb"
			break
		fi

		if $shorten; then
			title="${title//\*/ }"											# Remove wildcards from current run
			tmp="${title% *}"												# Shorten the title by one word
			if [ ${#tmp} -le 4 ] || [ "$tmp" == "$title" ]; then			# Too short or was not shortened
				break;
			fi
			title="$(echo $tmp | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"
			shorten=false;
		else
			title="${title// /*}"											# Replace spaces with wildcards
			shorten=true;
		fi
	done
}

# Get the EPG from OnlineTvRecorder and get the title of the episode
function funcGetEPG {
	if $debug; then echo -e "\033[36mfuncGetEPG\033[37m"; fi;
	# Download OTR EPG data and search for series and time
	wget_file="$PwD/epg-${file_date}.csv"
	if [ -f "$wget_file" ]; then
		wget_file_date=$(stat --format=%Y "$wget_file")
		if [ $(( $(date +%s) - $wget_file_date)) -gt $((60*60*24*7*2)) ]; then		# if file is older than 2 weeks
			#echo "Deleting file with timestamp $wget_file_date"
			rm "$wget_file"
		elif [ $(stat --format=%s "$wget_file") -eq 0 ]; then						# if file is empty
			#echo "Deleting file with size $(stat --format=%s $wget_file)"
			rm "$wget_file"
		fi
	fi
	if [ ! -f "$wget_file" ]; then										# This EPG file does not exist
		#rm -f ${PwD// /\\ }/epg-*.csv 2> /dev/null						# Delete all old files
		epg_csv="https://www.onlinetvrecorder.com/epg/csv/epg_20${file_date//./_}.csv"
		wget_running=true;
		if $debug; then echo -e "\033[36mwget \"$epg_csv\" -O \"$wget_file\"\033[37m"; fi;
		wget "$epg_csv" -O "$wget_file" -o /dev/null					# Download the csv
		error=$?
		wget_running=false;
		if [ $error -ne 0 ]; then
			eecho "Downloading $epg_csv failed (Exit code: $error)!"
			logNexit 40
		fi
		iconv -f LATIN1 -t utf8 "$wget_file" -o "${wget_file}.iconv"
		mv "${wget_file}.iconv" "$wget_file"
	fi

	epg="$(grep -i "$series_title_file" "$wget_file" | grep "${file_time}")"				# Get the line with the movie
	if [ -z "$epg" ]; then
		funcConvertName "$series_title_file"
		epg="$(grep -i "$tmp" "$wget_file" | grep "${file_time}")"							# Get the line with the movie
		if [ -z "$epg" ]; then
			epg="$(grep -i "$series_title_tvdb" "$wget_file" | grep "${file_time}")"		# Get the line with the movie
			if [ -z "$epg" ]; then
				eecho -e "    EPG:\tSeries \"$series_title_file\" not found in EPG data"	# This cannot happen :)
				logNexit 11
			fi
		fi
	fi
	# Parse EPG data using read
	OLDIFS=$IFS
	IFS=";"
	while read epg_id epg_start epg_end epg_duration epg_sender epg_title epg_type epg_text epg_genre epg_fsk epg_language epg_weekday epg_additional epg_rpt epg_downloadlink epg_infolink epg_programlink; do
		if [[ "$epg_start" == *$file_time* ]]; then						# Use the one with the correct start time
			break
		fi
	done <<< "$epg"
	IFS=$OLDIFS
}

# Get the title of the episode from description in EPG using $1 as delimiter to the real description
function funcGetEpisodeTitleFromEpg {
	if $debug; then echo -e "\033[36mfuncGetEpisodeTitleFromEpg \"$1\" \"$2\"\033[37m"; fi;
	local delimiter;
	local delimiter2;
	delimiter1="$1"
	delimiter2="$2"

	episode_title="${epg_text%%$delimiter1*}"							# Text begins with episode title, cut off the rest
	if [ -n "$delimiter2" ]; then
		episode_title="${episode_title##*$delimiter2}"					# Cut of anything before the second delimiter
	fi
	episode_title="$(echo ${episode_title} | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"
	episode_title="${episode_title#$series_title_file}"					# Get the title without the series title
	episode_title="$(echo ${episode_title#$series_title_tvdb} | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"	# Get the title without the series title
	if [ -z "$episode_title" ]; then
		eecho -e "    EPG:\tNo episode title found"
	else
		episode_title="$(echo $episode_title | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"
		eecho -e "    EPG:\tEpisode title:\t$episode_title"				# We found some title :)
	fi
}

# Download episodes list  from TvDB, language as argument
function funcDownloadEpisodesFile {
	if $debug; then echo -e "\033[36mfuncDownloadEpisodesFile\033[37m"; fi;
	wget_file="$PwD/episodes-${series_id}-${langCurrent}.xml"
	if [ -f "$wget_file" ]; then
		wget_file_date=$(stat --format=%Y "$wget_file")
		if [ $(( $(date +%s) - $wget_file_date)) -gt $(( 60*60*24*7*2 )) ]; then		# if file is older than 2 weeks
			rm "$wget_file"
		elif [ $(stat --format=%s "$wget_file") -eq 0 ]; then							# if file is empty
			rm "$wget_file"
		fi
	fi
	if [ ! -f "$wget_file" ]; then
		# Download Episode list of series
		episode_db="https://www.thetvdb.com/api/$apikey/series/$series_id/all/$langCurrent.xml"
		wget_running=true;
		if $debug; then echo -e "\033[36mwget \"$episode_db\" -O \"$wget_file\"\033[37m"; fi;
		wget $episode_db -O "$wget_file" -o /dev/null
		error=$?
		wget_running=false;
		if [ $error -ne 0 ]; then
			eecho "Downloading $episode_db failed (Exit code: $error)!"
			logNexit 41
		fi
	fi
}

# Get the information from episodes list of TvDB
function funcGetEpisodeInfoByTitle {
	if $debug; then echo -e "\033[36mfuncGetEpisodeInfoByTitle\033[37m"; fi;
	local i;
	local tmp;									# Some tmp variable
	local title;								# The current string of the title
	local title_not_converted;					# Whether the title was converted
	local remove_begin;							# How many words shall be removed from the beginnig
	title="$episode_title"														# Use coded version of episode title
	funcConvertName "$episode_title"
	if [ "$episode_title" != "$tmp" ]; then										# Save state to change to decoded version later
		title_not_converted=true;
	else
		title_not_converted=false;
	fi

	wget_file="$PwD/episodes-${series_id}-${langCurrent}.xml"

	while true; do								# Loop: Convert title
		for remove_begin in 1 2 3 4; do			# Loop: Remove up to 3 words from beginning
			while true; do						# Loop: Remove words from end
				eecho -e "        \tEpisode title:\t$title"
				episode_info=$(grep -i "sodeName>$title" "$wget_file" -B 10 | tail -11)	# Get XML data of episode
				if [ -z "$episode_info" ]; then											# Nothing found. Search the description
					if [ ${#title} -gt 10 ]; then										# If title is long enough
						episode_info=$(grep -i "verView>$title" "$wget_file" -B 16 | tail -17)
					fi
					if [ -n "$episode_info" ]; then										# We have found something!
						break;
					else																# Still nothing found. Shorten the title
						tmp=${title% *}
						if [ ${#tmp} -le 4 ] || [ "$tmp" == "$title" ]; then			# Stop when the title is to short
							break;
						fi
					fi
					title="$(echo $tmp | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"		# Remove special characters
				else
					break;
				fi
			done								# Loop: Remove words from end
			if [ -n "$episode_info" ]; then					# We have found something! :)
				break;
			fi

			title="$episode_title"
			for i in $(seq 1 $remove_begin); do											# Remove $remove_begin words from the beginning
				tmp="${title%% *}"														# Get the first word
				title="${title#$tmp }"													# Remove it from the title
			done
		done									# Loop: Remove words from beginning
			
		if [ -n "$episode_info" ]; then						# We have found something! :)
			break;
		fi
		if $title_not_converted; then						# We have not yet tried to convert the title
			funcConvertName "$episode_title"
			title_not_converted=false;
		else
			break;
		fi
	done										# Loop: Convert title

	funcGetEpisodeInfo_ParseData
}


function funcGetEpisodeInfoBySE {
	if $debug; then echo -e "\033[36mfuncGetEpisodeInfoBySE\033[37m"; fi;

	wget_file="$PwD/episodes-${series_id}-${langCurrent}.xml"

	episode_info=$(grep -i "bined_episodenumber>$episode_number" "$wget_file" -A 10 | grep -i "bined_season>$episode_season" -B 1 -A 9)		# Get XML data

	funcGetEpisodeInfo_ParseData
}


function funcGetEpisodeInfo_ParseData {
	if $debug; then echo -e "\033[36mfuncGetEpisodeInfo_ParseData\033[37m"; fi;

	if [ -n "$episode_info" ]; then												# If we have found something
		episode_number=$(echo -e "$episode_info" | grep -m 1 "Combined_episodenumber") # Get episode number
		episode_season=$(echo -e "$episode_info" | grep -m 1 "Combined_season")	# Get season number
		episode_title=$(echo -e "$episode_info" | grep -m 1 "EpisodeName")		# Get season name
		episode_number=${episode_number%<*}										# remove xml tags
		episode_number=${episode_number#*>}
		episode_season=${episode_season%<*}
		episode_season=${episode_season#*>}
		episode_title=${episode_title%<*}
		episode_title=${episode_title#*>}

		if [ -z "$episode_number" -o -z "$episode_season" ]; then				# If we have an illegal match (e.g. Series Overview)
			episode_info=														# Empty result
			episode_title=
		else
			if [[ "$episode_number" == *.* ]]; then								# Convert float to integer. Float!?
				episode_number=${episode_number%%.*}
			fi
			if [[ "$episode_season" == *.* ]]; then
				episode_season=${episode_number%%.*}
			fi

			if [ $episode_number -le 9 ]; then									# add leading zero
				episode_number="0$episode_number"
			fi
			if [ $episode_season -le 9 ]; then
				episode_season="0$episode_season"
			fi

			eecho -e "    TvDB:\tSeason: \t$episode_season"
			eecho -e "         \tEpisode:\t$episode_number"
		fi
	fi
}




function funcMakeFilename {
	if $debug; then echo -e "\033[36mfuncMakeFilename\033[37m"; fi;
	if [ "$lang" == "de" ]; then
		episode_title=${episode_title//Ä/Ae}				# Replace umlauts
		episode_title=${episode_title//Ö/Oe}
		episode_title=${episode_title//Ü/Ue}
		episode_title=${episode_title//ä/ae}
		episode_title=${episode_title//ö/oe}
		episode_title=${episode_title//ü/ue}
	fi
	echo "${series_title_tvdb// /.}..S${episode_season}E${episode_number}..${episode_title// /.}.$file_suffix"
}

# This function does everything
function doIt {
	funcHeader

	if [ -z "$path" ]; then									# If no path was specified (-f)
		echo "Usage: $0 -f pathToAvi [-s] [-l LANG]"
		exit 1
	fi

	PwD=$(readlink -e $0)									# Get the path to this script
	PwD=$(dirname "$PwD")
	langCurrent="$lang"

	file_name="$(basename $path)"							# Get file name
	file_dir="$(dirname $path)"								# Get file directory

	funcAnalyzeFilename										# Get info from $file_name
	funcGetSeriesId											# Get series ID from cache or TvDB

	if [ -n "$episode_season" -a -n "$episode_number" ]; then	# We already got info from filename
		funcGetEpisodeInfoBySE

	else														# We have to get info from EPG

		funcConvertName "$file_title"
		if [[ "$tmp" == $series_title_tvdb* ]] || [[ "$file_title" == $series_title_tvdb* ]] ||
		   [[ "$tmp" == $series_alias* ]]      || [[ "$file_title" == $series_alias* ]]          ; then
			if $debug; then echo -e "\033[36mParsing file name only! \"$tmp\" == \"$series_title_tvdb*\" || \"$file_title\" == \"$series_title_tvdb*\" || \"$tmp\" == \"$series_alias*\" ||  \"$file_title\" == \"$series_alias*\"\033[37m"; fi
			episode_title="$(echo ${file_title#$series_title_tvdb} | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"
			funcConvertName "$series_title_file"
			episode_title="$(echo ${episode_title#$tmp} | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"
			episode_title="$(echo ${episode_title#$series_title_tvdb} | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"
			episode_title="$(echo ${episode_title#$series_alias} | sed -e 's/^[^a-zA-Z0-9]*//' -e 's/ *$//')"
		fi
		if [ -n "$episode_title" ]; then
			eecho -e "    \t\tEpisode title:\t$episode_title"
			episode_title_set=true								# used in doItEpisodes (whether the episode title shall be search in epg)
		else													# Otherwise search the episode title in the EPG:
			funcGetEPG											# Download epg file
			episode_title_set=false
		fi

		langCurrent="$lang"
		doItEpisodes											# Search for the episode in the specified language
		if [ -z "$episode_info" ]; then							# Episode was not found!
			if [ "$lang" != "en" ]; then
				langCurrent="en"
				doItEpisodes									# Try it again with english
			fi
		fi

		if $episode_title_set && [ -z "$episode_info" ]; then	# Episode was not found!
			episode_title_set=false								# Do not use file name as episode title
			funcGetEPG											# Download epg file
			langCurrent="$lang"
			doItEpisodes										# Search for the episode in the specified language and get title from EPG
			if [ -z "$episode_info" ]; then						# Episode was not found!
				if [ "$lang" != "en" ]; then
					langCurrent="en"
					doItEpisodes								# Try it again with english
				fi
				if [ -z "$episode_info" ]; then					# Again/still no info found! Damn :(
					eecho "No episode info found!"
					logNexit 20
				fi
			fi
		fi
	fi
	
	if [ -n "$episode_info" ] && [ -n "$series_title_tvdb" ]; then
		funcMakeFilename
		exit 0
	fi
}

# Parse the episodes, language as argument
function doItEpisodes {
	if ! $episode_title_set; then
		funcGetEpisodeTitleFromEpg "."						# Get the episode title using . as delimiter
	fi
	funcDownloadEpisodesFile								# Download episodes file
	if [ -n "$episode_title" ]; then
		funcGetEpisodeInfoByTitle
	fi
	if [ -z "$episode_info" ] && ! $episode_title_set && [[ "$episode_title" == *,* ]]; then	# No info found and we are allowed to search and our title contains a ","
		funcGetEpisodeTitleFromEpg "." ","					# Try again with . AND , as delimiter
		if [ -n "$episode_title" ]; then					# If we have got an episode title
			funcGetEpisodeInfoByTitle
		else
			eecho -e "    EPG:\tNo episode title found in EPG!"
			logNexit 21
		fi
	fi
	
	if [ -z "$episode_info" ] && ! $episode_title_set; then	# No info found and delimiter , is possible:
		funcGetEpisodeTitleFromEpg ","						# Try again with , as delimiter
		if [ -n "$episode_title" ]; then					# If we have got an episode title
			funcGetEpisodeInfoByTitle
		fi
	fi
	if [ -z "$episode_info" ] && ! $episode_title_set && [[ "$episode_title" == *.* ]]; then	# No info found and our title contains a "."
		funcGetEpisodeTitleFromEpg "," "."					# Try again with , AND . as delimiter
		if [ -n "$episode_title" ]; then					# If we have got an episode title
			funcGetEpisodeInfoByTitle
		fi
	fi
}

funcParam $@
doIt
logNexit 20
