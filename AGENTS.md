# Agentenrichtlinie fuer `flutter_application_1`

## Ziel dieser App
Ziel dieser App ist eine möglichst umfangreiche Heldenverwaltung für das Pen and Paper "Das schwarze Auge".
Das Spiel beinhaltet eine vielzahl von Regeln und ist für sein detailreichtum bekannt. Mache dich ggfs. mit dem Spiel vertraut und recherchiere. 

## Zweck und Geltungsbereich
Diese Regeln gelten fuer alle agentischen Arbeiten in diesem Repository.  
Sie sind verbindlich und haben Vorrang vor impliziten Standardannahmen.

## Sicherheitsprinzipien (verbindlich)
- Zuerst lesen und analysieren, dann minimal und gezielt aendern.
- Keine destruktiven Operationen ohne explizite Anweisung durch den Nutzer.
- Vor potenziell riskanten Schritten immer sichere Vorpruefung nutzen (`git status`, `git diff`, Dry-Run).
- Keine ungefragte Umschreibung von Historie oder grossflaechige Bereinigung des Worktrees.
- Nur den fuer den Task noetigen Scope aendern.
- Architektur, Schichten, Abhaengigkeiten und Projektaufbau aktiv und kritisch hinterfragen, statt bestehende Muster ungeprueft zu uebernehmen.
- Erstelle möglichst generische Funktionen, sodass Erweiterungen und Skalierungen möglich sind.
- Nutze in UI-Strings konsequent echte Umlaute und ß statt Transliterationen wie `ae`, `oe`, `ue` oder `ss`, sofern kein technischer Grund dagegen spricht.
- Hinterfrage die Anforderung im Prompt. Gibt es eine bessere Lösung? Dann schlag diese vor.

## Verbotene Befehle
Die folgenden Befehle sind in normalen Agent-Workflows untersagt:
- `git reset --hard`
- `git clean -fd`
- `git clean -fdx`
- `git checkout -- <pfad>`
- `git push --force`
- `git push --force-with-lease`
- `rm -rf *`
- `Remove-Item -Recurse -Force *`
- `del /s /q *`
- `rd /s /q`
- Alle vergleichbaren Befehle, die ohne Rueckfrage irreversibel Dateien, Historie oder Nutzerdaten verwerfen.

## Sichere Ersatzbefehle (statt gefaehrlicher Befehle)
| Nicht nutzen | Stattdessen |
|---|---|
| `git reset --hard` | `git status`, `git diff`, `git restore --staged <datei>`, gezielte Ruecknahme pro Datei |
| `git clean -fd` / `git clean -fdx` | `git clean -nd` (Vorschau), danach selektive Loeschung einzelner Artefakte |
| `git checkout -- <pfad>` | `git restore <pfad>` nur fuer gezielte Dateien nach Sichtpruefung |
| `git push --force*` | Normaler `git push`; bei Konflikten Branch/Commits sauber neu aufsetzen statt Historie ueberschreiben |
| `rm -rf *` / `Remove-Item ... *` / `del /s /q *` | Pfadspezifische Loeschung einzelner Build-Ordner oder Dateien, in PowerShell bevorzugt mit `-WhatIf` vorab |

Zusaetzliche Sicherheitsmassnahme vor groesseren Umbauten:
- Temporaerer Sicherungs-Branch: `git switch -c backup/<datum-zeit>`

