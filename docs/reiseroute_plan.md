# Reiseroute

Hält fest, wo ein Held wann war und was dort geschah: Stationen mit Ort,
aventurischem Datum, Abenteuerzuordnung und Notiz. Sie erscheinen als Zeitleiste
und später auf einer Aventurien-Karte.

## Stand

| Stufe | Inhalt | Status |
| --- | --- | --- |
| 0 | Anfrage an Avesmaps (Ortsverzeichnis, Kacheln, CORS, Namensnennung) | beantwortet (12.11.2026): Ortsdaten und Route ja, Kacheln nein |
| 1 | Stationsliste am Helden, Spielkachel „Reiseroute“, Blatt mit Zeitleiste | umgesetzt |
| 2 | Ortssuche mit Koordinaten, Reisewege, Karte mit Route und Pins | A2, A1, Tabellenansicht, Ortsdetails (D), Standort-Kachel und Aventurien-Karte im Avesmaps-Stil (C2, C3 vorbereitet) umgesetzt (13.11.2026); Reisewege (B2) umgesetzt (20.11.2026), Reiseplaner (B3) umgesetzt (21.11.2026), Kartenbild (C3) live (23.11.2026) |

## Stufe 1 (umgesetzt)

- **Modell:** `HeroReiseStation` (`lib/domain/hero_reise_station.dart`):
  `id`, `ort`, `datum` (`HeroAdventureDateValue`), `notiz`, `adventureId`,
  `ortId`, `kartenX`/`kartenY`, `lastModified`. Optionale Felder werden nur bei
  Belegung geschrieben. `HeroSheet.reiseStationen` wird nur bei nicht leerer
  Liste geschrieben, damit Bestandshelden ihren Inhalts-Hash behalten.
  Editorentwürfe gleichen je oberstem Schlüssel ab; die Stationsliste ist ein
  eigener Schlüssel und wird daher von Notizen- oder Übersichtsentwürfen nicht
  überschrieben.
- **Regeln:** `lib/rules/derived/reiseroute_rules.dart`.
  - Sortierung nach Kalender. Eine Station ohne Datum bleibt hinter ihrem
    Vorgänger in der Erfassung.
  - Etappen mit „+n Tage“ und Luftlinie (eine Karteneinheit entspricht drei
    Meilen).
  - Vorschlag für eine neue Station aus Standort, Abenteuerdatum und laufendem
    Abenteuer.
  - Listenänderungen per ID.
- **Oberfläche:**
  - `KartoSpielkachelArt.reiseroute` mit `KartoReiserouteKachel`: die drei
    jüngsten Stationen.
  - `zeigeReiseroute` öffnet `KartoReiserouteBlatt` mit Übersicht,
    Abenteuerfilter und Avesmaps-Link je Station.
  - Geschrieben wird nur über `KartoReiserouteSchreiben`: frisch per
    `updateHero`, gesperrt während einer Planung.
  - Ändert sich der Ortsname, verfällt die Kartenposition des alten Orts.
- **Tests:** `test/rules/derived/reiseroute_rules_test.dart`,
  `test/ui2/spielen/karto_reiseroute_test.dart`, Eintrag in
  `test/domain/unbekannte_verschachtelte_felder_test.dart`.

## Ortsauswahl aus der Wiki Aventurica (umgesetzt)

Standort und Station schlagen Orte aus `orte.json` vor (Siedlungen, Regionen,
Staaten, Flüsse, Straßen; auch „unterwegs durch …“). Das Verzeichnis ist ein
Snapshot der Wiki Aventurica (CC BY-SA), erzeugt von `tool/import_wiki_orte.py`,
siehe `docs/catalog_import_workflow.md`. Gespeichert wird weiter nur der Name als
Text; es gibt keine `ortId` und keine Koordinaten. Die Ortsauswahl
funktioniert damit ohne Netz; Koordinaten für Karte und Luftlinie kommen in
Stufe 2 aus Avesmaps.

## Avesmaps: Antwort und Schnittstelle (Stand 2026-11-12)

Anfrage und Antwort: github.com/valentin-schwind/avesmaps, Issue 7.

### Zusage

- **Ortsdaten:** Nutzung erlaubt. Die Ortsliste einmal täglich abrufen und
  lokal speichern ist ausdrücklich erwünscht. `id` und Koordinaten gewählter
  Orte dürfen im Heldendokument stehen; die `id` bleibt dauerhaft gleich.
- **Route:** Nutzung erlaubt. Je IP-Adresse gilt eine Drossel (`429` mit
  `Retry-After`); eine Abfrage je Nutzeraktion bleibt darunter. Zahlen nennt
  die Antwort nicht.
- **Kennung:** Die Apps sollen den User-Agent
  `DSA_HeroApp/1.0 (+https://github.com/DennisAdamski/DSA_HeroApp)` setzen. Im
  Web setzt der Browser seinen eigenen, das ist in Ordnung.
- **Kacheln:** keine Freigabe für fremde Apps (kleiner Server, Pfade ändern
  sich mit jeder Kartenfassung). Angebot: ein Schlüssel für die Karten-API,
  damit die Karte einmal als PNG geladen und selbst gehostet werden kann. Die
  Rechte dafür kommen nicht von Avesmaps, sondern unmittelbar aus der Lizenz
  des Ulisses-Kartenpakets (nicht-kommerziell, als Fanprojekt gekennzeichnet).
- **Namensnennung:** „Karte & Ortsdaten: Avesmaps (avesmaps.de)“ passt. Sobald
  die App selbst Kartenmaterial zeigt, zusätzlich: „Kartenmaterial © Ulisses
  Spiele · Originalkarte: Ina Kramer · Bearbeitung: Avesmaps
  (DSA-Fanprojekt)“. Rücklinks über `https://avesmaps.de/?siedlung=` mit dem
  Seitennamen aus `wiki.url` der Ortsdetails.
- **Nicht beantwortet:** ob die Ortsliste als Snapshot in der App oder im
  öffentlichen Repository ausgeliefert werden darf. Bestätigt ist nur das
  lokale Zwischenspeichern.

### Entwickler-API v1 (am 12.11.2026 geprüft)

Dokumentation: `docs/schnittstellen/entwickler-api.md` im Zweig `avesmaps3d`;
maschinenlesbar unter `GET https://avesmaps.de/api/v1/openapi.json`. Ohne
Schlüssel, jede Antwort trägt `Access-Control-Allow-Origin: *`. Die alte
Schnittstelle (`legacy.avesmaps.de/api/locations/`, `/api/route/`) antwortet
mit `410 api_gone`.

