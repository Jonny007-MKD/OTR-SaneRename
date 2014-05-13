;; TODO: Umlaute werden beim Download der xml όber alle serien nicht richtig όbergeben. evtl mit %-Code arbeiten

#NoTrayIcon
#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Outfile=SaneRename for OTR.exe
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Comment=Umbenennungstool fόr Downloads vom OTR in das fόr Serien όbliche Format zur weiterverarbeitung durch Scraper
#AutoIt3Wrapper_Res_Description=Umbenennungstool fόr Downloads vom OTR in das fόr Serien όbliche Format zur weiterverarbeitung durch Scraper
#AutoIt3Wrapper_Res_Fileversion=0.2.0.15
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_LegalCopyright=All rights reserved. Leroy Fφrster
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Run_AU3Check=n
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <Array.au3>
#include <_CSV2Array.au3>
#include <File.au3>
#include <String.au3>

Global Static $apikey = "2C9BB45EFB08AD3B"
Global Static $productname = "SaneRename for OTR (ALPHA) v0.2"
Dim $titel

w("")
w(" :: " & $productname & @CRLF & " :: by Leroy Foerster" & @CRLF & @CRLF)

;~ Sleep(1000)


Func w($text)
	ConsoleWrite($text & @CRLF & @CRLF)
	Sleep(500)
EndFunc   ;==>w

Func ende($t)
	ConsoleWrite($t & @LF)
	MsgBox(0, "Fehler", $t)
	Exit 3
EndFunc   ;==>ende

