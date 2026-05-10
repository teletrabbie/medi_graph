// Load all data into Neo4j
// Cypher code for Neo4j version 5



// Part 1: Liste der hochteuren Medikamente/Substanzen
// Load data from input list
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/hochteure_medis.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

WITH row,
     CASE 
         WHEN row.addition IS NOT NULL THEN split(row.addition, ',')
         ELSE []
     END AS additions,
     CASE 
         WHEN row.application IS NOT NULL THEN split(row.application, ',')
         ELSE []
     END AS applications,
     CASE 
        WHEN row.tariff = 'T' THEN ['Tarpsy']
        WHEN row.tariff = 'TR' THEN ['Tarpsy', 'ST Reha']
        WHEN row.tariff IS NULL OR trim(row.tariff) = '' THEN ['Alle']
        ELSE []
     END AS tariffs

// Create compound node with properties
MERGE (s:Substanz {Name: row.atc_code})
    SET
    s.Bezeichnung=row.compound_de,
    s.`Bezeichnung FR`=row.compound_fr,
    s.`Einschränkung`=row.constraints_de,
    s.`Einschränkung FR`= row.constraints_fr,
    s.`Einschränkung IT`= row.constraints_it,
    s.`Zu erfassen seit`= toInteger(row.since)

// Create and relate tariff nodes
FOREACH (tariff IN tariffs |
    MERGE (t:Tarif {Name: trim(tariff)})
    MERGE (s)-[:GILT_FUER_TARIF]->(t)
)

// Create and relate addition nodes
FOREACH (addition IN additions |
    MERGE (add:Zusatzangabe {Name: trim(addition)})
    MERGE (s)-[:HAT_ZA]->(add)
)

// Create and relate application nodes
FOREACH (application IN applications |
    MERGE (app:Verabreichungsart {Name: trim(application)})
    MERGE (s)-[:HAT_VA]->(app)
)

// Create and relate unit node
MERGE (unit:Einheit {Name: row.unit})
MERGE (s)-[:HAT_EINHEIT]->(unit)
;


// Create constraints in database
CREATE CONSTRAINT Substanz_Bezeichnung IF NOT EXISTS
FOR (x:Substanz) 
REQUIRE x.Bezeichnung IS UNIQUE 
;


// Constraint for ATC-Code
CREATE CONSTRAINT Substanz_ATC IF NOT EXISTS
FOR (x:Substanz) 
REQUIRE x.Name IS UNIQUE
;



// Part 2: Add description from "Technisches Begleitblatt" for Verabreichungsart, Einheit and Tarif
// Verabreichungsart
UNWIND [
  {lang: 'de', suffix: 'Bezeichnung'},
  {lang: 'fr', suffix: 'Bezeichnung FR'},
  {lang: 'it', suffix: 'Bezeichnung IT'}
] AS langInfo
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/technisches_begleitblatt.csv' AS row
MATCH (n:Verabreichungsart {Name: row.kuerzel})
WHERE langInfo.lang = row.sprache
SET n[langInfo.suffix] = row.kuerzel_bezeichnung
;


// Einheit (Bezeichnung)
UNWIND [
  {lang: 'de', suffix: 'Bezeichnung'},
  {lang: 'fr', suffix: 'Bezeichnung FR'},
  {lang: 'it', suffix: 'Bezeichnung IT'}
] AS langInfo
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/technisches_begleitblatt.csv' AS row
MATCH (n:Einheit {Name: row.kuerzel})
WHERE langInfo.lang = row.sprache
SET n[langInfo.suffix] = row.kuerzel_bezeichnung
;

// Einheit (Hinweis)
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/technisches_begleitblatt.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row
MATCH (n:Einheit)
WHERE n.Name=row.kuerzel AND 'de'= row.sprache AND 'NA'<> row.hinweis
SET n.Hinweis = row.hinweis
;


// Zusatzangabe (Bezeichnung)
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/technisches_begleitblatt.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row
MATCH (n:Zusatzangabe)
WHERE n.Name=row.kuerzel AND 'de'=row.sprache
SET n.Bezeichnung = row.kuerzel_bezeichnung
;