| Weg | Inhalt |
| --- | --- |
| `GET /api/v1/orte` | alle 5846 Orte mit `id` (UUID), `name`, `art`, `x`, `y`; 624 kB, gzip 241 kB; `Cache-Control: max-age=300`, kein ETag |
| `GET /api/v1/orte/{id}` | zusätzlich `wiki {url, titel}` und `gebiete` (Ketten vom Reich bis zur Baronie) |
| `GET /api/v1/suche?q=…&limit=…` | bis zu 20 Treffer, ab zwei Zeichen |
| `GET /api/v1/route?von=…&nach=…` | `meilen`, `reisestunden`, `reisetage`, `etappen[]` (Wegart, Reisemittel), `linie` als `[x, y]`-Punkte; `ueber=` mit `~` getrennt, höchstens zehn Halte; `optimierung`, `wege` |

- **Koordinaten:** 0 … 1024, Ursprung Südwest, `y` wächst nach Norden, eine
  Einheit sind drei Meilen. Das entspricht `kartenX`/`kartenY` und
  `kMeilenProKarteneinheit`.
- **Vertrag:** Felder kommen nur dazu. Unbekannte Werte von `art` und
  `hinweise` sind zu überspringen. Entschieden wird am Fehler-`code`, bei
  `429` am Status.
- **Reiserechnung:** Reisegruppe zu Fuß, Flusssegler, Lastensegler, acht
  Reisestunden je Tag. `gefunden: false` ist eine Antwort, kein Fehler.
- **Lizenz der Antworten:** nicht MIT, siehe dort `LEGAL.md` und `NOTICE.md`.
- **Karten-API** (`/api/v1/karten`, nur mit Schlüssel `Authorization: Bearer
  avk_…`, ohne CORS): Kartenserien als PNG im ZIP samt `LIZENZ.txt` und
  Fanprojekt-Logo. Der Schlüssel gehört nie in die App oder ins Repository.
- **Kartenpaket-Lizenz:** https://de.wiki-aventurica.de/wiki/Kartenpaket/Lizenz.
  Bedingungen: nur nicht-kommerziell, Bearbeitungen mit DSA-Fanprojekt-Logo,
  Lizenz oder ihre URI liegt bei, keine Unterlizenzen.

### Abgleich mit dem Ortsverzeichnis der Wiki Aventurica

`orte.json` hat 6417 Einträge, davon 2649 Siedlungen. 1768 dieser Siedlungen
(67 %) tragen denselben Namen wie ein Avesmaps-Ort. Rund 4040 Avesmaps-Orte
(meist Dörfer und Gebäude) fehlen im Wiki-Verzeichnis. Regionen, Staaten,
Flüsse und Straßen kennt nur das Wiki-Verzeichnis. In Avesmaps tragen 133
Namen einen Klammerzusatz („Auweiler (Darpatien)“), zwei Namen sind doppelt.

## Stufe 2: Möglichkeiten der Integration

Die Bausteine sind einzeln umsetzbar. Das Modell braucht für A, B und D kein
neues Feld: `ortId`, `kartenX` und `kartenY` gibt es an `HeroReiseStation`
bereits, sie werden nur bei Belegung geschrieben.

### A · Ortsdaten mit Koordinaten

| Variante | Inhalt | Bewertung |
| --- | --- | --- |
| A1 Online-Suche | Das Ortsfeld fragt `/suche` je Eingabe (entprellt). | Wenig Code, aber ohne Netz keine Position, eine Anfrage je Tastenpause, zweite Trefferliste neben dem Wiki-Verzeichnis. |
| **A2 Tagesliste lokal** | `/orte` höchstens einmal täglich laden, sobald der Nutzer ein Ortsfeld oder die Reiseroute öffnet; lokal ablegen (Hive-Box als JSON-Text). Die Auswahl mischt beide Verzeichnisse: Avesmaps liefert `ortId` und Position, das Wiki-Verzeichnis Region und Nicht-Siedlungen. | **Empfohlen.** Genau das zugesagte Verfahren, offline nutzbar nach dem ersten Abruf, eine Anfrage je Tag. |
| A3 Snapshot im Paket | Ortsliste als Asset ausliefern. | Von der Zusage nicht gedeckt (öffentliches Repository, Daten nicht frei lizenziert). Nur nach Rückfrage. |

Zu A2 gehört:

- Auswahl eines Avesmaps-Orts setzt `ortId`, `kartenX`, `kartenY`. Freitext und
  Wiki-Einträge ohne Gegenstück bleiben ohne Position. Die Luftlinie der
  Zeitleiste (`luftlinieMeilen`) wird damit ohne weitere Änderung sichtbar.
- Abgleich über `suchFaltung` des Namens; Klammerzusätze von Avesmaps bleiben
  im Vorschlag sichtbar, damit gleichnamige Orte unterscheidbar sind.
- „Position nachtragen“ für Bestandsstationen: Name gegen die Liste prüfen und
  bei genau einem Treffer anbieten, nie still schreiben.
- Ohne Liste (kein Netz, Abruf gescheitert) verhält sich das Ortsfeld wie
  heute.

### B · Wege und Reisezeiten

| Variante | Inhalt | Bewertung |
| --- | --- | --- |
| B1 Luftlinie | Bereits gerechnet, erscheint mit A2. | Kostenlos, aber fern vom Reiseweg. |
| **B2 Reiseweg der Route** | Knopf „Reiseweg berechnen“ im Blatt: `/route` über die Stationen mit Position (Start, Ziel und zehn Halte je Anfrage, längere Routen in Abschnitten). Je Etappe Meilen und Reisetage neben dem Kalenderabstand („+9 Tage · 365 Meilen, zu Fuß 6½ Tage“). | **Empfohlen** als zweiter Schritt. Eine Anfrage je Nutzeraktion. |
| B3 Reiseplaner | In der Spielansicht: vom Standort zu einem Ziel, mit `optimierung` und `wege`; Ergebnis Meilen, Reisetage, Wegarten, optional als neue Station übernehmen. | Hoher Spielwert, eigenständig, baut auf A2 und dem Client von B2 auf. |

