# TODO: Umlaute werden beim Download der xml über alle serien nicht richtig übergeben. evtl mit %-Code arbeiten

### CONFIG ###
apikey="2C9BB45EFB08AD3B"
productname="SaneRename for OTR (ALPHA) v0.2"

function eecho {
	if [ -z "$silent" ]; then
		echo "$1" "$2" "$3"
	fi
}


### Check input ###
while getopts "f:l:s" optval; do
	case $optval in
		"f")
			path=$OPTARG;;
		"s")
			silent=1;;
		"l")
			lang="$OPTARG";;
		"?")
			echo "Usage: $0 -f pathToAvi [-s] [-l LANG]";;
		":")
			echo "No argument value for option $OPTARG";;
	esac
done

eecho " :: $productname"
eecho " :: by Leroy Foerster"
eecho


if [ -z "$path" ]; then
	echo "Usage: $0 -f pathToAvi [-s] [-l LANG]"
fi

case "$lang" in
	de*)
		lang="de";;
	en*)
		lang="en";;
	us*)
		lang="en";;
	fr*)
		lang="fr";;
	"")
		lang="de";;
	*)
		echo "Language not recognized: $lang"
		exit 11;;
esac

PWD=$(readlink -e $0)
PWD=$(dirname $PWD)

file_name="$(basename $path)"
file_suffix="${file_name##*.}"
file_dir="$(dirname $path)"

if [ ! -f "$path" ]; then
	echo "This is no file!"
	echo "$path"
	exit 10
fi


# Split filename into fields, divided by _ (underscores)

fields="${file_name//_/ }"

# If first field is a number (cutlist id)
firstField="${fields%% *}"
test $firstField -eq 0 2>/dev/null
if [ $? -ne 2 ]; then
	fields=${fields##$firstField }
fi

fieldsTitle=${fields%% [0-9][0-9].*}						# Cut off everything after the title: date, hour, sender, ...
fieldsSender=${fields##*-[0-9][0-9]}						# Cut off everything bevor the sender: title, date, time, ...

fieldsDate=${fields%%$fieldsSender}							# Cut off the sender
fieldsDate=${fieldsDate##$fieldsTitle }						# Cut off the title, now we do have the date and time
fieldsTime=${fieldsDate##* }
fieldsDate=${fieldsDate%% *}

fieldsDateInv=$(date +%d.%m.%Y --date="${fieldsDate//./-}")	# Convert YY.MM.DD to DD.MM.YY
fieldsTime=${fieldsTime/-/:}								# Convert HH-MM to HH:MM

fieldsTitle=${fieldsTitle// s /\'s }						# Replace a single s with 's
if [ "$lang" == "de" ]; then
	fieldsTitle=${fieldsTitle//Ae/Ä}						# Replace Umlauts
	fieldsTitle=${fieldsTitle//Oe/Ö}
	fieldsTitle=${fieldsTitle//Ue/Ü}
	fieldsTitle=${fieldsTitle//ae/ä}
	fieldsTitle=${fieldsTitle//oe/ö}
	fieldsTitle=${fieldsTitle//ue/ü}
fi


eecho -e "    Work dir:\t$PWD"
eecho -e "    Datum:\t$fieldsDateInv"
eecho -e "    Uhrzeit:\t$fieldsTime"
eecho -e "    Titel:\t$fieldsTitle"

# ------------ Series ID abrufen anhand vom Titel der Serie -------------------- ;;
series_db="https://www.thetvdb.com/api/GetSeries.php?seriesname=$fieldsTitle&language=$lang"
wget "$series_db" -O "$PWD/series.xml" -o /dev/null
error=$?
if [ $error -ne 0 ]; then
	eecho "Downloading $series_db failed (Exit code: $error)!"
	exit 2
fi

series_id=$(grep -m 1 "seriesid" $PWD/series.xml)			# Get series id (needed later)
if [ -z "$series_id" ]; then
	eecho -e "    TVDB:\tSeries NOT found!"
	exit 3
fi

series_title=$(grep -m 1 "SeriesName" $PWD/series.xml)		# Get series name from TvDB (for user)
series_alias=$(grep -m 1 "AliasName" $PWD/series.xml)
series_id=${series_id%<*}									# Remove XML tags
series_id=${series_id#*>}
series_title=${series_title%<*}
series_title=${series_title#*>}
series_alias=${series_alias%<*}
series_alias=${series_alias#*>}

eecho -e "    TVDB:\tSeries found.\tID:    $series_id"
eecho -e "\t\t\t\tName:  $series_title"
if [ -n "$series_alias" ]; then
	eecho -e "\t\t\t\tAlias: $series_alias"
fi

# ------------ EPG vom jeweiligen Tag herunterladen, durchsuchen anhand der Ausstrahlungszeit ------------- ;;
# Download OTR EPG data and search for series and time
if [ ! -f "$PWD/epg-$fieldsDate.csv" ]; then				# didnt cache this file
	rm -f "$PWD/epg-*.csv" 2> /dev/null
	epg_datei="https://www.onlinetvrecorder.com/epg/csv/epg_20${fieldsDate//./_}.csv"
	wget "$epg_datei" -O "$PWD/epg-$fieldsDate.csv" -o /dev/null
	error=$?
	if [ $error -ne 0 ]; then
		eecho "Downloading $epg_datei failed (Exit code: $error)!"
		exit 4
	fi
fi

epg="$(grep "$series_title" "$PWD/epg-$fieldsDate.csv" | grep "$fieldsTime")"
if [ -z "$epg" ]; then
	eecho "    EPG:\tSeries not found in EPG data"
	exit 5
fi


# Parse EPG data
OLDIFS=$IFS
IFS=";"
read epg_id epg_start epg_end epg_duration epg_sender epg_title epg_type epg_text epg_genre epg_fsk epg_language epg_weekday epg_additional epg_rpt epg_downloadlink epg_infolink epg_programlink <<< "$epg"
IFS=$OLDIFS


episode_title="${epg_text%%.*}"									# Text begins with episode title
if [ -z "$episode_title" ]; then
	eecho "    EPG:\tNo Episode title found"
	exit 5
fi
eecho -e "    EPG:\tEpisode title:\t$episode_title"


# Download Episode list of series
episode_db="https://www.thetvdb.com/api/$apikey/series/$series_id/all/$lang.xml"
wget $episode_db -O "$PWD/episodes.xml" -o /dev/null
error=$?
if [ $error -ne 0 ]; then
	eecho "Downloading $episode_db failed (Exit code: $error)!"
	exit 6
fi

episode_info=$(grep "$episode_title" "$PWD/episodes.xml" -B 10)	# Get XML data of episode
episode_number=$(echo -e "$episode_info" | grep -m 1 "episodenumber") # Get episode number
episode_season=$(echo -e "$episode_info" | grep -m 1 "season")		# Get season number
episode_number=${episode_number%<*}									# remove xml tags
episode_number=${episode_number#*>}
episode_season=${episode_season%<*}
episode_season=${episode_season#*>}

# add leading zero
if [ $episode_number -le 9 ]; then
	episode_number="0$episode_number"
fi
if [ $episode_season -le 9 ]; then
	episode_season="0$episode_season"
fi

eecho -e "    TvDB: Season:\t$episode_season"
eecho -e "          Episode:\t$episode_number"

echo "${series_title// /.}..S${episode_season}E${episode_number}..${episode_title// /.}.$file_suffix"
