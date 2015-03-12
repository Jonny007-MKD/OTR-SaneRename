#!/bin/bash

#srArgs="-d"

declare -A files

files=(
	["Bibi_Blocksberg_15.03.07_08-30_zdf_30_TVOON_DE.mpg.avi"]="Bibi.Blocksberg..S01E06..Bibi.im.Dschungel.avi"			# Remove 3 words from the beginning
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

	if [ "$result" != "${files["$the_file"]}" ]; then
		echo -e "\033[31m$the_file -> $result";
		echo "'$result' != '${files[$the_file]}'";
	fi
done;