Ergebnisse von `/route` gehören **nicht** ins Heldendokument (`linie` hat
schnell über 200 Punkte, und jedes neue Feld berührt Hash und Sync). Sie
liegen in einem lokalen Zwischenspeicher, Schlüssel sind die `ortId`-Folge und
die Parameter. Die Rechnung selbst bleibt bei Avesmaps; `reiseroute_rules.dart`
formatiert nur.

### C · Kartendarstellung

| Variante | Inhalt | Bewertung |
| --- | --- | --- |
| C1 Nur Rücklinks | Wie heute, Link je Station; mit D der genaue Seitenname. | Kein Aufwand, keine Karte in der App. |
| **C2 Routenskizze** | Eigene Zeichnung ohne Kartenbild: Stationen als nummerierte Pins, Verbindung als Luftlinie oder als `linie` aus B2, dazu Metropolen und Großstädte (43 Orte der Liste) als Anhaltspunkte. | **Empfohlen** vor C3. Keine Kartenrechte berührt, keine neue Abhängigkeit, läuft offline. Orientierung bleibt grob. |
| C3 Eigene Kacheln (umgesetzt, live seit 23.11.2026) | Karten-PNG mit Schlüssel einmal laden (lokales Werkzeug unter `tool/`, Schlüssel in gitignorierter Datei), in Kacheln schneiden, selbst hosten (Firebase Hosting oder Storage, damit ohne CORS- und CSP-Thema). Anzeige mit `flutter_map` und `CrsSimple`, Route und Pins darüber. | Volle Karte. Verlangt: Lizenz des Kartenpakets selbst prüfen, Logo, Lizenz-URI und Ulisses-Zeile in der Kartenecke und unter „Rechtliches“, Speicher- und Bandbreitenkosten, erneutes Schneiden bei neuer Kartenfassung. Kacheln nicht ins öffentliche Repository. |
| C4 Übersichtsbild | Ein verkleinertes Kartenbild (etwa 2048 px) als Hintergrund der Skizze aus C2. | Günstiger als C3 und offline, aber dieselben Lizenzpflichten; im App-Paket ausgeliefert heißt im Repository eingecheckt. Erst nach der Lizenzprüfung zu C3 entscheiden. |

### D · Ortsdetails

`/orte/{id}` bei der Auswahl oder beim Öffnen einer Station laden, lokal
zwischenspeichern:

- Gebietskette als Unterzeile („Kaisermark Gareth · Königreich Garetien“),
  auch für Orte, die das Wiki-Verzeichnis nicht kennt.
- Rücklink mit dem Seitennamen aus `wiki.url`, wie von Avesmaps gewünscht. Orte
  ohne Wiki-Seite bekommen keinen Link statt eines toten.

### A2 und A1 (umgesetzt 13.11.2026)

**Datenmodell.** Festgehalten wird je Station, wann der Held wo war und
wozu: `datum`, `ort`, `adventureId`, `notiz`. Der Ort ist verknüpft über
`ortId` (Avesmaps-`id`) und `kartenX`/`kartenY` als Schnappschuss bei der
Auswahl. Alle Felder gab es schon; am Heldendokument hat sich nichts geändert.
Der Standort im Zustand bleibt Text. Eine gespeicherte Verbindung zwischen
Stationen (Anreise mit Weglänge und Reisetagen) ist zurückgestellt, bis die
grafische Darstellung ansteht; bis dahin gilt die Luftlinie.

**Abruf.**

- `AvesmapsOrt` (`lib/domain/avesmaps_ort.dart`): `id`, `name`, `art`, `x`,
  `y`. Liegt nur im lokalen Zwischenspeicher, nie im Heldendokument.
- `AvesmapsClient` (`lib/data/avesmaps/avesmaps_client.dart`): `ladeOrte()`
  und `suche()`. Liest tolerant, setzt die Kennung nur außerhalb des Webs,
  meldet `429`/`503` samt `Retry-After` als `AvesmapsFehler` und wiederholt
  nichts von sich aus.
- `AvesmapsOrteRepository` mit `HiveAvesmapsOrteSpeicher` (Box
  `avesmaps_orte_v1` im Heldenspeicher): Liste höchstens einmal in 24 Stunden;
  nach einem Fehlschlag 15 Minuten Pause bzw. die Wartezeit des Servers;
  scheitert das Auffrischen, gilt die ältere Liste weiter.
- `lib/state/avesmaps_providers.dart`: `avesmapsAktivProvider` ist ohne
  Override aus (Tests fragen nie das Netz) und wird nur in
  `AppStartupGate._buildScope` eingeschaltet. Geladen wird erst nach
  `AvesmapsOrteAnforderung.fordereAn()`, also wenn ein Ortsfeld oder das
  Reiseroute-Blatt aufgeht. Jede erneute Anforderung prüft die Liste wieder;
  Tagescache und `Retry-After` bzw. die Fehlerpause bleiben im Repository
  wirksam. Nach einem Fehlschlag bleibt „Kartendaten laden“ bedienbar.
  Erfolgreiche Ortsdetails werden dabei nicht erneut geladen.

**Auswahl und Verweis.**

- `verbindeOrtsverzeichnisse` (`standort_rules.dart`) mischt beide
  Verzeichnisse zu `ortsverzeichnisProvider`: Wiki-Siedlungen bekommen
  Kennung und Position des gleichnamigen Avesmaps-Orts (voller Seitenname vor
  Name, nur eindeutig), übrige Avesmaps-Orte kommen als Siedlung dazu.
  Vorschläge mit Position tragen ein Kartensymbol.
- `ortsVerweisFuer` bestimmt beim Speichern den Verweis: der gewählte
  Vorschlag, sonst ein eindeutig gleicher Name (ohne Umlaut-Faltung).
  Gleichnamige Orte verknüpft nur die ausdrückliche Auswahl.
- Schreibregeln (`KartoReiserouteSchreiben`): Ein neuer Ortsname löst den
  alten Verweis. Bleibt der Name und liefert die Eingabe keinen Verweis (kein
  Netz), bleibt der bestehende. Eine unveränderte, bereits verknüpfte Station
  wird nicht neu geschrieben.
