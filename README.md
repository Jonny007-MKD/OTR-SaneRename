OTR-SaneRenamix
===============

Benenne Serien mit OnlineTVrecorder Zeitstempeln nach Standard-Benennungen um.
Dies ist ein Linux-Bash-Fork von OTR-SaneRename von gersilex.

Hallo liebe Freunde,

ich stelle euch hier mein Programm vor, welches die heruntergeladenen Serien in üblichere, konforme Formate umbenennt, damit sie von anderen Programmen weiterverarbeitet, oder einfach nur sortierter gespeichert werden können.

Zum Hintergrund:

Ich bin großer Fan von Serien und nutze das XBMC (Media Center). Dieses analysiert die Titel der Dateien, und sortiert entsprechend alles in die richtigen Ordner, lädt Cover von allen Episoden herunter und stellt Infos, Beschreibungen usw zur Verfügung und pflegt es in die Programmeigene Serien-Abteilung ein (sowas wird Scrapen genannt). Das ist nicht nur praktisch, weil man dann alle Serien und Episoden in der richtigen Reihenfolge bequem vom Sofa aus sehen kann, sondern sieht auch noch hübsch aus:

Anhang 6278

Vorraussetzung ist eben, dass die Videodateien mit Name, Staffel und Episode gekennzeichnet sind. Und hier kommt mein (bis jetzt noch) kleines Programm ins Spiel:


Die Funktionen:

Das Tool analysiert den Dateinamen und liest Sendungsname, Datum und Zeit aus. Über das EPG von OTR wird dann aus der Kurzbeschreibung der Sendung der Episodentitel herausgefiltert. Das ist leider die einzige Info, die OTR an dieser Stelle liefert.
Glücklicherweise liefert aber die TVDB (www.tvdb.com) auch alle anderen Infos, darunter Episodennummer und Staffel. Also alles, was die Mediacenter oder sonstige weiterverarbeitende Scraper brauchen.

Aktuell funktioniert:
Infos auslesen, sofern der Dateiname mit dem Namen der Sendung anfängt
Titel, Staffelnummer, Episodennummer und Episodentitel aus den Datenbanken im Internet lesen
Einzelne Filmdatei umbenennen


Geplante Funktionen:
Massenverarbeitung
Verschieben in eine übersichtliche Ordnerstruktur
grafische Oberfläche (bereits teilweise vorhanden, man braucht keine Kommandozeilenkenntnisse!)
automatische Ordnerüberwachung
Senden an / Integration von automatischen schneide- und decodiertools


Folgendes ist neu in v0.2:
Erkennung von Dateinamen, die mit Zahlen (Cutlistnummern) beginnen. Alle nur-Zahlen-Felder vor dem Titel werden jetzt ignoriert.
Datum und Zeit werden mit regulären Ausdrücken gelesen und in ein "anständiges" Format umgeformt.
Falls kein Treffer vorhanden ist wird zusätzlich in der englischen TheTvDB.com gesucht. (Oft stehen im EPG vom OTR nur die englischen Titel der Episoden)
detailliertere Ausgabe
Fehlererkennungen