## Erlaubte Standard-Workflows fuer dieses Repo
Unkritische Standardbefehle:
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter run`
- Schnelle Suche/Inspektion mit `rg` (Fallback: `grep` bzw. PowerShell-Aequivalent)

Hinweis zu `flutter clean`:
- `flutter clean` ist nicht pauschal verboten.
- Es ist ein Troubleshooting-Schritt und nicht der Default.
- Reihenfolge bevorzugen: Analyse/Test/Dependency-Refresh zuerst, `flutter clean` nur bei konkreten Build-Problemen.

## Branch-Regel fuer natuerlicheres Git-Workflow
- Sofern nichts anderes vorgegeben ist, gilt: Wenn der aktuelle Branch `main` ist, wird zu Beginn einer neuen Konversation ein eigener Arbeits-Branch erstellt.
- Alle zur jeweiligen Konversation gehoerenden Commits werden in diesem Arbeits-Branch erstellt, nicht direkt auf `main`.
- Der Branch-Name soll kontextbezogen und eindeutig sein, z. B. `task/<datum-zeit>-<kurzthema>`.
- Befindet sich die Arbeit bereits auf einem Nicht-`main`-Branch, wird dieser Branch weiterverwendet, sofern der Nutzer nichts anderes vorgibt.

## Commit-Regel nach erfolgreichen Tests
- Nach jeder abgeschlossenen Aenderung ist bei erfolgreich ausgefuehrten relevanten Tests automatisch ein Commit zu erstellen.
- Commit-Inhalt: nur die zur Aenderung gehoerenden Dateien (kein Sammel-Commit mit unzusammenhaengenden Aenderungen).
- Commit-Nachricht: praezise und aenderungsbezogen, z. B. `<bereich>: <konkrete aenderung>`.
- Wenn Tests fehlschlagen, wird kein Commit erstellt; stattdessen wird der Fehler analysiert und behoben oder transparent berichtet.

## Kommunikation bei Unklarheiten
- Wenn Anforderung, Umfang oder gewuenschtes Verhalten unklar ist, muss vor der Umsetzung aktiv nachgefragt werden.
- Rueckfragen sind ausfuehrlich und kontextbezogen zu formulieren, damit der Nutzer die Auswirkung der Entscheidung versteht.
- Antwortmoeglichkeiten muessen spezifisch, gegenseitig abgrenzbar und leicht verstaendlich sein.
- Keine vagen Ja/Nein-Rueckfragen bei inhaltlichen Trade-offs; stattdessen konkrete, vergleichbare Optionen anbieten.

## Repo-spezifische Hinweise
- Katalogquelle bleibt die Split-JSON-Struktur unter `assets/catalogs/house_rules_v1/*`.
- Legacy-/Platzhalterdateien nicht ungefragt loeschen.
- Plattformordner (`ios/`, `android/`, `macos/`, `windows/`, `linux/`) nur bei klarer Notwendigkeit aendern.
- Vorhandene Tools unter `tool/` bevorzugen statt ad-hoc Skripte.
- Keine unbegruendeten Massenaenderungen an generierten Plattformdateien.

## Vor jeder Aenderung: Pflicht-Checkliste
1. Ziel und Scope des Tasks klar benennen.
2. Betroffene Dateien gezielt eingrenzen.
3. Vorherzustand mit sicheren Befehlen pruefen (`git status`, `git diff`).
4. Architektur und Aufbau der betroffenen Loesung kritisch pruefen (Sinnhaftigkeit, Kopplung, Wartbarkeit).
5. Nur minimal notwendige Aenderungen durchfuehren.
6. Nach Aenderungen mindestens `flutter analyze` und relevante `flutter test`-Laeufe ausfuehren.
7. Bei erfolgreichem Testlauf einen passenden Commit mit praeziser Nachricht erstellen.
8. Ergebnis und verbleibende Risiken transparent dokumentieren.

## Dokumentationspflicht nach Aenderungen
- Nach jeder inhaltlichen Aenderung sind betroffene Anleitungen zu pruefen:
  CLAUDE.md, AGENTS.md, README.md und alle Dateien unter docs/.
- Wenn eine Aenderung ein dokumentiertes Verhalten, eine Schnittstelle oder
  einen Workflow betrifft, muss die Dokumentation im selben Commit aktualisiert
  oder ergaenzt werden.
- Neue, noch nicht beschriebene Konzepte oder Dateien sind in CLAUDE.md
  (Verzeichnisstruktur / Architektur) nachzufuehren.

## Kommentarpflicht fuer Funktionen und Methoden
- Jede oeffentliche Funktion, Methode oder Klasse muss einen erklaerenden
  Dart-Doc-Kommentar (///) tragen, der Zweck und Verhalten beschreibt.
- Private Hilfsfunktionen erhalten mindestens einen einzeiligen Kommentar,
  wenn ihr Zweck nicht trivial ist.
- Kommentare beschreiben das *Warum* und den *Zweck*, nicht das syntaktische
  *Was* (kein Rephrasen des Codes).

## Lesbarkeit: keine komplexen oder stark verschachtelten Zeilen
- Stark verschachtelte Ausdruecke (mehr als zwei Ebenen tief, oder Zeilen
  ueber ~100 Zeichen) sind in benannte Zwischenvariablen aufzuloesen.
- Mehrfach verkettete Methodenaufrufe (.foo().bar().baz()) sind in
  lesbare Schritte zu splitten, wenn sie nicht trivial sind.
- Unleserlichen Code nicht weiter verschachteln; stattdessen in klar
  benannte Schritte aufloesen.

## Regellogik in dedizierte Regeldateien
- Berechnungen und Regellogik gehoeren ausschliesslich in die zustaendigen
  Dateien unter lib/rules/derived/.
- Jede thematische Gruppe von Regeln erhaelt eine eigene Datei, z. B.:
    - Behinderungsberechnungen → lib/rules/derived/behinderung_rules.dart
    - Initiativeberechnungen  → lib/rules/derived/initiative_rules.dart
- Keine Regelberechnungen in UI-Widgets, Providern oder Domain-Modellen —
  diese Schichten duerfen Regelmodule nur aufrufen, nicht selbst rechnen.
- Neue Regelthemen stets als eigene, klar benannte Datei anlegen, nicht
  in bestehende Regeldateien einbauen, wenn das Thema abgrenzbar ist.

## Dateigroesse und Lesbarkeit
- Dateien sollen klein und uebersichtlich bleiben.
- Wenn eine Datei schwer zu ueberblicken ist oder Verantwortlichkeiten
  vermischt, ist sie sinnvoll aufzuteilen (z. B. in ein Unterverzeichnis
  mit Teildateien).
- Das bestehende LOC-Limit von 700 Zeilen fuer Screen-Dateien
  (tool/check_screen_loc_budget.py) gilt als konkreter Richtwert;
  dasselbe Prinzip gilt analog fuer alle anderen Dateien.
- Neue Hilfsfunktionen oder -klassen, die nur zur Entflechtung einer zu
  grossen Datei entstehen, koennen in eigenstaendige Dateien ausgelagert
  werden.

## Oeffentliche APIs / Interfaces / Types
- Diese Richtlinie aendert keine Runtime-APIs, Dart-Interfaces oder Datenmodelle.
- Prozessuale Schnittstelle: verbindliche Agenten-Policy in dieser `AGENTS.md`.

## Abnahmekriterien fuer diese Richtlinie
- Klare Verbotsliste mit destruktiven Befehlen ist enthalten.
- Fuer jede verbotene Kategorie ist mindestens eine sichere Alternative dokumentiert.
- Repo-Standardworkflow (`pub get`, `analyze`, `test`, `run`) ist explizit enthalten.
- Keine Widersprueche zwischen verbotenen und erlaubten Aktionen.