- A1: Solange die Liste angefordert, aber nicht vorhanden ist, fragt das
  Ortsfeld nach 400 ms Tipppause `/suche` und mischt die Treffer unter die
  lokalen Vorschläge (`avesmapsOnlineSucheProvider`). Mit lokaler Liste gibt es
  keine Suchanfragen. Enter übernimmt den aktuell hervorgehobenen Vorschlag
  auch aus der Online-Suche; erst eine weitere Eingabetaste schickt den
  übernommenen Namen ab. Die Standortdialoge in Abenteuer- und Standort-Kachel
  beobachten das laufende Verzeichnis, statt beim Öffnen eine Liste einzufrieren.

**Tabelle.** Das Reiseroute-Blatt zeigt die Stationen zuerst als Tabelle
(`KartoReiseTabelle`: Nummer, Datum mit Abstand zur vorigen Station, Ort,
Abenteuer, Notiz), umschaltbar auf die Zeitleiste. Unter 520 dp oder bei
Schrift über dem 1,3-Fachen steht die Notiz gekürzt unter dem Ort. Der Filter
nach Abenteuer gilt für beide Ansichten.

**Pflichtteile.** `connect-src` in `firebase.json` erlaubt
`https://avesmaps.de`. Quellenzeile `kOrtsdatenQuellen` im Blatt,
Lizenzeintrag „Avesmaps (Ortsdaten)“ (`avesmaps_lizenz.dart`),
Datenschutzerklärung Abschnitt 6 und Zeile im Verzeichnis der
Verarbeitungstätigkeiten (Art. 6 Abs. 1 lit. b DSGVO; das Kartenbild der
eigenen Kacheln lit. f).

**Tests.** `test/data/avesmaps/`, `test/state/avesmaps_providers_test.dart`,
`test/rules/derived/standort_rules_test.dart`,
`test/ui2/spielen/karto_reiseroute_test.dart`,
`test/ui2/spielen/karto_ort_feld_test.dart`.

**Offen.** Verweis am Standort (`HeroState`). Erledigt: Anreise zwischen
Stationen (B2), grafische Darstellung (C2) und die Sichtprüfung im Web gegen
die echte Schnittstelle (22.11.2026).

### Automatische Station beim Standortwechsel (umgesetzt 16.11.2026)

Ändert der Standort im Abenteuer-Bereich oder in der Standort-Kachel
(`standortSetzen`), legt die Brücke eine Station an: Ort, Datum und Abenteuer
aus `reiseStationFuerStandortwechsel` (`reiseroute_rules.dart`), Kartenverweis
nur bei eindeutigem Ort im Ortsverzeichnis. Keine Station entsteht beim
Entfernen des Standorts, ohne Ortswechsel und wenn die zeitlich letzte Station
schon diesen Ort trägt. Es sind zwei eigenständige Schreibvorgänge mit je einem
Dokument: erst `HeroState.standort`, dann `HeroSheet.reiseStationen`. Scheitert
der zweite (etwa während einer Planung), bleibt der Standort gespeichert und
eine Meldung nennt den Grund.

### Standort-Kachel und Ortsdetails (umgesetzt 13.11.2026)

**Vorbild.** Die Ortsansicht von avesmaps.de, aus dem ausgelieferten Bundle
gelesen (Vue + MapLibre, `main-*.js`, `gemeinsam-*.js`, `main-*.css`; nichts
ausgeführt): Infotafel 400 px breit, Bezeichnungsspalte 96 px,
Kartenvorschau 116×72; Kopf mit Bild/Wappen, Titel und Untertitel, Fakten als
Bezeichnung/Wert-Liste, „In der Nähe“, Aktionen („Reiseziel hinzufügen“,
„Link teilen“). Die Siedlungsfakten der Seite (Einwohner, Oberhaupt,
Handelszone, Verkehrswege, Tempel …) kommen aus internen Schnittstellen und
dem Wiki-Infokasten, nicht aus der API v1, und werden nicht übernommen.
Rücklink-Regel der Seite: Seitenname hinter `/wiki/` aus `wiki.url` als
`?siedlung=`, ohne Artikel `?place=<id>`.

**Umsetzung.**

- `AvesmapsClient.ladeOrt` (`/orte/{id}`, 404 und ungültige Kennung ergeben
  `null`), Modell `AvesmapsOrtsdetails`/`AvesmapsGebiet` nur im Speicher.
- `avesmapsOrtsdetailsProvider` je Ort einmal pro Sitzung, nur nach der
  Anforderung. `avesmapsOrteProvider` liest vor der Anforderung die lokal
  gespeicherte Tagesliste (ohne Netz); `avesmapsOrteSpeicherProvider` trennt
  den Speicher vom Repository.
- `standort_lage_rules.dart`: `ortZumStandort`, `orteInDerNaehe` (nur
  Siedlungen, ohne Gebäude und Stadtviertel), `gebietsZeile`/`reichDesOrts`,
  `avesmapsOrtLink`, `lageskizze` (Halbmesser 15/30/60/120 Meilen, der kleinste
  mit sechs Siedlungen; bis zu sechs Namen ab der Kleinstadt).
- Kachel „Standort“ mit eigener Lageskizze statt Kartenausschnitt (C2 für den
  Standort); Knopf „Kartendaten laden“, solange nichts vorliegt.
- Datenschutzerklärung Abschnitt 6 und Verzeichnis der Verarbeitungstätigkeiten
  nennen die Kachel und den Abruf der Ortsdetails.

**Offen.** Rücklinks der Reiseroute über die Ortsdetails (Sichtprüfung im
Web erledigt, 22.11.2026). Die Lageskizze ist inzwischen ein Ausschnitt der Aventurien-Karte (siehe
unten).

### Aventurien-Karte im Avesmaps-Stil (umgesetzt 13.11.2026)

**Befund aus dem Bundle von avesmaps.de** (gelesen, nichts ausgeführt):

- Avesmaps zeichnet mit MapLibre aus eigenen Vektorkacheln
  (`/tiles/vector/<ebene>/{z}/{x}/{y}`: Orte, Wege, Gebiete, Gewässer,
  Höhenlinien) über Rasterserien `modern`, `original`, `old`
  (`/tiles/raster/<serie>/<revision>/{z}/{x}/{y}.webp`, 512 px, bis z6 =
  32768 px). Alle Serien stammen aus der Ulisses-Karte. Für fremde Apps
  gesperrt; die App lädt davon nichts.