// Zusatzangabe (Hinweis)
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/technisches_begleitblatt.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row
MATCH (n:Zusatzangabe)
WHERE n.Name=row.kuerzel AND 'de'= row.sprache AND 'NA'<> row.hinweis
SET n.Hinweis = row.hinweis
;



// Part 3: Liste der Zusatzentgelte (ZE, supplements, supplementary charges)
// Load data and create node for ZE with properties
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/ze_definitions.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

MERGE (z:Zusatzentgelt {Name: row.ze_id})
    SET
    z.`ZE-Nr` = toInteger(row.ze_nr),
    z.ATC = row.code,
    z.Version = row.version,
    z.`ZE-Code` = row.ze_code,
    z.Zusatzangabe = row.za,
    z.Einheit = row.dose_unit,
    z.Verabreichungsart = row.va,
    z.url = CASE 
        WHEN substring(row.version,0,1)='V' 
        THEN 'https://manual.swissdrg.org/de/'+replace(row.version,'V','')+'/supplements/'+row.ze_code
        END
;


// Create relationship between Substanz and ZE
match (z:Zusatzentgelt)
match (s:Substanz)
where z.ATC = s.Name
merge (s)-[r:HAT_ZE]-(z)
;


// Create relationship between ZE and Einheit
match (z:Zusatzentgelt)
match (e:Einheit)
where z.Einheit = e.Name
merge (z)-[r:HAT_EINHEIT]->(e)
;


// Create relationship between ZE and Zusatzangabe
match (z:Zusatzentgelt)
match (a:Zusatzangabe)
where z.Zusatzangabe = a.Name
merge (z)-[r:HAT_ZA]->(a)
;


// Create relationship between ZE and Verabreichungsart
match (z:Zusatzentgelt)
unwind split(z.Verabreichungsart,",") as vas
match (v:Verabreichungsart {Name: vas})
merge (z)-[:HAT_VA]->(v)
;


// Create relationship between ZE and Tarif
match (n:Zusatzentgelt)
with n, case
    WHEN left(n.`ZE-Code`,1) = 'T' THEN 'Tarpsy'
    WHEN left(n.`ZE-Code`,1) = 'R' THEN 'ST Reha'
    WHEN left(n.`ZE-Code`,1) = 'Z' THEN 'Alle'
    end as tariff
match (t:Tarif {Name: tariff})
merge (n)-[g:GILT_FUER_TARIF]->(t)
;



// Part 4: Implement product information from EMA (European Medicines Agency)
// Create Präparat nodes
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/ema_products.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

MERGE (p:Präparat {Name: lower(row.product_name)})
    SET p.Mesh = row.mesh,
        p.Indikation = row.indication,
        p.Zulassungsinhaberin = row.company,
        p.`Orphan Status` = row.orphan,
        p.Generikum = row.generic,
        p.Biosimilar = row.biosimilar,
        p.url = row.url,
        p.`ATC-EMA` = row.atc,
        p.`Aktive Substanz EMA` = row.substance
;


// Create Substanz nodes and relationships to Präparat nodes by ATC code
MATCH (p:Präparat)
MATCH (s:Substanz {Name: p.`ATC-EMA`})
MERGE (p)-[:HAT_ATC {Quelle: 'EMA'}]->(s)
;


// Create Indikation nodes and relationships to Präparat nodes
MATCH (n:Präparat)
UNWIND (split(lower(n.Mesh), ';')) as mesh_terms
MERGE (m:Indikation {Name: mesh_terms})
MERGE (n)-[:INDIZIERT_FUER {Quelle: 'EMA'}]->(m)
;




// Part 5: Load structured refdata information (SAI) of level "Präparate" to Präparat nodes
// Create Präparat nodes with short "Praep_Name"
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/sai_praeparate.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR ','

MERGE (p:Präparat {Name: row.Praep_Name})
    SET p.Zulassungsnummer = row.ZULASSUNGSNUMMER,
        p.`ATC-SAI` = row.ATC_CODE,
        p.IT = row.IT_NUMMER,
        p.Anwendungsgebiet = row.ANWENDUNGSGEBIET,
        p.Erstzulassung = row.ERSTZULASSUNGSDATUM,
        p.Zulassungsinhaberin = row.ZULASSUNGSINHABERIN,
        p.Praeparatename = row.PRAEPARATENAME