$pfad = InputBox("","")
;~ $pfad = FileOpenDialog("Datei mit OTR-Benennungsschema [Titel_Datum_Zeit] auswδhlen", "", "Videodateien (*.avi;*.mp4;*.mpg;*.mpeg;*.divx;*.xvid;*.mkv)")
$datei = StringSplit($pfad, "\")
$datei = $datei[$datei[0]]
$dateiendung = StringRight($datei, 3)

;; Datei in einzelne Felder, getrennt von _ (underscores) aufteilen

$array = StringSplit($datei, "_", 2)

$array_pos = 0
For $i In $array
	If StringIsDigit($array[0]) And $array_pos == 0 Then ; Prόfen, ob das erste Feld Cutlistnummern enthδlt, statt den Sendungsnamen
		w("Erstes Feld ist eine Zahl (vermutlich Cutlist-Nummer) und wird ignoriert.")

	ElseIf StringRegExp($i, "\d+\.\d+\.\d+") Then ; Feld ist Datum YY.MM.TT?
		$datum = StringRegExpReplace($i, "(\d+)\.(\d+)\.(\d+)", "$3.$2.$1")

	ElseIf StringRegExp($i, "\d+-\d+") Then ; Feld ist Uhrzeit?
		$uhrzeit = StringRegExpReplace($i, "(\d+)-(\d+)", "\1:\2") ; Uhrzeit in ein schφnes Format bringen
		ExitLoop ; Nach der Uhrzeit kommen keinen parsbaren Informationen mehr, der Loop wird verlassen

	Else
		$titel &= $i & " " ; Das Feld passt zu keinem vorherigen Fall, es muss folglich zum Titel gehφren. Feld wird an bestehenden Titel angehδngt.
	EndIf

	$array_pos += 1
Next
$titel = StringStripWS($titel, 2) ; Entferne όberflόssiges Leerzeichen am Ende des Titels
$titel = StringRegExpReplace($titel, "(.*)(ae)(.*)", "\1δ\3") ; Mache aus AE ein Δ (Umlaute erstellen)
$titel = StringRegExpReplace($titel, "(.*)(ue)(.*)", "\1δ\3") ; Mache aus UE ein ά (Umlaute erstellen)
$titel = StringRegExpReplace($titel, "(.*)(oe)(.*)", "\1δ\3") ; Mache aus OE ein Φ (Umlaute erstellen)

w("    Datum: " & @TAB & @TAB & $datum)
w("    Uhrzeit: " & @TAB & @TAB & $uhrzeit)
w("    Titel: " & @TAB & @TAB & $titel)

;; ------------ Series ID abrufen anhand vom Titel der Serie -------------------- ;;
$series_db = "http://www.thetvdb.com/api/GetSeries.php?seriesname=" & $titel & "&language=de"
w("Lade Serieninfos von '" & $series_db & "' herunter...")
If Not InetGet($series_db, "serien.xml") Then Ende("Fehler beim Download von " & $series_db)
Dim $serien_xml[1]
_FileReadToArray("serien.xml", $serien_xml)
;~ FileDelete("serien.xml")

$serien_xml_zeile_serie = _ArraySearch($serien_xml, $titel, -1, -1, -1, -1, 1) ; Nach Serientitel-Zeile suchen, von oben nach unten
If $serien_xml_zeile_serie = -1 Then Ende("Die Serie wurde nicht in der TVDB.COM gefunden.")
$serien_id = (_StringBetween($serien_xml[$serien_xml_zeile_serie - 2], ">", "</"))
$serien_id = $serien_id[0]
w("    TVDB: " & @TAB & @TAB & "Serie gefunden. ID: " & $serien_id)

;; ------------ EPG vom jeweiligen Tag herunterladen, durchsuchen anhand der Ausstrahlungszeit ------------- ;;
$aDatum_DMY = StringSplit($datum, ".")
$epg_datei = "http://www.onlinetvrecorder.com/epg/csv/epg_20" & $aDatum_DMY[3] & "_" & $aDatum_DMY[2] & "_" & $aDatum_DMY[1] & ".csv"

;~ w("Lade die EPG Datei '" & $epg_datei & "' herunter...")

If Not InetGet($epg_datei, "epg.csv") Then Ende("Fehler beim Download von " & $epg_datei)

$epg = _CSV2Array("epg.csv")
FileDelete("epg.csv")

$ersterFund = _ArraySearch($epg, $uhrzeit, -1, -1, -1, -1, 1, 1) ; Position der ersten Sendung von hh:mm Uhr
$letzterFund = _ArraySearch($epg, $uhrzeit, -1, -1, -1, -1, 0, 1) ; Position der letzten Sendung von hh:mm Uhr
$ID = (_ArraySearch($epg, $titel, $ersterFund, $letzterFund, -1, -1, -1, 5)) ; Position (Zeile) der Sendung mit dem $TITEL im Berech der oben eingegerenzten Uhrzeiten. So wird vermieden, dass die Infos von der gleichen Sendung, zu einer anderen Sendezeit gefunden werden

If $ID == -1 Then _ArrayDisplay($epg, "Fataler Fehler: Sendung '" & $titel & "' konnte im EPG (Spalte 5) nicht gefunden werden!") ; Wenn im EPG nichts gefunden wurde mit dem Titel (z.B. bei falscher Formatierung oder Whitespaces)
;; Beschreibung lesen und alles nach dem Komma als Episodentitel behandeln (BETA)
w("    EPG: " & @TAB & @TAB & "gefunden. Zeile: " & $ID)

$beschreibung = $epg[$ID][7] ; Hole die Beschreibung aus Spalte 7 der Zeile, die oben herausgefunden wurde

$episode = StringSplit($beschreibung, ",") ; Episodenname kommt όblicherweise hinter dem Komma
$episode = StringStripWS($episode[2], 7) ; Fόhrende und folgende Whitespaces entfernen

w("    Episodentitel: " & @TAB & $episode)
;; Episoden von der TVDB herunterladen und nach einer Episode mit diesem Titel suchen

$episoden_db = "http://www.thetvdb.com/api/" & $apikey & "/series/" & $serien_id & "/all/de.xml"
;~ w("Lade Episodeninfos von '" & $episoden_db & "'herunter...")

If Not InetGet($episoden_db, "episoden.xml") Then ende("Fehler beim Download von " & $episoden_db)

Dim $episoden_xml[1]
_FileReadToArray("episoden.xml", $episoden_xml)

;; Infos aus der Episodendatei rauslesen

$episode_xml_zeile_episode = _ArraySearch($episoden_xml, $episode, -1, -1, -1, -1, 1) ; Nach Episodentitel-Zeile suchen, von oben nach unten
If $episode_xml_zeile_episode == -1 Then
	ConsoleWrite("Keine Episode mit diesem Titel gefunden. Suche nochmal in der englischen Datenbank... ")

	$episoden_db = "http://www.thetvdb.com/api/" & $apikey & "/series/" & $serien_id & "/all/en.xml"
;~ w("Lade Episodeninfos von '" & $episoden_db & "'herunter...")

	If Not InetGet($episoden_db, "episoden.xml") Then ende("Fehler beim Download von " & $episoden_db)

	Dim $episoden_xml[1]
	_FileReadToArray("episoden.xml", $episoden_xml)

	;; Infos aus der Episodendatei rauslesen

	$episode_xml_zeile_episode = _ArraySearch($episoden_xml, $episode, -1, -1, -1, -1, 1) ; Nach Episodentitel-Zeile suchen, von oben nach unten
	if $episode_xml_zeile_episode == -1 then Ende("Die Episode mit dem Titel '"&$episode&"' konnte weder in der deutschen, noch der englischen Datenbank von TheTvDB.com gefunden werden.")
	w("gefunden! :)")
EndIf
FileDelete("episoden.xml")

$episode_nummer = (_StringBetween($episoden_xml[$episode_xml_zeile_episode + 1], ">", "</"))
$episode_nummer = $episode_nummer[0]

$episode_xml_zeile_season = _ArraySearch($episoden_xml, "<SeasonNumber>", $episode_xml_zeile_episode, -1, -1, 1, 1) ; Nach SeasonNumber suchen, von der Zeile mit dem Episodentitel aus abwδrts
$season_nummer = (_StringBetween($episoden_xml[$episode_xml_zeile_season], ">", "</"))
$season_nummer = $season_nummer[0]

w("    Staffel: " & @TAB & @TAB & $season_nummer)
w("    Episode: " & @TAB & @TAB & $episode_nummer)

;; Datei gemδί der όblichen Namenskonvention umbenennen; damit ist die Datei bereit zum scrapen durch andere Programme wie XBMC oder SickBeard
$neueDatei = $titel & " - " & $season_nummer & "x" & $episode_nummer & " - " & $episode & "." & $dateiendung

#region --- CodeWizard generated code Start ---
;MsgBox features: Title=Yes, Text=Yes, Buttons=Yes and No, Icon=Question
If Not IsDeclared("iMsgBoxAnswer") Then Local $iMsgBoxAnswer
$iMsgBoxAnswer = MsgBox(36, $productname, "Die Verarbeitung ist abgeschlossen. Der empfohlene Dateiname lautet:" & @CRLF & @CRLF & $neueDatei & @CRLF & @CRLF & "Soll die Datei umbenannt werden?")
Select
	Case $iMsgBoxAnswer = 6 ;Yes
		FileMove($pfad, $neueDatei)
	Case $iMsgBoxAnswer = 7 ;No

EndSelect
#endregion --- CodeWizard generated code Start ---