- **Karten-API** (nicht in `openapi.json`): Der Betreiber stellt einen Zugang
  aus (Link oder Schlüssel `avk_…`, Frist `laeuftAb`, begrenzte Abrufe; Fehler
  `karten_zugang_zuviele`, `…_gesehen`, `…_unbekannt`, nach Ablauf `410`).
  `…/oeffnen` liefert `karten[]` (`id`, `art` png/svg, `bytes`, `pixel`),
  `datei`, `nennung[]`, `lizenz.uri`; das Paket kommt als ZIP mit
  DSA-Fanprojekt-Logo. PNG in 8192 bis 65536 px; `modern` ist der
  Avesmaps-Stil ohne Beschriftung im Bild. SVG mit wählbaren Ebenen (Orte,
  Wege, Gebiete, Landschaften, Kraftlinien, Beschriftungen) wäre später eine
  Vektorlage.
- **Designkanon** (`avesmaps.json` im Bundle): Palette, Durchmesser und
  Schriftgrößen der Ortsmarken je Zoomband 0–8 und Ortsklasse, Goldring der
  Metropolen ab Band 3, Rauten für Bauwerke ab Band 4, Ortsnamen weiß mit
  schwarzem Saum in „Faculty Glyphic“, Route `#1452f7` mit weißem Saum,
  Querfeldein als Pillen 10/14, Wegpunkt-Scheibe und Reisender. Maßstab: bei
  Zoom z misst eine Karteneinheit 0,5 · 2^z px. Übernommen sind nur Zahlen
  und Farben, kein Code (`lib/ui2/karte/karto_karten_stil.dart`).

**Umsetzung.**

- Eigene Karte ohne Kartenbibliothek (`lib/ui2/karte/`): Kamera mit dem
  Maßstab von Avesmaps, Maler für Orte, Namen (gierig, ohne Überlappung,
  rechts vor links), Route als Luftlinie in Pillen, nummerierte Wegpunkte,
  Reisender am Standort, Kompass und Meilenmaßstab. Ohne Kartenbild: Papier
  und Landschimmer aus der Ortsdichte.
- Kartenbild (C3): `KartenKachelSpeicher` lädt Kacheln einer selbst
  gehosteten Site; Adresse per `--dart-define=KARTEN_KACHELN`, Manifest
  `aktuell.json` (`KartenKachelManifest`). Ohne Adresse oder bei Fehlern
  bleibt der Rückfall. Werkzeug `tool/avesmaps_karte_kacheln.py`, Hosting und
  Ablauf in `docs/web_deployment.md` („Kartenkacheln“).
- Einbau: Die Lageskizze der Standort-Kachel ist ein fester Kartenausschnitt
  mit der Route; ein Tipp öffnet die Karte im Vollbild (`zeigeKarte`) mit
  Zoom, Infotafel zu Ort oder Station und „Bearbeiten“ über
  `KartoReiserouteSchreiben`. Das Reiseroute-Blatt hat „Auf der Karte
  zeigen“. Regeln: `karten_rules.dart`.
- Pflichtteile: Ecke „Ortsdaten: Avesmaps“, mit Kartenbild zusätzlich
  Ulisses-Zeile, Logo und Lizenz-URI; Lizenzseite mit Kartenmaterial (nur in
  Builds mit Kacheln) und Faculty Glyphic (OFL).

**Ortsfakten (13.11.2026).** Einwohner, Oberhaupt, Herrschaftsform und
Verkehrswege sowie Tempel und wichtige Orte je Siedlung kommen aus den
Infoboxen der Wiki Aventurica (`ortsfakten.json`, siehe
`docs/catalog_import_workflow.md`), nicht von Avesmaps: dort stammen dieselben
Fakten aus internen Schnittstellen ohne Zusage. Verknüpft wird über den
Wiki-Seitennamen; Dörfer ohne Wiki-Artikel bleiben ohne Fakten. Infotafel
der Karte: Einwohner, Oberhaupt und je drei Namen.

**Gestaltung der Standort-Kachel (13.11.2026).** Kopf mit Name (Titel) und
einem Satz zur Einordnung („Metropole in Alt-Gareth“), daneben Avesmaps und
Wiki als Symbolknöpfe. Darunter die Karte als Blickfang, dann der Steckbrief:
Einwohnerzahl als Leitzeile mit dem Wiki-Zusatz leise darunter, Oberhaupt,
Herrschaft, Lage, Wege als Marken und Tempel als Marken je Gottheit mit
Anzahl (`tempelNachGottheit`; mehrere Tempel öffnen eine Liste, einer direkt
das Wiki). Dann „Wichtige Orte“ mit Symbol je Art, reihum nach Art geordnet
(`reiheNachVielfalt`, Palast vor Burg vor Akademie …, Botschaften zuletzt),
und „In der Nähe“ mit Richtungspfeil. Weit: Karte und Steckbrief links,
wichtige Orte und Nachbarn rechts. Die Kartenposition (x/y) zeigt die Kachel
nicht mehr.

**Standort auf der Karte (20.11.2026).**

- **Lageskizze:** Die Lageskizze der Standort-Kachel zeigt keine Reiseroute
  mehr.
- **Vollbild aus der Standort-Kachel:** Es öffnet ohne Route
  (`zeigeKarte(mitRoute: false)`). Im Vollbild blendet ein Knopf die
  Reiseroute ein und aus.
- **„Standort hierher“:** Die Infotafel eines Orts oder einer Station
  bietet den Knopf an, außer für den Standort selbst. Er schreibt über
  `KartoStandortSetzer`, also über `standortSetzen` der Spielansicht.
  - Das ist derselbe Weg wie der Standortdialog: frisch am Zustand, bei
    Ortswechsel mit automatischer Station.
  - Der Knopf erscheint, wenn die Karte aus der Standort-Kachel oder aus dem
    Reiseroute-Blatt der Spielansicht geöffnet wurde.

**Kartenbild live (23.11.2026).** Paket `modern` mit 32768 px, Revision
`e62449359a41` (z0–6) auf `heldensync-karten`; CI und `tool/deploy_web.ps1`
setzen `KARTEN_KACHELN`. Sichtprüfung auf Test und Produktion: Kacheln aller
Stufen ohne Haarrisse, Orte auf den Siedlungen, keine CSP- oder CORS-Fehler,
Lizenzeintrag vorhanden. Seit 23.11.2026 kürzt die schmale Ecke der
Standort-Kachel die Nennung nicht mehr (vorher fiel „DSA-Fanprojekt“ weg);
unter „Rechtliches“ steht ein Absatz zu Avesmaps und dem Kartenmaterial.
Neue Kartenfassungen nach [avesmaps_kartenzugang.md](avesmaps_kartenzugang.md).

