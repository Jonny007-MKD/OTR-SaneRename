#!/bin/bash

#srArgs="-d"

declare -A files

files=(
# Nothing special
	["Inspector_Barnaby_15.03.09_21-45_zdfneo_100_TVOON_DE.mpg.HQ.avi"]="Inspector.Barnaby..S07E02..Immer.wenn.der.Scherenschleifer....HQ.avi"

# Remove 3 words from the beginning and some from the end
	["Bibi_Blocksberg_15.03.07_08-30_zdf_30_TVOON_DE.mpg.avi"]="Bibi.Blocksberg..S01E06..Bibi.im.Dschungel.avi"
# Use season and episode information from the beginning
	["S05_E22_Good_Wife_15.03.11_00-40_sixx_40_TVOON_DE.mpg.HQ.avi.otrkey"]="Good.Wife..S05E22..Ein.seltsames.Jahr.otrkey"
# Cut 3 words from the end
	["Good_Wife_15.03.11_00-40_sixx_40_TVOON_DE.mpg.HQ.avi.otrkey"]="Good.Wife..S05E22..Ein.seltsames.Jahr.otrkey"
# Use , as delimiter
	["H2O_Ploetzlich_Meerjungfrau_15.02.28_11-55_orf1_30_TVOON_DE.mpg.avi.otrkey"]="H2O.-.Plötzlich.Meerjungfrau..S03E06..Bella.irrt.otrkey"
);

if [ -f test.sh ]; then
	path=".."
else
	path="."
fi

if [ ! -f "$path/saneRenamix.sh" ]; then
	echo "saneRenamix.sh not found!" >&2
fi


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

	result="$($path/saneRenamix.sh $srArgs -s -f "$the_file")";

	if [ -L $path/$epg_file ]; then					# We have created it above
		rm $path/$epg_file
	fi

	if [ "$result" != "${files["$the_file"]}" ]; then
		echo -e "\033[31m$the_file -> $result";
		echo "'$result' != '${files[$the_file]}'";
	fi
done;
