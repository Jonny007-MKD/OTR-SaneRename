#!/bin/bash

#srArgs="-d"

declare -A files

files=(
	["Bibi_Blocksberg_15.03.07_08-30_zdf_30_TVOON_DE.mpg.avi"]="Bibi.Blocksberg..S01E06..Bibi.im.Dschungel.avi"			# Remove 3 words from the beginning
);


i=0
for file in "${!files[@]}"; do
	echo -e "\033[37m${file}";
	result="$(./saneRenamix.sh $srArgs -s -f "$file")";
	if [ "$result" != "${files["$file"]}" ]; then
		echo -e "\033[31m$file -> $result";
		echo "'$result' != '${files[$file]}'";
	fi
	i=$(($i+1));
done;