### B2 · Reisewege statt Luftlinie (umgesetzt 20.11.2026)

**Ziel.** Zwischen zwei Stationen zeichnet die Karte den Weg, den
Avesmaps berechnet: Straße, Fluss oder See statt der Luftlinie. Je Etappe
lässt sich wählen, wie gereist wurde, etwa „nur über Land“ oder „mit dem
Schiff“. Die Tabelle nennt Meilen und Reisetage. Die Luftlinie bleibt der
Rückfall.

**Schnittstelle** (`GET /api/v1/route`, ohne Schlüssel, CORS offen):

- **Parameter:**
  - `von`, `nach`: Kennung oder eindeutiger Name;
  - `ueber`: höchstens zehn Halte, mit `~` getrennt;
  - `optimierung`: `schnellste` (Vorgabe) oder `kuerzeste`;
  - `wege`: aus `land`, `fluss`, `see`, kommagetrennt (Vorgabe alle).
- **Antwort:**
  - `gefunden` (mit `grund`: `kein_zusammenhang`, `gesperrt`);
  - `meilen`, `reisestunden`, `raststunden`, `reisetage`, `stundenProTag`;
  - `etappen[]` mit `art`, `mittel`, `wege`, `von`/`nach` (x/y), `meilen`;
  - `linie` als `[x, y]`-Punkte und `hinweise`.
- **Drossel:** je IP-Adresse; `429` mit `Retry-After`.

**Entscheidungen.**

- **Wahl je Etappe am Ziel-Halt:** Die Wahl gehört zur Station, an der eine
  Etappe endet: neues optionales Feld `HeroReiseStation.anreise` mit `wege`
  (Menge aus Land, Fluss, See) und `optimierung`.
  - Es wird nur bei Belegung geschrieben und kommt in `jsonSchluessel`, die
    Enums laufen über `leseEnumWert`.
  - Bestandshelden behalten so ihren Hash, und die Wahl synchronisiert
    zwischen Geräten.
  - Ohne Feld gilt die Vorgabe (schnellste, alle Wege).
- **Ergebnis nur lokal:** Das Ergebnis kommt nie ins Heldendokument. Es
  liegt im lokalen Zwischenspeicher (Hive-Box `avesmaps_routen_v1`).
  - Schlüssel ist `vonId|nachId|wege|optimierung`.
  - Ein Eintrag gilt 30 Tage, ein leeres Ergebnis (`gefunden: false`) einen
    Tag.
- **Anfragen nur auf Nutzeraktion:**
  - „Reisewege berechnen“ im Blatt fragt die fehlenden Etappen nacheinander
    ab.
  - Bei `429` hört das Holen auf und meldet die Wartezeit.
  - Auf der Karte erscheinen nur bereits gespeicherte Wege.
  - Je Etappe eine Anfrage, damit die Wahl je Etappe wirkt und Treffer im
    Speicher wiederverwendbar bleiben.
- **Rückfall Luftlinie:** Die Luftlinie wie heute (Pillen) bleibt, wenn
  - einer Station die `ortId` fehlt,
  - der Weg noch nicht geholt ist,
  - die Anfrage scheitert oder `gefunden: false` meldet.
- **Varianten:** Der Etappendialog zeigt die gespeicherte Wahl samt
  Ergebnis. „Vergleichen“ holt auf Wunsch bis zu drei Vorgaben nacheinander:
  - schnellste, alle Wege;
  - nur Land;
  - kürzeste.

  Gespeichert wird die übernommene Variante.

**Schritte.**

1. **Daten:**
   - Modell `AvesmapsRoute` mit `AvesmapsRoutenEtappe`.
   - `AvesmapsClient.route()`: tolerant lesen, unbekannte `art`/`hinweise`
     überspringen, `429`/`503` als `AvesmapsFehler`.
   - `AvesmapsRoutenRepository` mit Hive-Speicher.
   - Provider `avesmapsRouteProvider` (Familie je Anfrage, liest nur den
     Speicher) und `AvesmapsRoutenAbruf` für das Holen.
   - Tests mit `MockClient` und aufgezeichneten Antworten.
2. **Regeln** (`reiseroute_rules.dart`, `karten_rules.dart`):
   - `routenAnfrageFuer(etappe)`: nur mit beiden `ortId`.
   - Formatierung „365 Meilen · 6½ Reisetage · Straße, Fluss“.
   - `kartenRoutenPunkte` erhält je Abschnitt optional die `linie`, aufgeteilt
     nach den Wegarten der `etappen`.
3. **Karte:**
   - Der Maler zeichnet eine vorhandene `linie` durchgezogen (`#1452f7` mit
     weißem Saum, Fluss und See in hellerem Blau gestrichelt), sonst die
     Pillen der Luftlinie.
   - Treffer auf die Linie öffnen die Etappe in der Infotafel: Meilen,
     Reisetage, Wegarten, „Reiseweg ändern“.
4. **Wahl je Etappe:**
   - Modellfeld `anreise` samt Eintrag in
     `test/domain/unbekannte_verschachtelte_felder_test.dart`, geschrieben
     über `KartoReiserouteSchreiben`.
   - Etappendialog: Wege als Schalter, Optimierung, Ergebnis, „Vergleichen“.
   - Tabelle und Zeitleiste nennen Meilen und Reisetage statt der Luftlinie,
     sobald ein Weg vorliegt.
5. **Pflichtteile:**
   - Datenschutzerklärung Abschnitt 6 und Verzeichnis der
     Verarbeitungstätigkeiten um den Routenabruf ergänzen.
   - Quellenzeile „Wege: Avesmaps“ unter der Karte.

**Umsetzung.**

- **Daten:**
  - `AvesmapsRoute`, `AvesmapsRoutenEtappe` und `AvesmapsRoutenAnfrage`
    (`lib/domain/avesmaps_route.dart`).
  - `AvesmapsClient.route()`.
  - `AvesmapsRoutenRepository` mit `HiveAvesmapsRoutenSpeicher`
    (`avesmaps_routen_v1`).
  - `avesmapsReisewegeProvider` (`lib/state/avesmaps_routen_providers.dart`).
