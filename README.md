# Optimierung der Datenintegration und Analyse hochteurer Medikamente im SwissDRG-System

## Einleitung

Christian Franke hat im erstem Halbjahr 2025 eine Bachelor-Thesis im Studiengang Medizininformatik an der Berner Fachhochschule durchgeführt. Das Ziel war es, diverse Medikamentendaten in eine übersichtliche Datenbank zu vereinen. Als Datenbank wurde die Graph-Datenbank Neo4j verwendet. Die SwissDRG AG hat das Projekt in Auftrag gegeben.

Das Projekt wurde im Sommer 2025 erfolgreich abgeschlossen. Gewisse Details wurden diesem Repository nach Abgabe der Bachelorarbeit hinzugefügt. Die Weiterentwicklung ist weiterhin geplant, erfolgt jedoch nur noch sporadisch.

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

Die Datenverarbeitung ist nach dem Medaillon Data Pattern mit drei Schichten aufgebaut: Bronze, Silber und Gold. Im Bronze-Layer werden die Daten von den Quellen in einen lokalen Stagingbereich gespeichert. Im Silber-Layer werden die Daten weiter aufbereitet und als csv-Dateien in einem zweiten Stagingbereich abgelegt. Bronze und Silber sind "preprocessing" Schritte bevor das Graph-Datenmodell aufgebaut wird. Der Gold-Layer besteht aus dem Cypher-Script, der die Labels, Knoten und Relationen in der Neo4j Datenbank erstellt, einer Perspektive für NEo4j Bloom/Explore und dem eigentlichen Graph-Datenmodell.

### Aktualisierungsfrequenz

  - Monatlich
    - `04_ema_produkte.R` (Dauer: weniger als 1 Minute)
    - `05_refdata.R` (Dauer: weniger als 10 Minuten, Link muss aktualisiert werden)
    - `07_bag_sl.R` (Dauer: weniger als 1 Minute)
    - `11_gBA_nutzenbewertung.R` (Dauer: weniger als 5 Minuten, Dauerlink ggfs. aktualisieren, weil verfällt bei 3 Monaten Inaktivität)
    - `12_gBA_icd.R` (Dauer: weniger als 5 Minuten, Dauerlink ggfs. aktualisieren, weil verfällt bei 3 Monaten Inaktivität)
  - Jährlich
    - `01_hochteure_medis.R` (Link muss aktualisiert werden)
    - `02_technisches_begleitblatt.R` (Link muss aktualisiert werden)
    - `03_zusatzentgelte.R` (Link muss aktualisiert werden)
    - `06_parse_atc_ddd.py` (Dauer: weniger als 10 Minuten ohne `time.sleep(10)`)
    - `08_atc_alterations.R` (manuelle Aufbereitung nötig)
    - `09_antraege.R` (manuelle Aufbereitung nötig, `proposals Medi.xlsx` und `proposals ZE.xlsx`)

### Bronze-Layer

- Pfad der Skripte: `src/1 bronze/scripts`
- Inputs: Internet
- Outputs: `src/1 bronze/staging area`
- Skripte
  - `01_hochteure_medis.R`: die "Liste der hochteuren Medikamente/Substanzen" wird als csv-Datei von der Website der SwissDRG AG heruntergeladen. Die URL muss jährlich aktualisiert werden.
  - `02_technisches_begleitblatt.R`: die Excel-Datei "Technisches Begleitblatt" wird von der Website der SwissDRG AG heruntergeladen. Die URL muss jährlich aktualisiert werden.
  - `03_zusatzentgelte.R`: der Zusatzentgelt-Katalog wird als zip-Datei von der Website der SwissDRG AG heruntergeladen und die definitions-csv-Datei extrahiert. Die URL muss jährlich aktualisiert werden. Eine Datei zu den Zusatzentgelten von TARPSY/ST Reha (`ZE_tarpsy_reha.csv`) muss manuell erstellt werden.
  - `04_ema_produkte.R`: eine aktuelle Excel-Datei mit Medikamenten-Daten der Europäischen Arzneimittelagentur (EMA) wird von der EMA-Website heruntergeladen. Die Excel-Datei wird regelmässig aktualisiert. Die URL muss nicht geändert werden.
  - `05_refdata.R`: die strukturierten Arzneimittelinformationen der Stiftung Refdata werden als zip-Datei von der SAI-Platform heruntergeladen und zwei relevante XML-Dateien (Präparate und Adressen) extrahiert. Für monatliche Updates muss der Download-Link angepasst werden, weil sich der Download-Link immer nur auf einen spezifischen Monat bezieht.
  - `06_parse_atc_ddd.py`: Dummy-Datei ohne Datenaufbereitung. Siehe stattdessen `06_parse_atc_ddd.py` im Silber-Layer. Zukünftig soll das Webscraping durch den Download des ATC-Index von einem Terminologie-Server abgelost werden.
  - `07_bag_sl.R`: die aktuelle Excel-Datei der Spezialitätenliste (SL) des Bundesamt für Gesundheit (BAG) wird von der (alten) SL-Website heruntergeladen. Die Excel-Datei wird monatlich aktualisiert. Mit der neuen SL-Platform muss die URL zukünftig wahrscheinlich angepasst werden.
  - `08_atc_alterations.R`: Dummy-Datei ohne Datenaufbereitung.
  - `09_antraege.R`: Dummy-Datei ohne Datenaufbereitung. Eine manuelle Datenaufbereitung ist nötig, um  `proposals Medi.xlsx` und `proposals ZE.xlsx` zu erstellen.
  - `11_gBA_nutzenbewertung.R` und `12_gBA_icd.R`: die aktuelle maschinenlesbare Fassung der Beschlüsse zur Nutzenbewertung von Arzneimitteln des deutschen, gemeinsamen Bundesauschuss wird heruntergeladen. Der Link zum Download ist zwar ein Dauerlink, aber er verfällt nach drei Monaten Inaktivität.