;


// Create Präparat nodes in case there are multiple products with the same name
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/sai_praeparate.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR ','

WITH row WHERE tointeger(row.anz) > 1
MERGE (p:Präparat {Name: row.PRAEPARATENAME})
    SET p.Zulassungsnummer = row.ZULASSUNGSNUMMER,
        p.`ATC-SAI` = row.ATC_CODE,
        p.IT = row.IT_NUMMER,
        p.Anwendungsgebiet = row.ANWENDUNGSGEBIET,
        p.Erstzulassung = row.ERSTZULASSUNGSDATUM,
        p.Zulassungsinhaberin = row.ZULASSUNGSINHABERIN,
        p.Praeparatename = row.Praep_Name
;


// Index for Präparat-Names to search for strings in Bloom/Explore
CREATE TEXT INDEX Praeparat_text_index_name IF NOT EXISTS
FOR (n:Präparat) ON (n.Name)
;


// Relationship between Präparat nodes with the same name but different PRAEPARATENAME
MATCH (p:Präparat)
MATCH (q:Präparat {Name: p.Praeparatename})
WHERE p.Name <> q.Praeparatename
MERGE (p)-[:IST_AUCH_PRÄPARAT]->(q)
;


// Create Präparat nodes and relationships to Substanz nodes by ATC code
MATCH (p:Präparat)
MATCH (s:Substanz {Name: p.`ATC-SAI`})
MERGE (p)-[:HAT_ATC {Quelle: 'SAI'}]->(s)
;


// Create Indication nodes and relationships to Präparat nodes -> "Anwendungsgebiet" also stays property of Präparat node
MATCH (n:Präparat)
UNWIND (split(lower(n.Anwendungsgebiet), ';')) as Anwendungsgebiete
MERGE (m:Indikation {Name: Anwendungsgebiete})
MERGE (n)-[:INDIZIERT_FUER {Quelle: 'SAI'}]->(m)
;



// Indirect relation between Präparat and Präparat with "long" name and same Indikation
MATCH (i:Indikation)<-[:INDIZIERT_FUER]-(p:Präparat)-[:IST_AUCH_PRÄPARAT]->(d:Präparat)
MERGE (d)-[:INDIZIERT_FUER {Quelle: 'Ist auch Präparat'}]->(i)
;


// Remove "double" INDIZIERT_FUER relationships
MATCH (i:Indikation)<-[s:INDIZIERT_FUER {Quelle:'SAI'}]-(p:Präparat)-[a:INDIZIERT_FUER {Quelle: 'Ist auch Präparat'}]->(i)
DELETE s
;


// Remove Indikation nodes without Name property content
MATCH (i:Indikation)
WHERE i.Name = ""
DETACH DELETE i
;


// Remove "double" HAT_ATC relationships and merge them into one with the property "EMA+SAI"
MATCH (p:Präparat)-[a:HAT_ATC {Quelle: 'SAI'}]->(s:Substanz)<-[b:HAT_ATC {Quelle: 'EMA'}]-(p)
MERGE (p)-[:HAT_ATC {Quelle: 'EMA+SAI'}]->(s)
DELETE a,b
;



// Part 6: ATC Index (WHO ATC Hierarchy) and DDD (Defined Daily Dose) information
// Match Medi-Liste Substanz and ATC Nodes of WHO
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/atc_list.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

WITH row where toInteger(row.level) = 7
MERGE (s:Substanz {Name: row.atc_code})
    SET
    s.Level = toInteger(row.level),
    s.`Bezeichnung EN` = row.atc_name
;


// Create nodes for WHO ATC Hierarchy
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/atc_list.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

WITH row where toInteger(row.level) < 7
MERGE (h:Hierarchie {Name: row.atc_code})
    SET
    h.`Bezeichnung EN` = row.atc_name,
    h.Level = toInteger(row.level)
;