- **Modell:** `HeroReiseStation.anreise` ist ein `HeroReiseAnreise` mit
  `wege`/`optimierung` als Texte der Schnittstelle. Unbekannte Werte bleiben
  erhalten, ein Enum entfällt.
- **Regeln:**
  - `reiseweg_rules.dart`;
  - `ReiseEtappe.vorherige`;
  - `reiseEtappenAbstandText(weg:)`;
  - `kartenRoutenPunkte(wege:)`.
- **Oberfläche:**
  - Im Blatt „Reisewege berechnen“ und je Etappe „Reiseweg“
    (`KartoReisewegDialog`).
  - Die Infotafel einer Station nennt die Anreise und öffnet den Dialog.
  - Die Karte zeichnet gemerkte Wege durchgezogen.
- **Abweichung vom Plan:** Die Linie wird nicht nach Wegarten eingefärbt.
  Die `von`/`nach`-Punkte der Etappen teilen die `linie` nicht verlässlich
  auf (in der Antwort vom 20.11.2026 lagen Lücken dazwischen). Die
  Wegarten stehen deshalb im Text. Treffer auf die Linie entfallen; die
  Etappe öffnet sich über die Station.
- **Tests:**
  - `test/data/avesmaps/avesmaps_routen_test.dart`;
  - `test/rules/derived/reiseweg_rules_test.dart`;
  - `test/ui2/spielen/karto_reiseweg_test.dart`;
  - Kartentest und Eintrag in `unbekannte_verschachtelte_felder_test.dart`.

**Später.** B3 Reiseplaner, siehe unten.

### B3 · Reiseplaner und Zeitrechnung (Konzept 20.11.2026, umgesetzt 21.11.2026)

**Ziel.** Ein Ortswechsel geht auf zwei Wegen:

- **Direkt setzen:** eine Korrektur oder ein Sprung, wie heute.
- **Reise planen:** vom Standort zu einem Ziel.

Beide Wege stehen in der Standort-Kachel und in der Karten-Infotafel
(„Standort hierher“ neben „Hierher reisen“). Eine geplante Reise landet als
Weg in der Reiseroute: Abreise, Ankunft, Anreise und Plan.

**Zeitrechnung: Plan nach Regelwerk, Ist über die Daten.**

- **Strecke und Wegarten von Avesmaps:** `etappen[].art` und `meilen`.
- **Dauer in der App nach den Regeln:**
  - Grundlage sind Basisregelwerk S. 192 und Geographia Aventurica S. 123.
  - Je Etappe gilt Tage = Meilen ÷ (Tagesstrecke des Reisemittels ×
    Geländemodifikator).
  - Die Reisetage von Avesmaps gelten nur zu Fuß und ohne Wegart und dienen
    nur zum Vergleich.
- **Tagesstrecke an Land:**

  | Reisemittel | normal | Eilmarsch |
  | --- | --- | --- |
  | zu Fuß | 30 | 45 |
  | beritten | 40 | 60 |
  | Fuhrwerk | 30 | 37,5 (×1,25) |
  | Kutsche | 50 | 62,5 (×1,25) |

  - Eile gilt nur auf befestigten Wegen.
  - Fuhrwerk und Kutsche fahren auf Pfaden und querfeldein wie zu Fuß.
- **Gelände:**
  - Reichsstraße ×1,1, Straße ×1, Weg und Pfad ×0,8, querfeldein ×0,75
    (offenes Gelände);
  - eine unbekannte Wegart zählt ×1 und wird erwähnt.
- **Wasser:**
  - Fluss 30 Meilen am Tag (Mittel aus Flusskahn stromauf 20 und stromab
    40; die Richtung kennt Avesmaps nicht);
  - See 120 (Lastensegler);
  - Umsteigen zählt wie zu Fuß.
- **Herleitung sichtbar:** etwa „Reichsstraße 120 Meilen ÷ (30 × 1,1) =
  3,6 Tage“.
- **Ankunft:** Abreise + aufgerundete Plantage. Die Ankunft lässt sich vor
  dem Übernehmen ändern, etwa für Wetter (×0,9 bis ×0,5), Rast oder Umwege.
  Eingetragen wird das tatsächliche Datum.
- **Abweichungen:** Ein Weg, der anders verlief als geplant, hat drei
  Wege:
  - das Ankunftsdatum ändern (Ist);
  - Wegarten oder Reisemittel ändern (Plan);
  - Zwischenhalte als eigene Stationen anlegen.

  Die Tabelle zeigt Ist und Plan nebeneinander, etwa „+9 Tage · 341 Meilen
  · Plan 6 Tage · 3 Tage länger“.

**Modell** (nur additiv, Felder nur bei Belegung):

- `HeroReiseAnreise` bekommt `abreise` (Datum), `mittel`
  (`fuss`/`beritten`/`fuhrwerk`/`kutsche`), `tempo` (`normal`/`eil`) sowie
  `geplanteTage` und `meilen` als Momentaufnahme. So bleibt der Plan ohne
  Netz und nach Ablauf des Wegspeichers lesbar.
- Mit `abreise` trennt die Etappe den Aufenthalt am vorigen Ort
  (vorige Ankunft bis Abreise) von der Reise (Abreise bis Ankunft).

**Schreiben** (je Schritt ein Dokument):

1. **Bogen:**
   - Eine Ausgangsstation wird angelegt, wenn die zeitlich letzte Station
     nicht der Standort ist (Datum = Abreise).
   - Die Ankunftsstation bekommt Kartenverweis, Ankunftsdatum, Abenteuer und
     `anreise`.
   - Auf Wunsch springt das Datum des laufenden Abenteuers auf die Ankunft.
2. **Zustand:** über `standortSetzen`. Die Brücke legt keine zweite Station
   an, weil die letzte Station schon das Ziel trägt.

**Regeln:**

- `reisezeit_rules.dart` rechnet die Plantage samt Herleitung.
- `reiseAntreten(held, …)` rechnet den neuen Bogen (rein, testbar).
- Belege kommen in die Regeltest-Inventur mit beiden Quellen.

**Oberfläche:** Der Reiseplaner (`KartoReiseplaner`) enthält:

- Von (Standort, braucht einen Kartenverweis) und Nach (Ortsfeld bzw. der
  Ort der Karte);
- Wegarten und Optimierung;
- Reisemittel und Eile;
- Abreise (Vorgabe: Datum des laufenden Abenteuers, sonst der letzten
  Station);
