# Optimierung der Datenintegration und Analyse hochteurer Medikamente im SwissDRG-System

## Einleitung

Christian Franke hat im erstem Halbjahr 2025 eine Bachelor-Thesis im Studiengang Medizininformatik an der Berner Fachhochschule durchgeführt. Das Ziel war es, diverse Medikamentendaten in eine übersichtliche Datenbank zu vereinen. Als Datenbank wurde die Graph-Datenbank Neo4j verwendet. Die SwissDRG AG hat das Projekt in Auftrag gegeben.

## Neo4j

[Neo4j](https://neo4j.com) gehört zu den bekanntesten Graph-Datenbanken. Im Rahmen der Bachelorarbeit wurde Neo4j 5.26.1 verwendet. Die Entwicklung erfolgte in Neo4j Desktop mit der Neo4j 5.26.1 Enterprise Datenbank. Zudem wurde die Cloud-Lösung Neo4j Aura sowie eine dockerisierte Datenbank in der Community Edition verwendet.

Lade Neo4j (5.26.1 Community Edition) in die Docker-Umgebung
```
docker pull neo4j:5.26.1
```

Starte die Neo4j Datenbank

```
docker run -d \
    --name=swissdrg \
    --restart always \
    --publish=7474:7474 --publish=7687:7687 \
    --env NEO4J_AUTH=neo4j/medikamente \
    --volume=/home/user/neo4j:/data \
    neo4j:5.26.1
```

## Daten in die DB laden

Die Daten werden in zwei Schritten in die Graph-Datenbank geladen. Zunächst muss das Preprocessing ausgeführt werden. Dabei handelt es sich um mehrere R-Skripte sowie ein Python-Skript, das die Daten als csv-Datei in einen Import-Ordner speichert. Das Cypher-Skript, mit dem die Knoten und Relationen in Neo4j erstellt werden, bezieht die Daten entweder aus dem Import-Ordner oder den Internet-Quellen.

Der Ordner Resources `./src/resources` dient einerseits als Zwischenspeicher für Dateien, die im Rahmen des Preprocessing aus dem Internet heruntergeladen werden. Andererseits sind zwei manuell aufbereitete Dateien zu den Anträgen (`proposals Medi.xlsx` und `proposals ZE.xlsx`) sowie eine Datei zu den Zusatzentgelten von TARPSY/ST Reha (`ZE_tarpsy_reha.csv`) vorhanden. Die ZE-Datei kann im internen Betrieb durch andere Quellen ersetzt werden, die die Daten automatisiert aufbereiten.

### Preprocessing

- Pfad der Skripte: `./src/main/preprocessing`
- Inputs: Internet oder `./src/resources`
- Outputs: `./src/main/import`
- Skripte
  - `02_technisches_begleitblatt.R`: die Daten der Excel-Datei "Technisches Begleitblatt 2025" werden von der SwissDRG Website heruntergeladen, für alle drei Sprachen (DE, FR, IT) aufbereitet und als csv-Datei `technisches_begleitblatt.csv` gespeichert
  - `03_zusatzentgelte.R`: der Zusatzentgelt-Katalog wird als zip-Datei von der SwissDRG Website heruntergeladen, die definitions-csv-Datei extrahiert, relevante Daten der Zusatzentgelte aufbereitet, mit den Zusatzentgelten von TARSPY und ST Reha ergänzt und als csv-Datei `ze_definitions.csv` gespeichert
  - `04_ema_produkte.R`: eine aktuelle Excel-Datei mit Medikamenten-Daten der Europäischen Arzneimittelagentur (EMA) wird von der EMA-Website heruntergeladen, aufbereitet, nur die zugelassenen Humanarzneimittel gefiltert, wenige alte (falsche) ATC-Codes korrigiert und als csv-Datei `ema_products.csv` gespeichert
  - `05_refdata.R`: die strukturierten Arzneimittelinformationen der Stiftung Refdata werden als zip-Datei von der SAI-Platform heruntergeladen. Für monatliche Updates muss der Download-Link angepasst werden, weil sich der Download-Link immer nur auf einen spezifischen Monat bezieht. Das R-Skript extrahiert zwei XML-Dateien (Präparate und Adressen), erstellt ein Data-Frame der Daten, korrigiert mehrere alte (falsche) ATC-Codes, fügt den Firmennamen der Zulassunginhaberin zu den Präparaten hinzu und speichert das Ergebnis als csv-Datei `sai_praeparate.csv`
  - `06_parse_atc_ddd.py`: das Python-Skript führt ein Webscraping der Seite `https://atcddd.fhi.no/atc_ddd_index` durch, auf dem die ATC-Codes gemäss Weltgesundheitsorganisation (WHO) veröffentlicht sind. In einem rekursiven Verfahren wird der ATC-Index von der obersten Hierarchiestufe bis zur detailliertesten Hierarchiestufe gescraped. Aufgrund der Nutzungsbestimmungen wurde der Befehl `time.sleep(10)` eingefügt, sodass zwischen den Webseitenaufrufen zehn Sekunden gewartet wird. Ohne `time.sleep(10)` dauert das Webscraping ca. 5 Minuten. Es werden zwei csv-Dateien erstellt mit der ATC-Hierarchie (`atc_list.csv`) und den Angaben der Defined Daily Dose (DDD, `atc_ddd.csv`)
  - `07_bag_sl.R`: die aktuelle Excel-Datei der Spezialitätenliste (SL) des Bundesamt für Gesundheit (BAG) wird von der SL-Website heruntergeladen, leicht aufbereitet und die relevanten Spalten als csv-Datei `sl.csv` gespeichert
  - `09_antraege.R`: die beiden manuell erstellten und aufbereiteten Excel-Dateien `proposals Medi.xlsx` und `proposals ZE.xlsx` werden als eine gemeinsame csv-Datei `antraege.csv` gespeichert
- Aktualisierungsfrequenz:
  - Monatlich
    - `04_ema_produkte.R` (Dauer: weniger als 1 Minute)
    - `05_refdata.R` (Dauer: weniger als 10 Minuten, Link muss aktualisiert werden)
    - `07_bag_sl.R` (Dauer: weniger als 1 Minute)
  - Jährlich
    - `02_technisches_begleitblatt.R` (Link muss aktualisiert werden)
    - `03_zusatzentgelte.R` (Link muss aktualisiert werden)
    - `06_parse_atc_ddd.py` (Dauer: weniger als 10 Minuten ohne `time.sleep(10)`)
    - `09_antraege.R` (manuelle Aufbereitung nötig)

### Cypher-Code

Nachdem die benötigten Dateien im Import-Ordner **der Neo4j-Datenbank** gespeichert wurden, kann das Cypher-Skript `create medi graph.cypher` im Ordner `./src/main` laufen gelassen werden. Das Skript kann wahlweise in die Neo4j-Browser-Umgebung kopiert oder mit Hilfe der VS Code Extension direkt gestartet werden.

Nachdem das Datenmodell erstellt wurde, sollten 13 Labels (Knoten-Typen) und 14 unterschiedlichen Relationen vorhanden sein. Die Zahl der Knoten sollte bei rund 20'000 und die Zahl der Relationen bei ca. 40'000 liegen. Das Datenmodells wird ausführlich im [Benutzerhandbuch](/doc/Benutzerhandbuch.MD) beschrieben.