// Substances of "old" Medi-Lists which are not in the current Medi-List will get a own property
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/geloeschte_substanzen.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR ';'

MATCH (h:Substanz)
WHERE h.Name = row.atc_del_substance
SET h.`War auf Medi-Liste bis und mit Jahr`=toInteger(row.bis_jahr)
;


// Relationships between hierarchy levels (1 and 3)
MATCH (l:Hierarchie {Level: 3})
MATCH (h:Hierarchie {Name: substring(l.Name,0,1)})
MERGE (l)-[:IST_IN_ATC_GRUPPE]->(h)
;


// Relationships between hierarchy levels (3 and 4)
MATCH (l:Hierarchie {Level: 4})
MATCH (h:Hierarchie {Name: substring(l.Name,0,3)})
MERGE (l)-[:IST_IN_ATC_GRUPPE]->(h)
;


// Relationships between hierarchy levels (4 and 5)
MATCH (l:Hierarchie {Level: 5})
MATCH (h:Hierarchie {Name: substring(l.Name,0,4)})
MERGE (l)-[:IST_IN_ATC_GRUPPE]->(h)
;


// Relationships between subtance and hierarchy level 5
MATCH (l:Substanz)
MATCH (h:Hierarchie {Name: substring(l.Name,0,5)})
MERGE (l)-[:IST_IN_ATC_GRUPPE]->(h)
;


// Relationships between Präparat and Hierachy for the lowest level
MATCH (l:Präparat)
MATCH (n:Substanz {Name: l.`ATC-SAI`})  where n.`Zu erfassen seit` is null
MERGE (l)-[:HAT_ATC]->(n)
;


// And also for ATC code of EMA
MATCH (l:Präparat)
MATCH (n:Substanz {Name: l.`ATC-EMA`}) where n.`Zu erfassen seit` is null
MERGE (l)-[:HAT_ATC]->(n)
;


// Relationship als "Flag" for Substance weather it is on Medi-Liste or not
MATCH (n:Substanz) where n.`Zu erfassen seit` is null
MERGE (n)-[:NICHT_AUF_MEDI_LISTE]->(n)
;


// URL to Compendium (ATC-Group)
MATCH (n:Hierarchie)
SET n.url = 'https://compendium.ch/register/atc/' + n.Name
;


// URL to Compendium (ATC)
MATCH (n:Substanz)
SET n.url = 'https://compendium.ch/register/atc/' + n.Name
;


// Add DDD Information to Substanz nodes as value or as array
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/atc_ddd.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

MATCH (h:Substanz)
WHERE h.Name = row.`ATC code`
WITH h,
     CASE WHEN size(collect(row.U)) > 1 THEN collect(row.U) ELSE collect(row.U)[0] END AS U_R,
     CASE WHEN size(collect(row.`Adm.R`)) > 1 THEN collect(row.`Adm.R`) ELSE  collect(row.`Adm.R`)[0] END AS R_R,
     CASE WHEN size(collect(row.DDD)) > 1 THEN collect(row.DDD) ELSE toFloat(collect(row.DDD)[0]) END AS D_R
SET h.Unit = U_R,
    h.Route = R_R,
    h.DDD = D_R
;


// Add Note information from DDD
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/atc_ddd.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

MATCH (h:Substanz)
WHERE h.Name = row.`ATC code` AND row.Note <> ""
WITH h, CASE WHEN size(collect(row.Note)) > 1 THEN collect(row.Note) ELSE collect(row.Note)[0] END AS N_R
SET h.Note = N_R
;



// Part 7: Detailed package information from BAG Spezialitätenliste
// Create the Spezialitätenliste nodes
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/sl.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

MERGE (n:Spezialitätenliste {Name: row.bezeichnung})
    SET
    n.`ATC-SL` = row.atc,
    n.Zulassungsnummer = row.zulassungsnummer,
    n.GTIN = row.gtin,
    n.`Letzte Preis Änderung` = date(row.letzte_preis_anderung),
    n.ExFactoryPreis = toFloat(row.exf_preis),
    n.PublikumsPreis = toFloat(row.pub_preis),
    n.`Einfügedatum` = date(row.einf_datum),
    n.`Therapie-Gruppe` = row.therap_gruppe
