#!/bin/bash

# use first parameter to add parameters for sanerenamix
srArgs="$1"

declare -A files

files=(
# Nothing special
	["Inspector_Barnaby_15.03.09_21-45_zdfneo_100_TVOON_DE.mpg.HQ.avi"]="Inspector.Barnaby..S07E02..Immer.wenn.der.Scherenschleifer....mpg.HQ.avi"

# Remove 3 words from the beginning and some from the end
	["Bibi_Blocksberg_15.03.07_08-30_zdf_30_TVOON_DE.mpg.avi"]="Bibi.Blocksberg..S01E06..Bibi.im.Dschungel.mpg.avi"
# Use season and episode information from the beginning
	["S05_E22_Good_Wife_15.03.11_00-40_sixx_40_TVOON_DE.mpg.HQ.avi"]="Good.Wife..S05E22..Ein.seltsames.Jahr.mpg.HQ.avi"
# Use season and episode information from the end
	["Bibi_Blocksberg_S02E07_15.04.05_07-20_zdf_25_TVOON_DE.mpg.avi.otrkey"]="Bibi.Blocksberg..S02E07..Der.Hexengeburtstag.mpg.avi.otrkey"
# Cut 3 words from the end
	["Good_Wife_15.03.11_00-40_sixx_40_TVOON_DE.mpg.HQ.avi.otrkey"]="Good.Wife..S05E22..Ein.seltsames.Jahr.mpg.HQ.avi.otrkey"
# Use , as delimiter
	["H2O_Ploetzlich_Meerjungfrau_15.02.28_11-55_orf1_30_TVOON_DE.mpg.avi.otrkey"]="H2O.-.Plötzlich.Meerjungfrau..S03E06..Bella.irrt.mpg.avi.otrkey"
# Series and episode name in title
	["Irene_Huss_Kripo_Goeteborg_Der_im_Dunkeln_wacht_S02E01_15.08.08_22-55_ard_90_TVOON_DE.mpg.HQ.avi"]="Irene.Huss,.Kripo.Göteborg..S02E01..Der.im.Dunkeln.wacht.mpg.HQ.avi"
# Difficult search for series
	["Ein_Fall_fuer_TKKG_S01E01_15.11.16_13-20_kika_20_TVOON_DE.mpg.avi"]="Ein.Fall.für.TKKG..S01E01..Das.leere.Grab.im.Moor.mpg.avi"
# Take Season and Episode info from manual.json
	["Die_Bruecke_Transit_in_den_Tod_18.09.22_00-45_zdf_115_TVOON_DE.mpg.HD.avi.otrkey"]="Die.Brücke.–.Transit.in.den.Tod..S01E01..Teil.1.mpg.HD.avi.otrkey"
);

if [ -f test.sh ]; then
	path=".."
else
	path="."
fi

if [ ! -f "$path/saneRenamix.py" ]; then
	echo "saneRenamix.py not found!" >&2
	exit 1
fi

function finish {
	pushd $path
	# Restore manual.json
	if [ -f "manual.json.orig" ]; then
		mv "manual.json.orig" "manual.json"
	fi
	# Restore *.cache
	for f in `ls *.cache.orig`; do
		mv "$f" "${f::-5}"
	done
	popd
}
trap finish EXIT

function init {
	pushd $path
	# Backup and replace manual.json
	if [ -f "$path/manual.json" ]; then
		mv "$path/manual.json" "$path/manual.json.orig"
	fi
	cp "$(dirname $0)/manual.json" "$path/manual.json"
	# Remove caches
	for f in `ls *.cache`; do
		mv "$f" "$f.orig"
	done
	popd
}


function runTest {
	for the_file in "${!files[@]}"; do
		echo -e "\033[37m${the_file}";

		file="${the_file//_/ }"

		file_title=${file%% [0-9][0-9].*}						# Cut off everything after the title: date, hour, sender, ...
		file_sender=${file##*-[0-9][0-9]}						# Cut off everything bevor the sender: title, date, time, ...

		file_date=${file%%$file_sender}							# Cut off the sender
		file_date=${file_date##$file_title }					# Cut off the title, now we do have the date and time
		file_time=${file_date##* }
		file_date=${file_date%% *}

		epg_file="epg-$file_date.csv"

		if ! [ -f $path/$epg_file ]; then				# Create EPG file if neccessary
			ln -s "testing/$epg_file" "$path/$epg_file"
		fi

		result="$(python3 $path/saneRenamix.py $srArgs -s -f "$the_file")";
		if [ "$result" != "${files["$the_file"]}" ]; then
			echo -e "\033[31m$the_file -> $result (cache)";
			echo "'$result' != '${files[$the_file]}'";
		else
			if [ -L $path/$epg_file ]; then				# We have created it above
				rm $path/$epg_file
			fi
		fi
		echo -ne "\033[37m"
		read -p "ok. next? "
	done;
}

init
runTest
runTest