- „Weg berechnen“, dann Strecke, Wegarten, Plan mit Herleitung und eine
  änderbare Ankunft;
- „Abenteuerdatum auf Ankunft setzen“;
- „Reisen“.

Der bestehende Reisewegdialog bekommt Reisemittel und Eile, damit auch
erfasste Etappen einen Plan haben.

**Stufe 2 (danach):** „Unterwegs“ als Zustand des Helden.

- Aufbrechen setzt den Standort auf „unterwegs nach …“. Die Kachel zeigt
  den Reisetag („Tag 3 von 6“) und die ungefähre Lage auf der Linie.
- „Angekommen“ übernimmt das tatsächliche Datum.
- „Unterwegs anhalten“ legt eine Zwischenstation an der geschätzten Lage
  an.
- Das braucht ein neues Feld am Zustand (Hash- und Sync-Regeln beachten)
  und wird deshalb erst nach der Erprobung von Stufe 1 gebaut.

**Entscheidungen (21.11.2026):**

- Ein Reittier unter den Begleitern belegt „beritten“ vor.
- Das Wetter ist je Reise wählbar (×1 bis ×0,3, Basisregelwerk S. 192 und
  Geographia Aventurica S. 123) und fließt in Herleitung und Ankunft ein.
- „Unterwegs“ (Stufe 2) kam gleich mit.

**Umsetzung.**

- **Regeln:** `reisezeit_rules.dart` mit `reisezeitPlan` (Herleitung je
  Wegart, Hinweise), `reisemittelVorschlag`, `reiseAbreiseVorschlag`,
  `reiseDatumPlus`, `reiseAntreten`, `reiseMitAusgangsstation`,
  `unterwegsLage`, `reiseUnterwegsAnhalten`, `anreiseMitPlan`,
  `reiseEtappenText`. Regeltest mit beiden Quellen in der Inventur.
- **Modell:** `HeroReiseAnreise` mit `abreise`, `mittel`, `tempo`,
  `wetter`, `geplanteTage`, `meilen`; `HeroUnterwegs` als
  `HeroState.unterwegs`. Alles nur bei Belegung, Hash-Pins unverändert.
- **Schreiben:** `karto_reise_ablauf.dart`; Bogen über
  `aendereHeldAusserhalbPlanung`, Zustand über die neue Adaptermethode
  `reiseZustandSetzen` (Reise und Standort in einem Dokument).
- **Oberfläche:** `KartoReiseplaner`, `KartoReiseplanWahl`,
  `KartoReiseplanHerleitung`; Tafel „Unterwegs nach …“ in der
  Standort-Kachel; Reisender auf der Karte an der geschätzten Lage;
  Reisewegdialog mit Reisemittel, Eile und Wetter; Tabelle und Zeitleiste
  mit Ist und Plan.
- **Abweichungen:**
  - Das Wetter wirkt nur an Land; auf Fluss und See nennt ein Hinweis, dass
    es nicht eingerechnet ist.
  - Eile entfällt bei Wetter ab ×0,7 (Geographia Aventurica: Sturm und
    heftiger Regen vereiteln den Eilmarsch).
  - Statt „Standort auf ‚unterwegs nach …‘“ bleibt der Standort der
    Ausgangsort; die Reise steht im eigenen Feld `unterwegs`.
  - „Unterwegs anhalten“ legt eine Rast ohne Avesmaps-Verweis an und beendet
    die Reise; weiter geht es mit einer neuen Planung.
- **Tests:** `test/rules/derived/reisezeit_rules_test.dart`,
  `test/ui2/spielen/karto_reiseplaner_test.dart`, Kartentest, Modelltests.

### Für alle Bausteine

- **Client:** `lib/data/avesmaps/` mit `package:http` (schon vorhanden), ohne
  Riverpod, per Konstruktor injizierbar. User-Agent außerhalb des Webs setzen.
  `429` und `503` mit `Retry-After` achten, nie automatisch in Schleife
  wiederholen. Tolerant lesen, unbekannte Felder ignorieren.
- **Web-CSP:** `connect-src` in `firebase.json` muss `https://avesmaps.de`
  nennen (zwei Stellen, seit 13.11.2026 eingetragen); ohne den Eintrag
  blockiert der Browser jede Anfrage.
- **Datenschutz:** Die Anfragen gehen direkt vom Gerät an avesmaps.de (IP-
  Adresse, in den Apps die Kennung). Das gehört in die Datenschutzerklärung
  und in `docs/legal_privacy_operations.md`. Anfragen entstehen nur durch
  Nutzeraktionen; ein Schalter „Avesmaps-Daten laden“ in den Einstellungen ist
  möglich.
- **Namensnennung:** Zeile „Karte & Ortsdaten: Avesmaps (avesmaps.de)“ am
  Ortsfeld bzw. Blatt und unter „Rechtliches“ (Muster:
  `lib/data/wiki_aventurica_lizenz.dart`). Die Ulisses-Zeile erst mit C3/C4.
- **Tests:** Client gegen aufgezeichnete Antworten (`MockClient`), kein Netz
  im Test; Abgleich und Formatierung als Regeltests.

### Empfohlene Reihenfolge

1. **2a (umgesetzt):** A2 und A1 mit Client, CSP, Datenschutztext und
   Namensnennung. Ergebnis: Stationen mit Position, Luftlinie in Tabelle und
   Zeitleiste.
2. **2b:** B2 und D. Ergebnis: echte Weglängen und Reisetage, Gebietszeile,
   genaue Rücklinks.
3. **2c (umgesetzt):** C2 als Aventurien-Karte mit Luftlinie; `linie` aus 2b
   kommt als durchgezogene Linie dazu.
4. **2d (umgesetzt, 21.11.2026):** B3 Reiseplaner mit Zeitrechnung und „Unterwegs“.
5. **2e (live, 23.11.2026):** C3 mit Schlüssel. Das Paket ist geladen
   (`tool/avesmaps_karte_laden.py`) und geschnitten, die Web-Builds setzen
   `KARTEN_KACHELN`; abgenommen und mit #286 auf `main`.

### Rückfragen an Avesmaps

- Schlüssel für die Karten-API (nur für C3/C4).
- Darf ein Snapshot der Ortsliste im App-Paket liegen (A3), damit die
  Ortssuche schon vor dem ersten Abruf Positionen kennt?
- Ist ein ETag für `/orte` geplant? Bis dahin gilt der Tagesabstand.