;


// Create index for Spezialitätenliste (for better performance while adding Flag Preismodell)
CREATE INDEX SL_text_index_GTIN IF NOT EXISTS
FOR (n:`Spezialitätenliste`) ON (n.GTIN)
;


// Add Flag Preismodell for SL-products with "PM" in preismodell column
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/sl.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'
WITH row
WHERE row.preismodell = "PM"
MERGE (s:`Spezialitätenliste`{GTIN: row.gtin})
    SET s.`Flag Preismodell` = TRUE
;


// Create relationships between Präparat and Spezialitätenliste
MATCH (n:Präparat)
MATCH (s:Spezialitätenliste)
WHERE n.Zulassungsnummer = s.Zulassungsnummer
MERGE (n)-[:IST_AUF_SL]->(s)
;


// Indirect relationship from product to substance via ATC-SL, if it does not exist
MATCH (s:Substanz)
MATCH (p:Präparat)-[:IST_AUF_SL]->(l:`Spezialitätenliste`)
WHERE l.`ATC-SL` = s.Name
AND NOT EXISTS ((p)-[]->(s))
MERGE (p)-[:HAT_ATC {Quelle: 'SL'}]->(s)
;



// Part 8: WHO ATC code alterations as relationship of Substanz node to itself
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/atc_alterations.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR ';'

MATCH (s:Substanz {Name: row.`New ATC code`})
MERGE (s)-[:WAR_ATC_BIS {`Gültig bis und mit Jahr`: toInteger(row.`Year changed`)-1, `Früherer ATC`:row.`ATC code`}]->(s)
;


// Index to search for ATC code alterations -> no changes in bloom at the moment
CREATE TEXT INDEX war_atc_bis_text_index_atc IF NOT EXISTS
FOR ()-[x:WAR_ATC_BIS]-() on (x.`Früherer ATC`)
;


// Indirect relationship from product to substance via "Früherer ATC"
MATCH (s:Substanz)-[r:WAR_ATC_BIS]->(s)
MATCH (p:Präparat)
WHERE (p.`ATC-SAI` = r.`Früherer ATC` OR p.`ATC-EMA` = r.`Früherer ATC`)
AND NOT EXISTS ((p)-[]->(s))
MERGE (p)-[:HATTE_ATC {Quelle: 'Gemäss früherem ATC'}]->(s)
;



// Part 9: Import data of SwissDRG "Antragsverfahren"
// Property for Relationship because this information is a "meta information" and not directly from the "Antragsverfahren WebApp"
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/antraege.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

MATCH (s:Substanz {Name: row.aktueller_atc_code})
MERGE (a:Antrag {Antragsnummer: row.antragsnummer})
    SET
    a.Tarifsystem = row.tarifsystem,
    a.Status = row.status,
    a.Antragsjahr = toInteger(row.jahr),
    a.Partner = row.antragsberechtigte_partnerorganisation
MERGE (s)-[:HATTE_ANTRAG {Art: row.quelle}]->(a)
;


