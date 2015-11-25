OTR-SaneRenamix
===============

Benenne Serien mit OnlineTVrecorder Zeitstempeln nach Standard-Benennungen um.
Dies ist ein Linux-Bash-Fork von OTR-SaneRename von gersilex (https://github.com/gersilex/OTR-SaneRename).

Zum Hintergrund:

Ich bin (ebenfalls) großer Fan von Serien und nutze Kodi (das Media Center). Dieses analysiert die Titel der Dateien, und sortiert entsprechend alles in die richtigen Ordner, lädt Cover von allen Episoden herunter und stellt Infos, Beschreibungen usw zur Verfügung und pflegt es in die Programmeigene Serien-Abteilung ein (sowas wird Scrapen genannt). Vorraussetzung ist, dass die Videodateien mit Name, Staffel und Episode gekennzeichnet sind. Und hier kommt dieses Programm ins Spiel. Ich habe die Regeln von gersilex abgeleitet, in Bash implementiert und erweitert.


Die Funktionen:

Das Tool analysiert den Dateinamen und liest Sendungsname, Datum und Zeit aus. Falls Serien- und Episodennummer nicht im Dateinamen angegeben wurde, wird Über das EPG von OTR und die Kurzbeschreibung der Sendung der Episodentitel extrahiert.
TheTvDB (www.thetvdb.com) liefert die dann die ordentlichen Namen für die Staffel und die Episode.
Die heruntergeladenen XML- und EPG-Dateien werden lokal gespeichert. Dies reduziert die Ausführzeit des Programms bei einem zweiten Aufruf auf ~15%.

Aktuell funktioniert:
* Infos auslesen, sofern 
  * der Dateiname mit dem Namen der Sendung anfängt
  * oder Staffel- und Episodennummer am Anfang des Dateinamens stehen (S00_E00_blabla_...)
  * oder Staffel- und Epsiodennummer nach dem Namen der Sendung stehen (blabla_S00E00_...)
* Serienname, Staffelnummer, Episodennummer und Episodentitel aus der TvDB lesen
* Name für Filmdatei zurück geben
* Alternative Suche in der englischen TvDB


Geplant ist weiterhin:
* Den Episodentitel aus Dateinamen übernehmen (falls vorhanden, z.B. Mankell's Wallander)
* Erfolgsquote erhöhen