### Silber-Layer

- Pfad der Skripte: `src/2 silver/scripts`
- Inputs: `src/1 bronze/staging area`
- Outputs: `src/2 silver/staging area`
- Skripte
  - `01_hochteure_medis.R`: die "Liste der hochteuren Medikamente/Substanzen" wird unverändert kopiert.
  - `02_technisches_begleitblatt.R`: die Excel-Datei wird für alle drei Sprachen (DE, FR, IT) aufbereitet und als csv-Datei `technisches_begleitblatt.csv` gespeichert.
  - `03_zusatzentgelte.R`: relevante Daten des aktuellen Zusatzentgelt-Kataloges (definitions-Datei) werden aufbereitet, mit den Zusatzentgelten von TARSPY und ST Reha ergänzt und als csv-Datei `ze_definitions.csv` gespeichert.
  - `04_ema_produkte.R`: es werden nur die zugelassenen Humanarzneimittel gefiltert, wenige alte (falsche) ATC-Codes korrigiert und als csv-Datei `ema_products.csv` gespeichert.
  - `05_refdata.R`: aus zwei XML-Dateien (Präparate und Adressen) werden relevante Daten extrahiert, ein Data-Frame der Daten erstellt, mehrere alte (falsche) ATC-Codes korrigiert, Firmennamen der Zulassunginhaberin zu den Präparaten hinzugefügt und als csv-Datei `sai_praeparate.csv` gespeichert.
  - `06_parse_atc_ddd.py`: das Python-Skript führt ein Webscraping der Seite `https://atcddd.fhi.no/atc_ddd_index` durch, auf dem die ATC-Codes gemäss Weltgesundheitsorganisation (WHO) veröffentlicht sind. In einem rekursiven Verfahren wird der ATC-Index von der obersten Hierarchiestufe bis zur detailliertesten Hierarchiestufe gescraped. Aufgrund der Nutzungsbestimmungen wurde der Befehl `time.sleep(10)` eingefügt, sodass zwischen den Webseitenaufrufen zehn Sekunden gewartet wird. Ohne `time.sleep(10)` dauert das Webscraping ca. 5 Minuten. Es werden zwei csv-Dateien erstellt mit der ATC-Hierarchie (`atc_list.csv`) und den Angaben der Defined Daily Dose (DDD, `atc_ddd.csv`).
  - `07_bag_sl.R`: die aktuelle Excel-Datei der Spezialitätenliste (SL) des Bundesamt für Gesundheit (BAG) wird leicht aufbereitet und nur die relevanten Spalten als csv-Datei `sl.csv` gespeichert.
  - `08_atc_alterations.R`: Die Datei "atc_alterations.csv" wird unverändert kopiert.
  - `09_antraege.R`: die beiden manuell erstellten und aufbereiteten Excel-Dateien `proposals Medi.xlsx` und `proposals ZE.xlsx` werden als eine gemeinsame csv-Datei `antraege.csv` gespeichert.
  - `11_gBA_nutzenbewertung.R` und `12_gBA_icd.R`: die XML-Strukturen werden in jeweils eine Tabelle umgewandelt und als csv-Datei `gBA_nutzenbewertung.csv` sowie `gBA_icd.csv` (für Indikationen) gespeichert.

### Gold-Layer

- Pfad: `src/3 gold`
- Inputs: `src/2 silver/staging area`
- Outputs: Neo4j Datenbank
- Skript: `create medi graph.cypher`

Die benötigten Dateien der Silver-Staging-Area können bei Bedarf im Import-Ordner **der Neo4j-Datenbank** gespeichert wurden (Import-Anweisung `WITH '../import/filename.csv' AS import` mit eigenem Pfad anpassen). Das Cypher-Skript `create medi graph.cypher` läd die Daten aus der Silver-Staging-Area dieses GitHub-Repositories. Das Skript kann wahlweise in die Neo4j-Browser-Umgebung kopiert oder mit Hilfe der VS Code Extension direkt gestartet werden.

Nachdem das Datenmodell erstellt wurde, müssen 12 Labels (Knoten-Typen) und 15 unterschiedlichen Relationen vorhanden sein. Die Zahl der Knoten sollte bei rund 30'000 und die Zahl der Relationen bei rund 50'000 liegen. Das Datenmodells wird ausführlich im [Benutzerhandbuch](/doc/Benutzerhandbuch.MD) beschrieben.
