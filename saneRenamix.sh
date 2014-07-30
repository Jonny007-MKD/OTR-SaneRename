#!/bin/bash

# TODO: Umlaute werden beim Download der xml über alle serien nicht richtig übergeben. evtl mit %-Code arbeiten

##########
# Config #
##########
apikey="2C9BB45EFB08AD3B"
productname="SaneRename for OTR (ALPHA) v0.2"
lang="de"


##########
# Script #
##########

# Print only of not silent
function eecho {
	if [ -z "$silent" ]; then
		echo "$1" "$2" "$3"
	fi
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    if $wget_running; then
		rm -f $wget_file
	fi
    exit 40
}
wget_running=false;

# Parse the parameters
function funcParam {
	while getopts "f:l:s" optval; do
		case $optval in
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
						exit 11;;
				esac;;
			"?")					# Help
				echo "Usage: $0 -f pathToAvi [-s] [-l LANG]"
				exit;;
			":")
				echo "No argument value for option $OPTARG"
				exit;;
		esac
	done
}

# Print the header
function funcHeader {
	eecho " :: $productname"
	eecho " :: by Leroy Foerster"
	eecho
}

# Get title, date and time
function funcAnalyzeFilename {
	# Split filename into words, divided by _ (underscores)
	file="${file_name//_/ }"

	firstField="${file%% *}"								# Get the first word
	test $firstField -eq 0 2>/dev/null						# If first word is a number -> cutlist id
	if [ $? -ne 2 ]; then
		file=${file##$firstField }							# remove it
	fi

	file_title=${file%% [0-9][0-9].*}						# Cut off everything after the title: date, hour, sender, ...
	file_sender=${file##*-[0-9][0-9]}						# Cut off everything bevor the sender: title, date, time, ...

	file_date=${file%%$file_sender}							# Cut off the sender
	file_date=${file_date##$file_title }					# Cut off the title, now we do have the date and time
	file_time=${file_date##* }
	file_date=${file_date%% *}

	file_dateInv=$(date +%d.%m.%Y --date="${file_date//./-}")	# Convert YY.MM.DD to DD.MM.YY
	file_time=${file_time/-/:}								# Convert HH-MM to HH:MM

	file_title=${file_title// s /\'s }						# Replace a single s with 's
	if [ "$lang" == "de" ]; then
		file_title=${file_title//Ae/Ä}						# Replace umlauts
		file_title=${file_title//Oe/Ö}
		file_title=${file_title//Ue/Ü}
		file_title=${file_title//ae/ä}
		file_title=${file_title//oe/ö}
		file_title=${file_title//ue/ü}
	fi
	
	eecho -e "    Work dir:\t$PwD"
	eecho -e "    Datum:\t$file_dateInv"
	eecho -e "    Uhrzeit:\t$file_time"
	eecho -e "    Titel:\t$file_title"
}

# Get the series ID from TvDB (needed to fetch episodes from TvDB)
function funcGetSeriesId {
	local tmp;
	if [ -f "$PwD/series.cache" ]; then								# Search the series cache
		funcGetSeriesIdFromCache
	fi
	if [ -z "$series_id" ]; then									# Otherwise ask TvDB whether they do know the series
		funcGetSeriesIdFromTvdb
	fi
	if [ -z "$series_id" ]; then									# This series was not found anywhere :(
		eecho -e "    TVDB:\tSeries not found!"
		exit 30
	fi

	eecho -e "    \t\t\tName:\t$series_title"
	if [ -n "$series_alias" ]; then
		eecho -e "\t\t\t\tAlias: $series_alias"
	fi
}

# Search the series.cache file for this series and get TvDB series id
function funcGetSeriesIdFromCache {
	local title;
	local tmp;
	title="$file_title";
	while true; do
		series_id="$(grep "^$title|#|" "$PwD/series.cache")"			# Search for this title in the cache
		if [ -n "$series_id" ]; then									# Stop if we have found something
			series_title="${series_id%|#|*}"
			series_id="${series_id#*|#|}"
			eecho -e "    Cache:\tSeries found.\tID:\t$series_id"
			break;
		fi
		tmp="${title% *}"												# Shorten the title by one word
		if [ ${#tmp} -le 4 ] || [ "$tmp" == "$title" ]; then			# Too short or was not shortened
			break;
		fi
		title=$tmp
	done
}

# Search the TvDB for this series and get TvDB series id
function funcGetSeriesIdFromTvdb {
	local title;
	local tmp;
	title="$file_title";
	while true; do
		series_db="https://www.thetvdb.com/api/GetSeries.php?seriesname=${title}&language=$lang"
		wget_file="$PwD/series.xml"
		wget_running=true;
		wget "$series_db" -O "$wget_file" -o /dev/null
		wget_running=false;
		error=$?
		if [ $error -ne 0 ]; then
			eecho -e "\t\t\tDownloading $series_db failed (Exit code: $error)!"
		fi
		tmp=$(grep -m 1 -B 3 -A 1 ">$title<" "$wget_file")
		if [ -n "$tmp" ]; then
			series_id=$(echo "$tmp" | grep "seriesid>")
			series_title=$(echo "$tmp" | grep "SeriesName>")			# Get series name from TvDB
			series_alias=$(echo "$tmp" | grep "AliasName>")
			series_id=${series_id%<*}									# Remove XML tags
			series_id=${series_id#*>}
			series_title=${series_title%<*}
			series_title=${series_title#*>}
			series_alias=${series_alias%<*}
			series_alias=${series_alias#*>}

			echo "$series_title|#|$series_id" >> "$PwD/series.cache"
			eecho -e "    TVDB:\tSeries found.\tID:    $series_id"
			break
		fi

		tmp="${title% *}"												# Shorten the title by one word
		if [ ${#tmp} -le 4 ] || [ "$tmp" == "$title" ]; then			# Too short or was not shortened
			break;
		fi
		title=$tmp
	done
}

# Get the EPG from OnlineTvRecorder and get the title of the episode
function funcGetEPG {
	# Download OTR EPG data and search for series and time
	wget_file="$PwD/epg-${file_date}.csv"
	if [ ! -f "$wget_file" ]; then										# This EPG file does not exist
		rm -f ${PwD// /\\ }/epg-*.csv 2> /dev/null						# Delete all old files
		epg_csv="https://www.onlinetvrecorder.com/epg/csv/epg_20${file_date//./_}.csv"
		wget_running=true;
		wget "$epg_csv" -O "$wget_file" -o /dev/null					# Download the csv
		wget_running=false;
		error=$?
		if [ $error -ne 0 ]; then
			eecho "Downloading $epg_csv failed (Exit code: $error)!"
			exit 4
		fi
	fi

	epg="$(grep "$series_title" "$wget_file" | grep "${file_time}")"	# Get the line with the movie
	if [ -z "$epg" ]; then
		eecho -e "    EPG:\tSeries \"$series_title\" not found in EPG data"	# This cannot happen :)
		exit 5
	fi

	# Parse EPG data using read
	OLDIFS=$IFS
	IFS=";"
	read epg_id epg_start epg_end epg_duration epg_sender epg_title epg_type epg_text epg_genre epg_fsk epg_language epg_weekday epg_additional epg_rpt epg_downloadlink epg_infolink epg_programlink <<< "$epg"
	IFS=$OLDIFS
}

# Get the title of the episode from description in EPG using $1 as delimiter to the real description
function funcGetEpgEpisodeTitle {
	episode_title="${epg_text%%$1*}"									# Text begins with episode title, cut off the rest
	if [ -z "$episode_title" ]; then
		eecho -e "    EPG:\tNo Episode title found"
		exit 5
	fi
	eecho -e "    EPG:\tEpisode title:\t$episode_title"					# We found some title :)
}

# Download episodes list from TvDB, language as argument
function funcGetEpisodes {
	# Download Episode list of series
	episode_db="https://www.thetvdb.com/api/$apikey/series/$series_id/all/$1.xml"
	wget_file="$PwD/episodes.xml"
	wget_running=true;
	wget $episode_db -O "$wget_file" -o /dev/null
	wget_running=false;
	error=$?
	if [ $error -ne 0 ]; then
		eecho "Downloading $episode_db failed (Exit code: $error)!"
		exit 6
	fi
}

# Get the information from episodes list of TvDB
function funcGetEpisodeInfo {
	while true; do
		episode_info=$(grep "Name>$episode_title" "$PwD/episodes.xml" -B 10)	# Get XML data of episode
		if [ -z "$episode_info" ]; then											# Nothing found. Shorten the title
			tmp=${episode_title% *}
			if [ ${#tmp} -le 4 ] || [ "$tmp" == "$episode_title" ]; then
				break;
			fi
			episode_title="$tmp"
			eecho -e "    EPG:\tEpisode title:\t$episode_title"
		else
			break;
		fi
	done

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
		if [[ "$episode_number" == *.* ]]; then									# Convert float to integer. Float!?
			episode_number=${episode_number%%.*}
		fi
		if [[ "$episode_season" == *.* ]]; then
			episode_season=${episode_number%%.*}
		fi

		if [ $episode_number -le 9 ]; then										# add leading zero
			episode_number="0$episode_number"
		fi
		if [ $episode_season -le 9 ]; then
			episode_season="0$episode_season"
		fi

		eecho -e "    TvDB:\tSeason: \t$episode_season"
		eecho -e "         \tEpisode:\t$episode_number"
	fi
}


# This function does everything
function doIt {	
	funcHeader

	if [ -z "$path" ]; then									# If no path was specified (-f)
		echo "Usage: $0 -f pathToAvi [-s] [-l LANG]"
		exit 15
	fi

	if [ ! -f "$path" ]; then								# If the path is no regular file
		echo "This is no file!"
		echo "$path"
		exit 10
	fi

	PwD=$(readlink -e $0)									# Get the path to this script
	PwD=$(dirname "$PwD")

	file_name="$(basename $path)"							# Get file name
	file_suffix="${file_name##*.}"							# Get file suffix
	file_dir="$(dirname $path)"								# Get file directory

	funcAnalyzeFilename										# Get info from $file_name
	funcGetSeriesId											# Get series ID from cache or TvDB

	if [ "$file_title" != "$series_title" ]; then			# Title in file is not series title. This means the episode title is also in the file title
		episode_title="${file_title#$series_title }"
		eecho -e "    \t\tEpisode title:\t$episode_title"
		episode_title_set=true								# used in doItEpisodes (whether the episode title shall be search in epg)
	else													# Otherwise search the episode title in the EPG:
		funcGetEPG											# Download epg file
		episode_title_set=false
	fi

	doItEpisodes $lang										# Search for the episode in the specified language
	if [ -z "$episode_info" ]; then							# Episode was not found!
		if [ "$lang" != "en" ]; then
			doItEpisodes "en"								# Try it again with english
		fi
		if [ -z "$episode_info" ]; then						# Again/still no info found! Damn :(
			echo "No episode info found!"
			exit 20
		fi
	fi
		
	
	if [ -n "$episode_info" ]; then
		echo "${series_title// /.}..S${episode_season}E${episode_number}..${episode_title// /.}.$file_suffix"
		exit 0
	fi
}

# Parse the episodes, language as argument
function doItEpisodes {
	if ! $episode_title_set; then
		funcGetEpgEpisodeTitle "."							# Get the episode title using . as delimiter
	fi
	funcGetEpisodes $1										# Download episodes file
	funcGetEpisodeInfo
	
	if [ -z "$episode_info" ] && ! $episode_title_set; then	# No info found and delimiter , possible:
		funcGetEpgEpisodeTitle ","							# Try again with , as delimiter
		funcGetEpisodeInfo
	fi
}

funcParam $@
doIt
exit 30
