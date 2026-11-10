# Reiseroute

Hält fest, wo ein Held wann war und was dort geschah: Stationen mit Ort,
aventurischem Datum, Abenteuerzuordnung und Notiz. Sie erscheinen als Zeitleiste
und später auf einer Aventurien-Karte.

## Stand

| Stufe | Inhalt | Status |
| --- | --- | --- |
| 0 | Anfrage an Avesmaps (Ortsverzeichnis, Kacheln, CORS, Namensnennung) | offen |
| 1 | Stationsliste am Helden, Spielkachel „Reiseroute“, Blatt mit Zeitleiste | umgesetzt |
| 2 | Ortssuche mit Koordinaten, Karte mit Route und Pins | wartet auf Stufe 0 |

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
Text; es gibt keine `ortId` und keine Koordinaten. Damit ist die Ortsauswahl
unabhängig von der offenen Anfrage an Avesmaps (Stufe 0); für Karte und
Luftlinie braucht Stufe 2 weiterhin dessen Koordinaten.

## Avesmaps: Recherche (Stand 2026-11-02)

- **Repository:** github.com/valentin-schwind/avesmaps. Nur der Programmcode
  steht unter MIT. Kacheln sowie Orts-, Wege- und Gebietsdaten sind **nicht**
  frei lizenziert, siehe dort `LEGAL.md` und `NOTICE.md`.
- **Kartenbasis:** Ulisses-Kartenpaket. Lizenz-URI:
  https://de.wiki-aventurica.de/wiki/Kartenpaket/Lizenz. Bedingungen:
  - nur nicht-kommerzielle Nutzung,
  - Bearbeitungen mit DSA-Fanprojekt-Logo,
  - die Lizenz oder ihre URI muss beiliegen,
  - keine Unterlizenzen.
- **Stabile API:** antwortet mit `Access-Control-Allow-Origin: *`.
  - `GET https://legacy.avesmaps.de/api/locations/` liefert rund 3950 Orte mit
    `public_id`, `name`, `subtype`, `is_crossing` und `coordinates {x, y}`.
    Der Wertebereich ist 0 … 1024, der Ursprung liegt im Südwesten, `y` wächst
    nach Norden.
  - Zur Revalidierung `X-Avesmaps-ETag` lesen und als `If-None-Match`
    zurückschicken.
  - `POST /api/route/` berechnet Weglänge, Dauer und Geometrie, mit bis zu
    zehn Zwischenstationen.
- **Kacheln:** `https://legacy.avesmaps.de/tiles/stylized/{z}/map_{x}_{-y}.webp`,
  256 px, Zoom 0 bis 5. Sie liefern **keinen CORS-Header** und lassen sich
  deshalb in Flutter Web nicht laden.

## Stufe 2 (geplant, nach Zusage)

- **Ortsverzeichnis:** `/api/locations/` laden, Kreuzungen herausfiltern, lokal
  mit ETag cachen. Ohne Netz bleibt der Ort Freitext ohne Position.
- **Ortsfeld:** Autovervollständigung; die Auswahl setzt `ortId`, `kartenX` und
  `kartenY`.
- **Karte:** `flutter_map` mit `CrsSimple`. Avesmaps-Kacheln, Routenlinie in
  Datumsreihenfolge, nummerierte Pins.
- **Pflichtangaben:** Namensnennung, Fanprojekt-Logo und Lizenz-URI in der
  Kartenecke und unter „Rechtliches“.
- **Optional:** `/api/route/` für echte Weglängen und Reisetage.
- **Fallback bei Absage:** ein eigenes Kartenbild des Nutzers, lokal gespeichert
  wie die Avatare. Pins setzt der Nutzer per Tipp, die Koordinaten bleiben im
  System 0 … 1024.