// Part 10: some manual inputs are made to the graph database
// Relations between nodes "Präparat" and "Zusatzangabe" according to "Technisches Begleitblatt"
MATCH (n:Präparat{Name: 'ventavis'})
MATCH (z:Zusatzangabe{Name: 'CVT'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'ilomedin'})
MATCH (z:Zusatzangabe{Name: 'CIM'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'alprolix'})
MATCH (z:Zusatzangabe{Name: 'CAI'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'idelvion'})
MATCH (z:Zusatzangabe{Name: 'CAI'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'refixia'})
MATCH (z:Zusatzangabe{Name: 'CAI'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'benefix'})
MATCH (z:Zusatzangabe{Name: 'CBB'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'immunine stim plus'})
MATCH (z:Zusatzangabe{Name: 'CBB'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'rixubis'})
MATCH (z:Zusatzangabe{Name: 'CBB'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'zavicefta'})
MATCH (z:Zusatzangabe{Name: 'CZC'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'zerbaxa'})
MATCH (z:Zusatzangabe{Name: 'CZB'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'epclusa'})
MATCH (z:Zusatzangabe{Name: 'CEP'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'vosevi'})
MATCH (z:Zusatzangabe{Name: 'CVO'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'maviret'})
MATCH (z:Zusatzangabe{Name: 'CMA'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'lonsurf'})
MATCH (z:Zusatzangabe{Name: 'CLS'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'qarziba'})
MATCH (z:Zusatzangabe{Name: 'CQZ'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'thymoglobuline'})
MATCH (z:Zusatzangabe{Name: 'CTG'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'grafalon'})
MATCH (z:Zusatzangabe{Name: 'CFR'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'zypadhera'})
MATCH (z:Zusatzangabe{Name: 'CZY'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'abilify maintena'})
MATCH (z:Zusatzangabe{Name: 'CAM'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'xeplion'})
MATCH (z:Zusatzangabe{Name: 'CXE'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'trikafta'})
MATCH (z:Zusatzangabe{Name: 'CTK'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'cayston'})
MATCH (z:Zusatzangabe{Name: 'CCS'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'azactam'})
MATCH (z:Zusatzangabe{Name: 'CAZ'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'livmarli'})
MATCH (z:Zusatzangabe{Name: 'CLM'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'emblaveo'})
MATCH (z:Zusatzangabe{Name: 'CEL'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'spectrila'})
MATCH (z:Zusatzangabe{Name: 'ACO'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'enrylaze'})
MATCH (z:Zusatzangabe{Name: 'ACY'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat{Name: 'pedmarqsi'})
MATCH (z:Zusatzangabe{Name: 'CPM'})
MERGE (n)-[:HAT_ZA]->(z)
;

MATCH (n:Präparat) WHERE n.Name STARTS WITH 'onivyde'
MATCH (z:Zusatzangabe{Name: 'CON'})
MERGE (n)-[:HAT_ZA]->(z)
;


// Part 11: Benefit Assessment of Medicinal Products by Federal Joint Committee on an Amendment of the Pharmaceuticals Directive (gBA Nutzenbewertung)
// Load data and create nodes
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/gBA_nutzenbewertung.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

MERGE (n:Nutzenbewertung {`Patientengruppe ID`: toInteger(row.ID_PAT_GR)})
SET n.URL = row.URL,
    n.Handelsname = row.NAME_HN,
    n.ATC = row.ATC,
    n.Wirkstoff = row.WS_BEW,
    n.Beschlussdatum = date(row.DATUM_BE_VOM),
    n.Vergleichstherapie = row.NAME_ZVT_BEST,
    n.Ausmass = row.ZVT_ZN_A,
    n.Wahrscheinlichkeit = row.ZVT_ZN_w
;


// Create relationship from Nutzenbewertung to ATC and/or Präparat
MATCH (n:Nutzenbewertung)
MATCH (s:Substanz {Name: n.ATC})
MERGE (s)-[:HAT_BEWERTUNG]->(n)
;

MATCH (n:Nutzenbewertung)
MATCH (p:Präparat {Name: lower(n.Handelsname)})
MERGE (p)-[:HAT_BEWERTUNG]->(n)
;


// Part 12: ICD diagnosis per product by Federal Joint Committee on an Amendment of the Pharmaceuticals Directive
// Load data and create nodes
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/gBA_icd.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

MERGE (n:Indikation {Name: row.NAME_ICD_GROUPED})
SET n.ICD = row.ID_ICD_GROUPED,
    n.FLAG_GBA = 'true'
;


// Create relationship from Präparat to Indikation
WITH 'https://raw.githubusercontent.com/teletrabbie/medi_graph/refs/heads/main/src/2 silver/staging area/gBA_icd.csv' AS import
LOAD CSV WITH HEADERS FROM import AS row FIELDTERMINATOR '|'

MATCH (p:Präparat {Name: lower(row.NAME_HN)})
MATCH (n:Indikation {ICD: row.ID_ICD_GROUPED})
MERGE (p)-[:INDIZIERT_FUER {Quelle: 'gBA'}]->(n)
;
