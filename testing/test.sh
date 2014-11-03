#!/bin/bash

#srArgs="-d"

files=(
			"Inspector_Barnaby_14.10.27_21-45_zdfneo_95_TVOON_DE.mpg.HQ.avi"
			"Bibi_Blocksberg_14.10.18_08-35_zdf_25_TVOON_DE.mpg.avi"								# Description in EPG
			"Bibi_Blocksberg_14.10.18_09-00_zdf_25_TVOON_DE.mpg.avi"								# Description in EPG
			"Bibi_und_Tina_14.10.26_07-45_zdf_25_TVOON_DE.mpg.avi"									# Normal title in EPG
			"Downton_Abbey_14.10.11_13-50_zdf_50_TVOON_DE.mpg.HQ.avi"								# Normal title in EPG
			"Good_Wife_14.10.28_23-05_sixx_50_TVOON_DE.mpg.HQ.avi"									# Normal title in EPG
			"Grey_s_Anatomy_Die_jungen_Aerzte_14.10.29_20-15_pro7_60_TVOON_DE.mpg.HQ.avi"			# Normal title in EPG after episode title (. ,)
			"Inspector_Barnaby_14.10.27_20-15_zdfneo_90_TVOON_DE.mpg.HQ.avi"						# Normal title in EPG
			"Inspector_Barnaby_14.10.31_00-45_zdf_100_TVOON_DE.mpg.HQ.avi"							# Normal title in EPG
			"Mankells_Wallander_Das_Gespenst_14.11.02_20-15_ardeinsfestival_90_TVOON_DE.mpg.HQ.avi"	# Title in Filename
);
results=(
			"Inspector.Barnaby..S09E05..Erst.morden,.dann.heiraten.HQ.avi"
			"Bibi.Blocksberg..S01E01..Der.Wetterfrosch.avi"
			"Bibi.Blocksberg..S01E13..Bibi.im.Orient.avi"
			"Bibi.und.Tina..S01E08..Tina.in.Gefahr.avi"
			"Downton.Abbey..S03E05..Auf.Leben.und.Tod.HQ.avi"
			"Good.Wife..S04E16..Tanz.mit.dem.Teufel.HQ.avi"
			"Grey's.Anatomy..S10E15..Was.wir.entsorgen.HQ.avi"
			"Inspector.Barnaby..S09E06..Pikante.Geheimnisse.HQ.avi"
			"Inspector.Barnaby..S09E06..Pikante.Geheimnisse.HQ.avi"
			"Inspector.Barnaby..S04E01..Der.Garten.des.Todes.HQ.avi"
			"Wallander..S02E10..Das.Gespenst.HQ.avi"
);


i=0
while [ $i -lt ${#files[@]} ]; do
	echo -e "\033[37m${files[$i]}";
	result="$(../saneRenamix.sh $srArgs -s -f ${files[$i]})";
	if [ "$result" != "${results[$i]}" ]; then
		echo -e "\033[31m${files[$i]} -> $result";
		echo "'$result' != '${results[$i]}'";
	fi
	i=$(($i+1));
done;
