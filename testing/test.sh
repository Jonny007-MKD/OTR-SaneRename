#!/bin/bash

srArgs="-d"

files=(		"Inspector_Barnaby_14.10.27_21-45_zdfneo_95_TVOON_DE.mpg.HQ.avi");
results=(	"Inspector.Barnaby..S14E03..Sonstwas.HQ.avi");


i=0
while(i < ${#files[@]}); do
	echo ${files[$i]};
	result="$(../saneRenamix.sh $srArgs -s -f ${files[$i]})";
	if [ "$result" != "${results[$i]}" ]; then
		echo "${files[$i]} -> $result"
	fi
	i=$(($i+1));
done;