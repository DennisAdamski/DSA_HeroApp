# Reiseroute

Hält fest, wo ein Held wann war und was dort geschah: Stationen mit Ort,
aventurischem Datum, Abenteuerzuordnung und Notiz. Sie erscheinen als Zeitleiste
und später auf einer Aventurien-Karte.

## Stand

| Stufe | Inhalt | Status |
| --- | --- | --- |
| 0 | Anfrage an Avesmaps (Ortsverzeichnis, Kacheln, CORS, Namensnennung) | beantwortet (12.11.2026): Ortsdaten und Route ja, Kacheln nein |
| 1 | Stationsliste am Helden, Spielkachel „Reiseroute“, Blatt mit Zeitleiste | umgesetzt |
| 2 | Ortssuche mit Koordinaten, Reisewege, Karte mit Route und Pins | A2 und A1 gewählt (13.11.2026); Unterbau umgesetzt, Datenmodell und Ortsfeld offen |

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
| C3 Eigene Kacheln | Karten-PNG mit Schlüssel einmal laden (lokales Werkzeug unter `tool/`, Schlüssel in gitignorierter Datei), in Kacheln schneiden, selbst hosten (Firebase Hosting oder Storage, damit ohne CORS- und CSP-Thema). Anzeige mit `flutter_map` und `CrsSimple`, Route und Pins darüber. | Volle Karte. Verlangt: Lizenz des Kartenpakets selbst prüfen, Logo, Lizenz-URI und Ulisses-Zeile in der Kartenecke und unter „Rechtliches“, Speicher- und Bandbreitenkosten, erneutes Schneiden bei neuer Kartenfassung. Kacheln nicht ins öffentliche Repository. |
| C4 Übersichtsbild | Ein verkleinertes Kartenbild (etwa 2048 px) als Hintergrund der Skizze aus C2. | Günstiger als C3 und offline, aber dieselben Lizenzpflichten; im App-Paket ausgeliefert heißt im Repository eingecheckt. Erst nach der Lizenzprüfung zu C3 entscheiden. |

### D · Ortsdetails

`/orte/{id}` bei der Auswahl oder beim Öffnen einer Station laden, lokal
zwischenspeichern:

- Gebietskette als Unterzeile („Kaisermark Gareth · Königreich Garetien“),
  auch für Orte, die das Wiki-Verzeichnis nicht kennt.
- Rücklink mit dem Seitennamen aus `wiki.url`, wie von Avesmaps gewünscht. Orte
  ohne Wiki-Seite bekommen keinen Link statt eines toten.

### Unterbau für A2 und A1 (umgesetzt 13.11.2026)

Noch ohne Anbindung an die Oberfläche; die App stellt damit keine Anfrage.

- `AvesmapsOrt` (`lib/domain/avesmaps_ort.dart`): `id`, `name`, `art`, `x`,
  `y`. Liegt nur im lokalen Zwischenspeicher, nie im Heldendokument.
- `AvesmapsClient` (`lib/data/avesmaps/avesmaps_client.dart`): `ladeOrte()`
  und `suche()`. Liest tolerant, setzt die Kennung nur außerhalb des Webs,
  meldet `429`/`503` samt `Retry-After` als `AvesmapsFehler` und wiederholt
  nichts von sich aus.
- `AvesmapsOrteRepository` mit `HiveAvesmapsOrteSpeicher` (Box
  `avesmaps_orte_v1` im Heldenspeicher): Liste höchstens einmal in 24 Stunden,
  nur auf Aufruf; nach einem Fehlschlag 15 Minuten Pause bzw. die Wartezeit
  des Servers; scheitert das Auffrischen, gilt die ältere Liste weiter.
- Tests: `test/data/avesmaps/`.

### Für alle Bausteine

- **Client:** `lib/data/avesmaps/` mit `package:http` (schon vorhanden), ohne
  Riverpod, per Konstruktor injizierbar. User-Agent außerhalb des Webs setzen.
  `429` und `503` mit `Retry-After` achten, nie automatisch in Schleife
  wiederholen. Tolerant lesen, unbekannte Felder ignorieren.
- **Web-CSP:** `connect-src` in `firebase.json` kennt `https://avesmaps.de`
  noch nicht (zwei Stellen); ohne den Eintrag blockiert der Browser jede
  Anfrage.
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
- **Kleinigkeit:** Der Kommentar an `HeroReiseStation.ortId` nennt noch
  `public_id`; das Feld heißt jetzt `id`.

### Empfohlene Reihenfolge

1. **2a:** A2 mit Client, CSP, Datenschutztext und Namensnennung. Ergebnis:
   Stationen mit Position, Luftlinie in der Zeitleiste.
2. **2b:** B2 und D. Ergebnis: echte Weglängen und Reisetage, Gebietszeile,
   genaue Rücklinks.
3. **2c:** C2 Routenskizze, mit `linie` aus 2b.
4. **2d:** B3 Reiseplaner.
5. **2e:** C3 erst nach Schlüssel und eigener Lizenzprüfung; sonst bleibt der
   Fallback: eigenes Kartenbild des Nutzers, lokal gespeichert wie die
   Avatare.

### Rückfragen an Avesmaps

- Schlüssel für die Karten-API (nur für C3/C4).
- Darf ein Snapshot der Ortsliste im App-Paket liegen (A3), damit die
  Ortssuche schon vor dem ersten Abruf Positionen kennt?
- Ist ein ETag für `/orte` geplant? Bis dahin gilt der Tagesabstand.
