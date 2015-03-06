OTR-SaneRenamix
===============

Benenne Serien mit OnlineTVrecorder Zeitstempeln nach Standard-Benennungen um.
Dies ist ein Linux-Bash-Fork von OTR-SaneRename von gersilex (https://github.com/gersilex/OTR-SaneRename).

Zum Hintergrund:

Ich bin (ebenfalls) großer Fan von Serien und nutze Kodi (das Media Center). Dieses analysiert die Titel der Dateien, und sortiert entsprechend alles in die richtigen Ordner, lädt Cover von allen Episoden herunter und stellt Infos, Beschreibungen usw zur Verfügung und pflegt es in die Programmeigene Serien-Abteilung ein (sowas wird Scrapen genannt). Vorraussetzung ist, dass die Videodateien mit Name, Staffel und Episode gekennzeichnet sind. Und hier kommt mein dieses Programm ins Spiel. Ich habe die Regeln von gersilex abgeleitet, in Bash implementiert und erweitert.


Die Funktionen:

Das Tool analysiert den Dateinamen und liest Sendungsname, Datum und Zeit aus. Über das EPG von OTR wird dann aus der Kurzbeschreibung der Sendung der Episodentitel herausgefiltert. Das ist leider die einzige Info, die OTR an dieser Stelle liefert.
Glücklicherweise liefert aber die TVDB (www.tvdb.com) auch alle anderen Infos, darunter Episodennummer und Staffel. Also alles, was weiterverarbeitende Scraper brauchen.

Aktuell funktioniert:
* Infos auslesen, sofern 
  * der Dateiname mit dem Namen der Sendung anfängt
  * oder Staffel- und Episodennummer am Anfang des Dateinamens stehen (S00_E00_blabla)
* Serienname, Staffelnummer, Episodennummer und Episodentitel aus der TvDB lesen
* Name für Filmdatei zurück geben
* Alternative Suche in der englischen TvDB


Geplant ist weiterhin:
* Den Episodentitel aus Dateinamen übernehmen (falls vorhanden, z.B. Mankell's Wallander)
* Erfolgsquote erhöhen
