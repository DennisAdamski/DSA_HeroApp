# CLAUDE.md - DSA Heldenverwaltung

Kurze Einstiegsdatei fuer neue Sessions. Diese Datei bleibt absichtlich klein und enthaelt nur stabile Hinweise.

## Zuerst lesen

- `AGENTS.md` ist die verbindliche Agentenrichtlinie.
- `README.md` beschreibt Produktumfang, Architekturueberblick und Standard-Workflows.
- `tool/sync_main_to_test.sh` mergt Main in Test;
  `tool/test_main_test_sync.py` sichert Erhalt, Konflikte und Wiederholungen ab.
- `docs/web_deployment.md` beschreibt Web-CI, Testbranch, automatischen Main-Test-Sync und Hosting-Targets.
- [Architektur-To-dos](docs/architecture_roadmap.md) halten sieben offene
  Verbesserungen mit Ist-Zustand, Abhängigkeiten und Abnahmekriterien fest.
  Bei Architekturarbeiten den Aufgabenstatus prüfen und nach abgeschlossenen
  Teilumfängen aktualisieren.
- [ARCH-06-Abnahmeprüfung](docs/arch06_abnahme.md) hält die reproduzierten
  Abbruchlücken bei „Nur Lokal“ und „Beide behalten“ fest. Konfliktentscheidungen
  über Bogen und Zustand haben noch keinen dauerhaften Wiederanlaufvertrag;
  die Gesamtabnahme bleibt offen.
  Der [Wiederanlaufvertrag](docs/superpowers/specs/2026-10-10-arch06-konflikt-wiederanlauf-design.md)
  beschreibt den Lösungsentwurf zur Nutzerprüfung, noch keine Implementierung.
- Das [Codex-Mockup](docs/mockups/README.md) zeigt den geplanten Workspace mit
  drei Arbeitsbereichen als eigenständigen HTML/CSS/JavaScript-Prototyp.
  Es nutzt ausschließlich flüchtige Beispieldaten und keine produktive Regellogik.
  Der [Gefecht-Plan](docs/mockups/gefecht-plan.md) ergänzt das klickbare
  Gefechts-Mockup. `gefecht-aktionen.js` bündelt dessen Freigaben und kompakte
  Rundensteuerung, `gefecht-ausruestung.js` enthält das separate Ausrüstungspopup.
  Die freigegebene Flutter-Umsetzung wird in
  [docs/gefecht_implementation.md](docs/gefecht_implementation.md) nachgeführt.
  `domain/gefecht.dart` enthält ausschließlich flüchtige Typen,
  `state/gefecht_provider.dart` hält Sitzungen je Held; `gefecht_rules.dart`
  und `gefecht_held_rules.dart` unter `rules/derived` entscheiden Freigaben.
  `gefecht_freigabe_rules.dart` ergänzt konkrete Formularpflichten und offene
  Entscheidungen; `gefecht_filter_rules.dart` ordnet AT/PA/Sonstige zu und
  verknüpft Such-, Lernstands- und Sperrfilter ohne Regelrechnung im Widget.
  `gefecht_ansage_rules.dart` prüft getrennte Finte/Wuchtschlag/FK-Ansagen,
  Kombinationen und bezahlte Zusatz-Zielzeit.
  `gefecht_zielen_rules.dart` ergänzt optionales Zielen (0–4 Punkte) mit eigener
  bezahlter Zeit, Profilbindung und Abbau ausschließlich sonstiger FK-Zuschläge.
  `gefecht_ansagefolge_rules.dart` führt eigene misslungene Nahkampf-Ansagen als
  flüchtigen Probenmalus bis einschließlich nächster AT/PA oder Orientieren.
  Die weiteren Pakete stehen in `docs/gefecht_folgepakete_plan.md`.
  `gefecht_meisterparade_rules.dart` ergänzt die getrennte PA-Ansage und den
  eigenen flüchtigen Erfolgsbonus. Prüfmetadaten binden Erleichterung und einmalige
  Buchung; Schilde benötigen eine konkrete manuelle Ansagegrenze plus aktuelle PA.
  `gefecht_meisterparade.dart` zeigt die gebuchte manuelle Fehlmanöverfolge.
  `domain/gefecht_angriff.dart`
  hält flüchtige Zielzahlungen und Erfolgsprofile; `gefecht_angriff_rules.dart`
  bindet TP-Boni an das eingefrorene Kampfmittel und klassifiziert Schadensfolgen:
  unterstützter Waffenschaden, kein Schaden oder manuell zu klären. Nur die erste
  Klasse liefert einen Schadensrequest; die anderen werden einzeln am Tisch
  abgewickelt und abgeschlossen. Kleine Ansage-/Ergebniswidgets
  lassen die allgemeine Schadensprobe unverändert unabhängig.
  Gebundener FK-Schaden ersetzt ausschließlich den Vorschau-Distanzanteil durch
  das Band der eingegebenen Schussentfernung; unbekannte Bänder bleiben manuell.
  Dynamische Formularhinweise erhalten die Identität ganzer Eingabeabschnitte,
  damit Tastaturfokus und Cursor beim Tippen bestehen bleiben.
  `domain/gefecht_laden.dart` hält flüchtige Ladestände pro physischer Waffen-ID
  und bezahlte Vorbereitungsaufträge. `gefecht_ladezustand_rules.dart` bindet
  Ladung an Waffen-/Geschossprofil, `gefecht_laden_rules.dart` prüft aktuelle
  Restdauer, echte reguläre Zahlung und den gehaltenen Ziel-/Schussauftrag.
  Profile ohne passenden Ladestand dürfen im Schussdialog frisch bestätigt werden;
  ein passender bekannter entladener Zustand bleibt verbindlich.
  `gefecht_ladedialog.dart` erfragt den unbekannten Anfang; `gefecht_laden.dart`
  verbindet den Dialog mit der flüchtigen Sitzung. Ladezeit stammt zentral aus
  der bestehenden Combat-Vorschau, einschließlich Effekten und Waffenmeister.
  Beide Hände übergeben effektive Rüstungs-BE nach Rüstungsgewöhnung; Schnellladen
  einschließlich Axxeleratus wirkt nur bis BE 4. Vorbereitete Schüsse behalten
  ihren ursprünglichen Auftrag, verwenden aber aktuelle DK und Sitzungskontext
  für die abschließende Prüfung und Probe.
  Die gezielte `KartoGefechtsAdapter`-Brücke ergänzt einmalige Probeauswertung
  und frische Ausrüstungsschreibwege, ohne bestehende Aufrufer zu verändern;
  der Wirkabschluss nutzt zusätzlich `gefechtsZustand`,
  `gefechtsFehlerBereich`, Armatrutz-/Attributo-Eingabe und
  `gefechtsWirkkosten`. Außer `karto_app_root.dart` importiert `lib/ui2`
  nichts aus `lib/ui` (`test/ui2/shell/ui2_import_richtung_test.dart`).
  `gefecht_hand_rules.dart` prüft Haupt-/Nebenhandbelegungen vor Normalisierung
  und frischem Speichern; `gefecht_handwahl.dart` enthält Auswahl und bestätigtes
  Wegstecken. Ziehhandlungen merken ihre Zielhand.
  Waffenloser Kampf: `waffenlos_slot_rules.dart` (blattartig, auch von
  `combat_rules` genutzt) definiert Platzhalter, virtuellen Raufen-/Ringen-
  Slot und `waffenlosKampfbereit` (Hände frei oder nur Raufen-Waffen wie
  Schlagring); ohne Waffe rechnet die Kampfvorschau Raufen. `waffenlos_rules.dart`
  liefert die Kampfmittel `waffenlos`, neben einer Waffe nur mit Kampftechnik
  (`nebenWaffe`, +2). Der leere Waffenplatzhalter zählt nie als Waffe.
  Effektive Einhändigkeit wird dort zentral aus Talent/Waffenart bestimmt:
  Bogen und gewöhnliche Armbrust brauchen beide Hände, Balestrina ist die
  belegte Ausnahme. Anzeigenamen und gespeicherte Standardwerte eröffnen keine
  Ausnahme; Metadaten bleiben unverändert. Kampfmittel und Zusatzbudgets nutzen
  dieselbe Prüfung. `GefechtsDialogzweck.distanzklasse` öffnet den eigenen
  DK-Einstieg mit Finte und ±1/±2; AT, freier Schritt und Folgen bleiben im
  vorhandenen zentralen Auftrags-/Ausführungspfad.
  `gefecht_kampfmittel_rules.dart` löst konkrete Kampfmittel auf; ihre getrennten
  Grundwerte werden von Anzeige, Dialog und frischer Auftragsprüfung verwendet.
  `gefecht_zusatz_rules.dart` verbindet konkrete Zusatzproben mit Ausrüstung,
  vorherigen regulären Aktionen und derselben nicht kumulativen Zusatzmarke.
  `ui2/gefecht/` trennt Einstieg, Rundenleiste, Ansicht, Aktionsdialog,
  Manöverliste, Ausrüstung und Magie. Weitere Gefechtsregelmodule betreffen
  Auftragsprüfung, Dauerhandlungen und echte Talent-/Zauberproben.
  `gefecht_vitalwerte.dart` zeigt geschlossen LeP, aktivierte AsP und tatsächliche
  Wunden; seine stabile Heldenidentität erhält die Expansion bei Ressourcenänderung.
  Geöffnet nutzt die Ansicht dieselben bisherigen Fachdialoge und Schreibwege.
  Normale Nahkampf-PA benötigt keine allgemeine Paradebestätigung; bekannte
  Verbote und konkrete fehlende Angriffsdaten bleiben in den Kontextregeln wirksam.
  Der Folgeplan steht in [docs/gefecht_next_plan.md](docs/gefecht_next_plan.md).
  `gefecht_orientieren_rules.dart` trennt Kampfverluste von geschützten und
  ungeklärten Korrekturen; der Orientierungsdialog nutzt frische Heldendaten.
  `gefecht_kontext.dart` hält ausschließlich flüchtige Kontakt-/Angriffsdaten.
  Kontext- und Fernkampfregelmodule liefern gemeinsame DK-Sperren und
  Modifikatoranteile; ein gewürfelter Schuss hält seine offene Munitionsübernahme.
  `gefecht_ziehen_rules.dart` liefert bestätigte Standardkosten und Markenarten.
  `gefecht_wirken.dart` enthält ausschließlich flüchtige Wirkprofile; das
  Wirkregelmodul berechnet Dauer, Kosten, Kulteigenschaften und einmalige Boni.
  Aktionsausführung, Handlungskarte, Wirkdialog, Unterbrechung und Abschluss
  sind eigenständige Bausteine unter `ui2/gefecht/`.
  **Vorgaben statt Pflichtfelder** (Nutzerentscheidung 5. Oktober 2026):
  `gefecht_vorgaben_rules.dart` belegt nur unbekannte Angaben sichtbar vor
  (Nahkampf, Finte 0, Zielsituation 0, Platz zum Ausweichen, Schild-WM) und
  liefert Start-DK und Gegnerzahl. Die Regeln behandeln `null` weiterhin als
  fehlend; Vorgaben setzen nur Gefechtsstart, Kontaktwechsel und das Ende
  einer Abwehr. Ladezustand und Schussentfernung bleiben bewusst ohne Vorgabe.
  Hinweise allein ergeben „Bereit“. Gegner der lokalen Begegnung
  (`gefecht_gegner_rules.dart`, `state/gefecht_begegnung_provider.dart`)
  tragen stabile IDs; die gemeinsame Initiative
  (`gefecht_initiative_rules.dart`, `state/gefecht_initiative_provider.dart`)
  verbindet ausdrücklich gewählte Helden; ihr Rundenwechsel nimmt die
  angezeigte Runde (`naechsteRunde(vonRunde:)`), Gegner- und Initiativkarte
  laufen wie alle Karten über `onAktion` (Guard und Gefechtshinweis, Text über
  `gefecht_fehlertext.dart`). Leere oder kleingeschriebene Waffen-DK gilt
  als Nahkampf mit Hinweis; die Klingen-Aufteilung ist vorbelegt
  (`gefechtsKlingenVorgaben`) und trägt die einzige Erschwernis ihrer
  Teilproben. Klingenwand/-sturm, Patzer und
  Bruchtest, Manöverfolgen und Fremdwirkung haben je eigene Regelmodule;
  alles bleibt flüchtig. Stand und Grenzen: [docs/gefecht_abschluss_entwurf.md](docs/gefecht_abschluss_entwurf.md).
  Bedienung: `gefecht_aktionsknopf.dart` zeigt Status und Hauptgrund
  (`gefechtsHauptgrund`), `gefecht_anordnung.dart` ordnet die Abschnitte,
  `gefecht_schnellleiste.dart` hält schmal Attacke/Parade/Ausweichen/Runde
  erreichbar. Dialoge nutzen `gefecht_zahlfeld.dart` (−/+), `gefecht_dkwahl.dart`
  und eingeklappte Herleitung (`gefecht_dialogabschnitte.dart`). Gefechtsproben
  mit eigenem Erschwernisfeld sperren den zweiten Modifikator im Probendialog
  (`kGefechtsprobenMitFestemModifikator`). Talent- und Eigenschaftsproben im
  Gefecht: `gefecht_probenwahl.dart` mit Zeitbedarf aus `gefecht_talent_rules.dart`.
  Benannte Handlungen (WdS S. 55) liefert `gefecht_aktionskatalog_rules.dart`
  mit `gefecht_aktionswahl.dart`; die LeP-/AuP-Lage (`gefecht_lage_rules.dart`)
  erscheint nur als Banner. Inventar und „Gegenstand benutzen“:
  `gefecht_inventar.dart` mit `gefecht_inventar_rules.dart`; abgebucht wird
  erst beim Abschluss nach Bestätigung über `inventar_verbrauch_rules.dart`
  (`menge` vor `anzahl`, frisch über `updateHero`). Begleiter nur ansehen:
  `gefecht_begleiter.dart` mit `begleiter_kampfprofil_rules.dart`.
- **Reittiere** entwickeln sich nur über die ZBA-Ausbildung, nie über AP
  ([docs/reittier_plan.md](docs/reittier_plan.md), Pakete P1–P3).
  `HeroCompanion.reittierAusbildung` hält Ausgangsstand, gebuchte Schritte,
  Variante und Unarten; die eingetragenen Werte gelten als Werte der
  Ausgangsstufe, Ausbildungseffekte werden nur abgeleitet
  (`reittier_ausbildung_rules.dart`, Wirkwerte in
  `begleiter_wirkwert_rules.dart`), nie in Grundwerte geschrieben.
  Ausbildungskatalog als Dart-Konstanten (`reittier_ausbildung_katalog.dart`,
  `pferde_sf_katalog.dart`) mit JSON-Spiegel. Schritte und Pferde-SF bucht der
  Begleiter-Tab sofort über `aendereHeldMitMeldung`.
- **Vertraute** (WdZ S. 123–128) haben einen Artenkatalog
  (`vertrauten_katalog.dart`, JSON-Spiegel) und eine Bindung
  `HeroCompanion.vertrautenBindung`. Bindung und AP-Übertragung zählen als
  ausgegebene AP der Hexe; ¼ der Abenteuer-AP läuft automatisch über
  Abenteuerabschluss und Reisebericht (`mitVertrautenApAnteil`). Die
  Steigerung folgt strikt WdZ S. 125: INI, LO und AuP sind gesperrt, die
  Grenze ist 1,5 × Startwert, Altbuchungen bekommen nur einen Hinweis.
  Plan, Belege und Entscheidungen stehen in
  [docs/vertraute_plan.md](docs/vertraute_plan.md) (V1 und V2 fertig, V3 offen).
  V2: `HeroState.begleiterZustaende` hält laufende LeP/AsP/AuP **aller**
  Begleiter (`null` = voll, Eintrag nur bei Belegung; Rechnung vom gespeicherten
  Wert in `begleiter_zustand_rules.dart`, Schreibweg `aendereBegleiterPool`;
  im Sync Zähler). Vereinigung (`VertrautenVereinigung`) und Rast-Regeneration
  schreiben ein Dokument, ein versäumtes Treffen zwei getrennte Buchungen.
  Die UI2-Spielansicht führt „Begleiter“ nach „Zustand“, noch vor dem
  Würfelprotokoll. Fehlt der Hexe die SF Vertrautenbindung, ist das nur ein
  Hinweis beim Binden (Meisterentscheid).
- [Redesign umsetzen](docs/redesign_implementation.md) enthält drei aufeinander
  aufbauende Agentenpläne, Startprompts und die gemeinsame Umsetzungsspezifikation
  unter `docs/superpowers/`. Ausgangspunkt ist das vorhandene UI2-Fundament;
  R1 samt Bestandsbrücke, R2 und R3 sind implementiert; die Abnahme steht in
  [docs/redesign_acceptance.md](docs/redesign_acceptance.md). Vor Folgearbeit
  den Paketstatus und die Nachprüfung lesen. Die Navigation hat drei Arbeitsbereiche.
- Detaildokumentation liegt bei Bedarf in `docs/technical_overview.md`, `docs/test_strategy.md`, `docs/catalog_import_workflow.md`, `docs/pdf_agent_workflow.md`, `docs/rule_audit_regelwerk_ueberarbeitung.md`, `docs/ios_xcode_setup.md` und `docs/windows_antivirus_audit.md`.

## Projektkontext

- `dsa_heldenverwaltung` ist eine Flutter-App zur Verwaltung von DSA-Helden.
- Die App nutzt lokale Persistenz, katalogbasierte Inhalte und getrennte Regellogik.
- Lokale Persistenz laeuft ueber `hive_ce` / `hive_ce_flutter`, den gepflegten
  Fork von Hive 2 (das Original ist seit 2022 ohne Release). Das Box-Format
  auf Platte ist identisch, Bestandsdaten brauchen keine Migration. Es sind
  keine `TypeAdapter` im Einsatz — Boxen halten `Map` bzw. `Uint8List`.
- Die AES-Schicht liegt in `lib/crypto/aes_primitives.dart` direkt auf
  `pointycastle`; `encrypt` ist entfernt. Das Modul ist bewusst blattartig,
  weil `catalog` und `data` es beide brauchen und die Richtung
  `data -> catalog` nicht umgedreht werden darf.
- Das Krypto-Wire-Format ist durch ausgelieferte Daten festgelegt und in
  `test/catalog/catalog_crypto_golden_test.dart` sowie
  `test/data/secrets_cipher_golden_test.dart` mit festen Chiffraten gepinnt.
  Diese Fixtures duerfen **nicht** angepasst werden, wenn sie brechen: dann
  ist die Implementierung inkompatibel geworden und jeder `enc:`-Katalogwert
  sowie jedes Firestore-Geheimnis waere unlesbar. Die uebrigen Krypto-Tests
  pruefen nur Round-Trips und wuerden das nicht bemerken.
- `HeroSheet` und `HeroState` bewahren JSON-Felder, die sie nicht kennen, in
  `unbekannteFelder` und schreiben sie zurueck; Verlaufseintraege unbekannter
  Steigerungsart bleiben als `UnbekannterVerlaufseintrag` erhalten. Bekannt ist,
  was in `jsonSchluessel` steht (bei `HeroSheet` einschliesslich der flach
  eingebetteten Schluessel von `HeroAppearance`/`HeroBackground`). **Jedes neue
  Feld dort eintragen** — sonst kaeme ein bewusst weggelassener Wert als
  „unbekannt“ zurueck. Dasselbe gilt fuer **jedes verschachtelte Modell**
  von Held und Zustand (Liste in `docs/technical_overview.md` Abschnitt 2.1;
  einzige Ausnahme `OffhandSlot`, nur gelesen). Jedes hat eigene
  `unbekannteFelder` und ein eigenes `jsonSchluessel`, das auch gelesene
  Altschluessel (`offhand`, `wmFk`, `fkMod`, `schnellladenBogen`, `eigenAp`,
  `vorNachteile`, Alias `note`) enthaelt. Bestehende Objekte **nur per
  `copyWith`** aendern — auch in Dialogen, die Zeilen oder Formulare neu
  zusammensetzen; neu errechnete Eigenschaften uebernimmt
  `Attributes.uebernimmWerte`. Ein Neuaufbau per Konstruktor verliert die
  Felder. Neue Modelle faengt der Vollstaendigkeitswaechter in
  `test/domain/unbekannte_verschachtelte_felder_test.dart` ab. Unbekannte
  Enum-Werte haelt jedes Modell roh in `unbekannteEnumWerte` (Regeln sehen
  den Ersatz, `toJson` schreibt den Rohwert); ein `copyWith` mit **anderem**
  Wert ueberschreibt ihn, derselbe Wert laesst ihn stehen. Neue
  Enum-Felder ueber `leseEnumWert` lesen und in die `_enumFelder`-Tabelle
  desselben Tests eintragen. Unbekannte Wundzonen: `WundZustand.unbekannteZonen`.
  Formatregel: nur additiv, eine neue Bedeutung bekommt einen neuen
  Schluessel.
- Verknuepfte Kampf-/Inventareintraege tragen stabile Slot-IDs in
  `lib/domain/combat_config/`; das Verweisformat und die Migration liegen in
  `inventar_verweise.dart`. `HeroSheet.fromJson` vergibt fuer Altdaten
  deterministische IDs, `HeroActions.saveHero` fuer neue Slots UUIDs.
  Ein Inventareintrag traegt **zwei** Verweise: `sourceRef` bleibt der
  Namensverweis (`w:Name` …), weil die bereits veroeffentlichte App nur ihn
  versteht. Mit einem ID-Verweis dort verwarf ihr Abgleich alle verknuepften
  Inventardaten. Den ID-Verweis (`w#id` …) traegt `slotRef`. Zugeordnet wird
  ueber Instanz und `slotRef`; ueber den Namen ordnet nur noch das Laden
  Altdaten zu (`migriereInventarVerweise`), und die Reihenfolge „manuell,
  dann Slot-Reihenfolge“ bleibt. Geschossmengen
  immer mit `slotRef ?? sourceRef` zurueckschreiben. `inventory_sync_rules.dart`
  gleicht weiterhin beide Darstellungen ab. Das ist der B2/B3-Teilfix, noch
  nicht das gemeinsame Gegenstandsmodell aus ARCH-03. Menge und Stapel
  (`inventar_menge_rules.dart`, `inventar_stapel_rules.dart`): `menge` führt,
  `anzahl` ist ihr Text, beide nur über `mitInventarMenge` schreiben.
  Weicht ein ganzzahliges `anzahl` ab, gilt es; das wird nie still
  aufgelöst. `saveHero` überführt reine Zahlen, der Abgleich vergibt keine
  Menge (Fixpunkt). Inventarwege treffen Einträge über `instanzId`
  (`findeInventarEintragZurAenderung`). Slots verweisen zurueck: Waffe,
  Geschoss, Ruestungs- und Nebenhandteil tragen `inventarInstanzId`, nur in
  `saveHero` gesetzt (`bindeSlotsAnInstanzen`); der Abgleich paart zuerst
  ueber sie. Der Verweis ist abgeleitet: Inhaltsvergleiche und
  Gefechts-Fingerabdruecke lassen ihn weg (`ohneInstanzverweise`).
  Entfernen im Kampf-Tab fragt „Nur ablegen“/„Ganz entfernen“
  (`kampfgegenstand_ablegen_rules.dart`): abgelegt bleibt das Exemplar als
  manueller Eintrag mit `abgelegt` (gemerkte Kampfwerte), „In Kampfbereich
  übernehmen“ holt es zurück; Geschosse gehen nie still verloren.
  Zusammenführen gleicher Stapel liegt in `inventar_stapel_rules.dart`,
  Verkaufen (Erlös auf den Geldstand) in `inventar_verkauf_rules.dart`;
  `gewichtGramm`/`wertSilber` gelten pro Stück (`inventar_summen_rules.dart`).
  Verknüpfte Waffen/Nebenhandteile gelten nur in der Hand als ausgerüstet
  (Abgleich setzt `istAusgeruestet`), nur dann wirken ihre Modifikatoren. Formataenderungen
  aendern Inhalts-Hashes; Bestandsfixtures und Hash-Pins nur gemeinsam mit
  ihnen aktualisieren. Den Mischbetrieb bildet
  `test/test_support/veroeffentlichte_app.dart` nach.
- Die Bestandshelden unter `test/fixtures/heroes/` (ARCH-07) sind genauso
  festgeschrieben: nie anpassen, ein neues Format bekommt eine neue Datei.
  `test/domain/bestandshelden_kompatibilitaet_test.dart` pinnt ihre
  Inhalts-Hashes — bricht einer, bekaeme jeder gleich gespeicherte Held einen
  neuen Hash und der Konto-Sync meldete Konflikte. Die Regelwerte je Fixture
  rechnet `buildHeroComputedSnapshot` (reine Funktion hinter
  `heroComputedProvider`) gegen den echten Katalog
  (`test/test_support/real_catalog.dart`). Aufgedeckte, bewusst nicht
  behobene Fehler tragen im Test den Kommentar `Befund ARCH-07-Bx` und stehen
  mit Folgeauftrag in `docs/architecture_roadmap.md`. Details in
  `docs/test_strategy.md`.
- Web-Interop laeuft ueber `package:web` + `dart:js_interop`, nie ueber
  `dart:html` (deprecated und von `dart2wasm` nicht uebersetzbar). Bedingte
  Importe muessen auf `dart.library.js_interop` stehen, **nicht** auf
  `dart.library.html`: unter dart2wasm ist letzteres `false`, ein Wasm-Build
  zoege dann stillschweigend die Stub-Implementierung. Der Web-Download liegt
  gemeinsam in `lib/data/web_download.dart`.
- `flutter analyze` bricht auch bei `info`-Lints ab, die CI faellt also
  darauf. Die Sprachversion aus `environment: sdk:` steuert mit, welche Lints
  ueberhaupt feuern und wie breit `dart format` umbricht — ein SDK-Bump zieht
  beides nach sich.
- Regellogik gehoert nach `lib/rules/derived/`.
- Fachlich benannte Anwendungsablaeufe (ARCH-05) liegen in `lib/ablaeufe/`:
  ohne Riverpod und Flutter, Abhaengigkeiten per Konstruktor, aus `data/`
  nur die `HeroRepository`-Schnittstelle — der Waechter
  `test/ablaeufe/abhaengigkeiten_test.dart` prueft das. Provider dazu stehen
  in `lib/state/ablauf_providers.dart`. Muster: frisch laden → Regel aus
  `rules/derived/` → stempeln → speichern (`aendereGespeichertenZustand`,
  an das auch `HeroActions.updateHeroState` delegiert). Ablaeufe fangen
  Fehler nicht, die aufrufende Oberflaeche zeigt sie. Bestandsaufnahme aller
  Schreibwege: `docs/schreibpfade_inventar.md`.
- Speichervertrag (ARCH-06, `docs/schreibpfade_inventar.md`): Jeder Ablauf
  schreibt genau ein Dokument, ausser dem Import. Der Import vermerkt sich im
  `Vorgangsjournal` (`lib/data/vorgangsjournal.dart`, Box `vorgaenge_v1`,
  `vorgangsjournalProvider`). `VorgaengeWiederaufnehmen` fuehrt ihn beim Start
  vor `syncNow` zu Ende oder gleicht ihn aus; dasselbe passiert sofort, wenn
  ein Importschritt scheitert. Ein neuer Ablauf mit mehreren Schreibvorgaengen
  braucht dasselbe. Der Sync bleibt dokumentbasiert: ausstehend ist, was vom
  gemerkten Hash abweicht; es gibt keine Operations-Warteschlange.
- `aendereGespeichertenZustand` reiht Aenderungen je Speicher und Held ein
  (Warteschlange per `Expando` am Repository); zwei nicht abgewartete Aufrufe
  ueberschreiben einander so nicht. Laufzeitwerte werden in der Oberflaeche
  **nie** als beim Rendern erfasster Gesamtzustand geschrieben
  (`saveHeroState` bleibt Editor, Anlegen und Import vorbehalten), sondern
  ueber `aendereZustandMitMeldung` (`lib/ui/screens/shared/zustand_aendern.dart`):
  frisch laden, nur die eigenen Felder ersetzen. Fehler erscheinen im
  naechsten `ZustandFehlerBereich` an der `ZustandFehlerAnzeige` (Blatt,
  Dialog, Inspector-Tab, UI2-Zustandsblock) — eine Snackbar laege hinter dem
  Blatt, auf iOS/macOS verdeckt; sie ist nur Rueckfall. Wunden laufen
  darueber in `wund_zustand_speichern.dart`, Zaubereffekte ueber
  `rules/derived/active_spell_state_rules.dart`. Bedienung zaehlt **immer**
  vom gespeicherten Wert, damit jeder schnelle Klick zaehlt: Ressourcenknoepfe
  melden eine `RessourcenAenderung` (`rules/derived/ressourcen_aenderung_rules.dart`,
  Schritt mit Grenzen nur in Schrittrichtung oder Setzen), nie einen
  fertigen Wert. `test/ui/shared/zustand_frisch_schreiben_test.dart` prueft
  jeden Weg gegen eine Zwischenaenderung und schnelle Klicks.
- Fuer den **Bogen** gilt dasselbe: `aendereGespeichertenHelden`
  (`lib/ablaeufe/held_schreiben.dart`) laedt frisch, aendert und speichert
  ueber die injizierte Normalisierung; `HeroActions.updateHero` delegiert
  daran und liefert den gespeicherten Helden. Auch `saveHero` reiht sich
  (`reiheBogenvorgangEin`, eigene Warteschlange neben der des Zustands,
  Baustein `reihenfolge_je_held.dart`) ein und liefert den normalisierten
  Helden; so landet ein Editorentwurf nie zwischen Laden und Schreiben einer
  frischen Aenderung, und die Hash-Pruefung der Steigerungsrunde sieht jede
  eingereihte Aenderung. Eine Aenderung darf **nie** selbst `saveHero` oder
  `updateHero` aufrufen — sie wartete auf sich selbst. Gibt sie dasselbe
  Objekt zurueck, wird nichts gespeichert. Sofortaktionen am Bogen
  (Inspector-Statuswerte, Wundschwelle, Uebersicht, Inventar-Loeschen und
  Dukaten, Abenteuerabschluss, Vertrauten-Steigerung) laufen ueber
  `aendereHeldMitMeldung` (neben `aendereZustandMitMeldung`): nur die eigenen
  Felder, Schritte vom gespeicherten Wert, Regeln aus `rules/derived/`
  (u. a. `modifikator_aenderung_rules.dart`, `epic_status_rules.dart`,
  `inventar_aenderung_rules.dart`, `begleiter_aenderung_rules.dart`). Bei
  offener Steigerungsrunde schreibt der Einstieg nicht; Statuswerte und
  Wundschwellen-Zahnrad sind dann sichtbar gesperrt. Das Sofortspeichern
  des Kampf-Tabs laeuft ueber einen Einstieg `_aendereKampf`
  (`hero_combat/combat_state_helpers.dart`, Regeln in
  `kampf_aenderung_rules.dart`): Slots werden ueber ihre ID getroffen, nie
  ueber die Position, und die Sektionen melden den **angezeigten** Slot;
  ein Editorergebnis auf einen inzwischen geaenderten Slot wird abgewiesen.
  Der Inventareditor schreibt ueber `aendereHeldImEditor` (Fehler zeigt
  der Editor selbst) und `inventar_aenderung_rules.dart`: Er trifft den
  geoeffneten Gegenstand ueber seinen Inhalt, nie ueber die Position, und
  schreibt in den Kampf nur dessen eigene Geschossmenge; eine beim Speichern
  vergebene Instanz-ID zaehlt dabei nicht als Aenderung.
  Editorentwuerfe speichern ueber `speichereEditorEntwurf`
  (`shared/editor_entwurf_speichern.dart`): Jeder Tab merkt sich in
  `_entwurfBasis` den Helden, aus dem er den Entwurf gefuellt hat, und baut
  den Entwurf auf dieser Basis. `uebernimmEditorEntwurf`
  (`rules/derived/editor_entwurf_rules.dart`) gleicht Basis, Entwurf und
  frischen Helden je oberstem JSON-Schluessel ab, AP sind Zaehler.
  Beidseitig verschieden Geaendertes fragt nach („Weiter bearbeiten“ /
  „Meine Fassung speichern“); Erzwingen nimmt nie eine fremde Buchung
  (Abenteuerabschluss, Reisebericht-Belohnungen) zurueck. Uebernimmt ein Entwurf
  waehrend der Bearbeitung frisch Gespeichertes, rueckt auch die Basis nach.
  Kein Bogenschreibweg schreibt mehr einen Snapshot. Pruefung:
  `test/ui/shared/held_frisch_schreiben_test.dart`,
  `test/ui/shared/editor_entwurf_frisch_test.dart` und Geschwister mit
  `test/test_support/bogen_test_repository.dart`.
- Mit Konto endet `SyncingHeroRepository.saveHeroState` nach dem **lokalen**
  Speichern; `GebuendelteLaeufe` (`lib/data/sync/gebuendelte_laeufe.dart`)
  laedt je Held im Hintergrund hoch, nie zwei gleichzeitig, immer den
  neuesten Stand. Parallele Uploads auf derselben Basisrevision meldeten
  sonst Konflikte mit sich selbst. Online-Staende, die waehrenddessen
  eintreffen (auch das eigene Echo), werden erst nach dem Upload bewertet;
  `syncNow` wartet vorher auf laufende Uploads. Tests, die danach die Cloud
  pruefen oder die Leitung umschalten, warten mit `warteAufUebertragungen()`
  (`test/data/zustand_schnell_tippen_sync_test.dart`).
- `CodexPageScaffold` legt eine transparente `Material`-Fläche über den
  Seitenhintergrund, damit `ListTile`-/`ExpansionTile`-Hintergründe und
  Ink-Effekte sichtbar bleiben. Der Regressionstest liegt unter
  `test/ui/widgets/codex_page_scaffold_test.dart`. Dasselbe gilt für
  `KartoPapier` und `KartoFlaeche`: beide tragen diese Schicht selbst
  (`test/ui2/widgets/karto_tintenschicht_test.dart`). Flutter prüft in
  `ListTile.build` jede `ColoredBox`, `DecoratedBox` und `ShapeDecoration` mit
  Farbe zwischen Kachel und nächstem `Material` — jede neue farbige Fläche,
  die Bestandskacheln aufnimmt, braucht deshalb ebenfalls eine eigene
  `Material`-Schicht (oder `ListTileMaterial`).
- Steigerungen laufen getrennt von manuellen Korrekturen als Sitzung:
  `lib/domain/hero_advancement_entry.dart` trägt persistierbare Einträge,
  `lib/rules/derived/advancement*.dart` Optionen und Replay,
  `lib/state/advancement_providers.dart` den flüchtigen Entwurf.
  `lib/ui/screens/advancement/` bietet Katalog und Inspector-Historie;
  `workspace/workspace_advancement.dart` verbindet sie mit dem Workspace.
  `advancement_value_tile.dart` verdichtet Eigenschaften, Talente und Zauber;
  bei ausreichender Breite stehen Eigenschaften links, Basiswerte und Zukäufe
  rechts. `advancement_specialization_dialog.dart` erfasst Talentspezialisierungen.
  Deren Prüfungen liegen in `rules/derived/advancement_specialization_rules.dart`.
  Sie verwenden `AdvancementKind.talent` mit `options.action = specialization`
  und `options.specialization` als Namen; Replay erhält TaW, SE und übrige
  Talentfelder und übernimmt beide Spezialisierungsfelder synchron.
  Nur Übernehmen schreibt Werte, AP/SE und `HeroSheet.advancementHistory`
  gemeinsam, über den Ablauf `SteigerungsrundeUebernehmen`
  (`lib/ablaeufe/steigerungsrunde_uebernehmen.dart`, auch für die
  SF-Anzeige). Alte Einträge sind nicht entfernbar; ungültige Folgeeinträge
  blockieren die Übernahme. Leere Historie darf nicht ins JSON geschrieben
  werden (Bestands-Sync-Hashes). `HeroActions.saveHero` prüft für Sitzungen
  zusätzlich den erwarteten Inhalt vor dem Schreiben.
- Für Talente, Zauber, Sprachen und Schriften zeigt der Steigerungskatalog nur
  Ziele, die der Held **auf dem Bogen führt**.
  Maßgeblich ist der Schlüssel in `talents`/`spells`/`sprachen`/`schriften`,
  nicht der Wert: Ein eingeblendeter Eintrag ohne Wert (`null`) ist vorhanden,
  seine Aktivierungskosten sind nur noch offen. `AdvancementOption.isOwned`
  trägt das für **alle** Arten (Eigenschaften und Grundwerte sind immer `true`);
  zusammen mit `currentValue` ergeben sich die drei Zustände. Den Umfang steuert
  `AdvancementScope` (`lib/rules/derived/advancement_scope_rules.dart`) —
  gefiltert wird vor dem Auflösen, die UI siebt nie 800 Einträge selbst.
  Alles Übrige läuft über das Erwerbsblatt
  (`lib/ui/screens/advancement/advancement_activation_sheet.dart`), das sich
  selbst schließt und das gewählte Ziel zurückgibt; geplant wird erst danach
  beim Aufrufer, damit die Sitzung nur an einer Stelle verändert wird.
  Aktivieren und Steigern sind ein Schritt: `fromValue: -1` auf einen freien
  Zielwert, die Kosten des Schritts `-1 → 0` sind die Aktivierungskosten.
  Bei Sonderfertigkeiten nutzt der Fähigkeitenbaum dagegen `AdvancementScope.all`
  und zeigt auch neue Ketten sowie Manöver;
  `unavailableReason == 'Bereits erworben'` bleibt dabei die Sperre für
  `_validateEntry` und wird nur in der Karte als Bestandsnachweis dargestellt.
  Rituale und Liturgien haben kein `AdvancementKind` und liegen außerhalb des
  Modus — das ist keine Lücke der Aktivfilterung.
- `rules/derived/advancement_skill_tree.dart` baut Abhängigkeiten und Status
  einschließlich UND-/ODER-Knoten. `ui/screens/advancement/advancement_skill_tree_view.dart`
  bindet Suche, Filter und Erwerbsdetails an die Sitzung; `skill_tree_branch.dart`
  zeichnet die Zweige. `rules/derived/advancement_maneuver_rules.dart` löst
  Manövererwerbe einschließlich talentgebundener IDs (`id::talentId`) auf.
  `learnedManeuverIds` berücksichtigt auch Freischaltungen durch Kampf-SF.
- `ui/screens/advancement/advancement_ability_details.dart` ergänzt den
  Baum-Detaildialog um die verfügbaren Katalogangaben für Sonderfertigkeiten
  und Manöver. Die Darstellung löst Referenznamen aus dem Sitzungskatalog auf
  und verwendet `resolveProtectedValue` mit dem selektiven Passwort-Provider.
- `AdvancementContext` bündelt Held und Katalog für einen Optionsaufbau.
  `buildHeroRequirementContext` und `parseModifierTextsForHero` dürfen nie
  wieder je Option laufen — sonst baut jede der rund 280 SF-Optionen den
  vollständigen Prüfkontext neu auf. `advancementOptionsProvider` memoisiert
  die Liste je Umfang, damit die Suche keinen Katalogaufbau auslöst.
- Eigenschaftsfolgen: `rules/derived/advancement_impact_rules.dart` liefert
  Basiswertvergleiche und neu steigerbare Werte; `advancement_attribute_rules.dart`
  teilt die effektive Zielwertübertragung mit dem Replay. `hero_stat_inputs.dart`
  bereitet die gemeinsamen Modifikatoren für Übersicht und Vorschau vor.
  `ui/screens/advancement/advancement_impact_panel.dart` zeigt Rundenvergleich
  bzw. Dialogvorschau ohne Buchung; Talentgrenzen bleiben beim Optionsmodul.
- Aventurische Waehrungsumrechnung fuer Dukaten/Silber/Kreuzer liegt in
  `lib/rules/derived/currency_rules.dart`.
- Die kanonische Katalogquelle bleibt `assets/catalogs/house_rules_v1/`.
- Vor- und Nachteile liegen dort katalogisiert in `vorteile.json` und
  `nachteile.json`, ihre Regelwirkungen deklarativ als `wirkungen`
  (`lib/catalog/hero_trait_effect.dart`). Der Held speichert sie seit ARCH-02
  strukturiert in `HeroSheet.vorteilEintraege`/`nachteilEintraege`
  (`HeroMerkmal`: Katalog-ID, Wert, Auswahl, Textfragment). **Die Liste
  führt**; `vorteileText`/`nachteileText` sind nur ihre Projektion für ältere
  App-Versionen. Ändert eine ältere Version den Text, meldet
  `gleicheMerkmaleAb` die Abweichung. Sie wird **nie** still aufgelöst,
  auch nicht von `saveHero`: Die Übersicht sperrt das Bearbeiten, bis der
  Nutzer „Text übernehmen“ oder „Liste behalten“ wählt. Listen nur bei
  Belegung schreiben (Hash-Pins); migriert wird erst in `saveHero`
  (`merkmaleZumSpeichern`, nur mit geladenem Katalog), zur Laufzeit ohne
  Speichern. Mehrdeutiges wird nie geraten. Regeln erhalten Vor-/Nachteile
  nur über `werteMerkmaleAus` (`lib/rules/derived/hero_merkmal_*_rules.dart`):
  Katalogisiertes wirkt über die ID, Freies über den Textparser, nie beides.
  Ohne Katalog rechnet alles über den Text der Liste; der Äquivalenztest in
  `test/rules/hero_merkmal_rules_test.dart` hält beide Wege gleich — eine neue
  Katalogwirkung braucht dort einen passenden Namensweg oder eine bewusste
  Ausnahme. Die Einstiegsfunktionen verlangen `required RulesCatalog?
  catalog`: in `lib/` immer den vorhandenen Katalog durchreichen,
  `catalog: null` (Textweg) nur in Tests. Details in
  `docs/technical_overview.md` Abschnitt 4.11.
- Begabungen und Unfähigkeiten wirken über die Katalogwirkung `lernspalte`
  auf ihre Ziele; `ermittleBegabungen` (`hero_begabung_rules.dart`) liefert
  je Talent, Zauber, Sprache/Schrift und Ritualkenntnis einen
  `LernspaltenBefund`. **Abgeleitet, nie am Ziel gespeichert**: das Häkchen
  `gifted` bleibt daneben, eine Begabung aus Vorteil erscheint gesperrt
  (`BegabungHaekchen`). Begabung wirkt wie das Häkchen (eine Spalte,
  Maximum +5), Merkmale je passendem Merkmal; Unfähigkeit verteuert um eine
  Spalte. Neue Kostenstellen nehmen den Befund, nie `entry.gifted` allein.
  Der Textweg kennt keine Lernspalten (bewusste Ausnahme im
  Äquivalenztest).
- Mehrfach erwerbbare allgemeine Sonderfertigkeiten (Kulturkunde, Geländekunde,
  Ortskenntnis, Akklimatisierung, Berufsgeheimnis) tragen im Katalog ihre
  Auswahlmöglichkeiten (`mehrfachwaehlbar`, `varianten`, `ap_erstwerb`,
  `ap_folgeerwerb`). Jede erworbene Instanz wird als eigener Eintrag
  `Basisname (Variante)` in `HeroSheet.talentSpecialAbilities` gespeichert;
  Namensaufbau und gestaffelte AP-Vorschläge liegen in
  `lib/rules/derived/special_ability_variant_rules.dart`.
- Magische Sonderfertigkeiten nutzen dieselbe Mechanik mit `varianten_gruppen`
  (Varianten mit gruppenspezifischen Kosten): Merkmalsgroßmeister und Arkane
  Meisterschaft nach Merkmalsklassifikation, die 17 Ritualgruppen der Kategorie
  `Traditionsrituale` je Einzelritual. Merkmalskenntnisse, Repräsentationen,
  Zauberspezialisierungen und Ritualkenntnisse sind dagegen eigene Felder im
  Heldenmodell und werden nicht als Sonderfertigkeit gepflegt; ihre AP-Kosten
  stehen in `lib/rules/derived/magic_acquisition_rules.dart` bzw.
  `learning_rules.dart`. Ihre Katalogeinträge tragen deshalb
  `nur_information: true` und erscheinen im Picker ohne Erwerbsschalter.
- Vor-/Nachteile mit `{choice}` im `selectionTemplate` tragen im Katalog ihre
  Auswahl (`choiceLabel`, `choices`, `choiceSource`, `choiceFreeText`);
  `resolveTraitChoices` (`lib/catalog/hero_trait_choices.dart`) loest
  katalogabgeleitete Quellen auf. „Herausragende Eigenschaft" ist der einzige
  Eintrag mit echter Regelwirkung
  (`lib/rules/derived/attribute_trait_rules.dart`): er hebt Startwert **und**
  aktuellen Wert, das Maximum folgt über `ceil(start × 1,5)`. Die Eigenschaft
  wird deshalb **ohne** diesen Bonus eingetragen. Startwerte und Maxima gibt es
  nur über `computeHeroEffectiveStartAttributes` /
  `computeHeroAttributeMaximums` — `HeroSheet.startAttributes` trägt bereits das
  Ergebnis und darf nie erneut modifiziert werden. Details in
  `docs/technical_overview.md` Abschnitt 4.10.
- Erwerbsvoraussetzungen liegen zusätzlich zum Freitext `voraussetzungen` als
  maschinenlesbarer Block `voraussetzungen_struktur` im Katalog
  (`lib/catalog/special_ability_requirement.dart`, Schema in
  `docs/technical_overview.md` Abschnitt 4.9). Gepflegt für magische,
  allgemeine, Kampf- und karmale Sonderfertigkeiten sowie Manöver.
  Nicht modellierte karmale Voraussetzungen wie Gottheit oder Entrückung
  bleiben Hinweise zur manuellen Prüfung. Geprüft wird über `buildHeroRequirementContext` und
  `evaluateRequirements` (`lib/rules/derived/`). Ein offener Punkt sperrt nie:
  Die UI zeigt eine Checkliste (`lib/ui/widgets/requirement_checklist.dart`)
  und verlangt im Erwerbsdialog die Bestätigung „Trotzdem erwerben
  (Meisterentscheid)".
- Kampf-Voraussetzungen brauchen eigene Bedingungsarten, weil sie auf Dinge
  außerhalb der SF-Kataloge zeigen: `manoever` (steht in `manoever.json`),
  `basiswert` (AT/PA/FK/INI), `waffenmeister` (liegt in
  `combatConfig.waffenmeisterschaften`), dazu `nachteil` und `rasse_verboten`.
  Die Katalogtests unter `test/catalog/` lösen jede Referenz gegen ihren
  Bezugskatalog auf — ohne sie fällt ein Tippfehler erst im Betrieb auf, und
  dort nur als stillschweigend unerfüllte Bedingung.
- Ob eine Kampf-SF bei einem Helden aktiv ist, beantwortet ausschließlich
  `isCombatSpecialAbilityActive` (`lib/rules/derived/combat_special_ability_state.dart`).
  Ein Teil der Kampf-SF steht nicht unter `activeCombatSpecialAbilityIds`,
  sondern in eigenen Feldern (`ausweichenI`, `kampfreflexe`,
  `globalArmorTrainingLevel`); diese Zuordnung darf nicht in der UI dupliziert
  werden.
- Aufeinander aufbauende Sonderfertigkeiten teilen sich eine `kette` mit
  gemeinsamer `id` und aufsteigender `stufe`; jede Stufe bleibt ein eigener
  Katalogeintrag mit eigenen Kosten und Voraussetzungen
  (`lib/rules/derived/special_ability_chain_rules.dart`). Ketten-Logik und
  Stufen-Karte (`lib/ui/screens/shared/special_ability_chain_card.dart`) sind
  generisch über `SpecialAbilityEntry`
  (`lib/catalog/special_ability_entry.dart`), damit Kampf-Ketten (`Ausweichen`,
  `Rüstungsgewöhnung`, `Schildkampf`, `Parierwaffen`, `Beidhändiger Kampf`)
  dieselbe Darstellung bekommen wie die magischen. Alte Sammelnamen wie
  `Eiserner Wille I / II` bleiben als `alias_namen` der ersten Stufe erhalten,
  damit Bestandshelden erkannt werden.
- Die unmittelbare Vorstufe steht auch in `voraussetzungen_struktur`, einschließlich
  Zusatzpaketen und Ketten mit unnummerierter erster Stufe. Der Asset-Test
  `test/data/special_ability_chain_integrity_test.dart` prüft Vollständigkeit,
  eindeutige Stufen und rückwärts gerichtete Stufenabhängigkeiten.
- `rules/derived/special_ability_visibility_rules.dart` filtert unpassende Magie-/
  Karmabereiche anhand der effektiven Ressourcenaktivierung; Bestand und geplante
  Erwerbe bleiben sichtbar. `shared/special_ability_visibility_toggle.dart`
  speichert `HeroSheet.showInapplicableSpecialAbilities` (Standard `false`, dann
  kein JSON-Feld). Picker und Fähigkeitenbaum verwenden dieselbe Präferenz.
  `AdvancementSessionController.setShowInapplicableSpecialAbilities` persistiert
  ausschließlich die Einstellung und aktualisiert bei offener Runde deren Basis
  mit erneutem Replay. Weder Entwurf noch AP werden dabei übernommen; fremde
  Heldenänderungen lösen weiterhin einen Konflikt aus.
- Laufende Zaubereffekte (`Axxeleratus`, `Attributo`, `Armatrutz`) stehen in
  `lib/rules/derived/active_spell_rules.dart` und werden über
  `Magie-Tab > Zauber aktivieren` gepflegt. Zusatzdaten je Effekt (Zahlenwert
  und Wirkungsdauer) liegen in `HeroState.activeSpellEffects.effectDetails`.
  Der `Armatrutz` addiert seinen erzauberten RS in
  `lib/rules/derived/armatrutz_rules.dart` zur getragenen Rüstung, ohne
  Behinderung zu erzeugen; bei abgelaufener Wirkungsdauer fällt der Bonus weg.
  Die Wirkungsdauer selbst (`lib/domain/spell_duration.dart`,
  `lib/rules/derived/spell_duration_rules.dart`) ist effektunabhängig:
  Kampfrunden, Spielrunden und weitere Zeiteinheiten werden nie ineinander
  umgerechnet, der Countdown bleibt manuell, und abgelaufene Effekte werden
  nur angezeigt statt automatisch abgeschaltet.
- Der aventurische Kalender liegt kanonisch in `lib/domain/aventurian_date.dart`:
  zwölf Göttermonate à 30 Tage — **Phex** steht zwischen Tsa und Peraine und
  fehlte in der früheren Monatsliste des Abenteuer-Tabs — plus fünf Namenlose
  Tage, zusammen 365. Der Abenteuer-Tab hält keine eigene Liste mehr.
  `lib/rules/derived/aventurian_age_rules.dart` leitet daraus das aktuelle Alter
  ab: Bezugspunkt ist `HeroAppearance.geburtsdatum`, Stichtag das Datum des
  laufenden Abenteuers (`currentAventurianDate` vor `startAventurianDate`,
  ersatzweise das zuletzt abgeschlossene Abenteuer). Das Freitextfeld
  `HeroAppearance.alter` bleibt der Erschaffungswert und wird nicht berechnet.
  `geburtsdatum` darf in `toJson` **nur bei belegtem Wert** geschrieben werden:
  die Appearance-Felder landen flach im Helden-JSON und gehen in
  `heroContentHash` ein — sonst ändert sich jeder Bestandsheld und der
  Konto-Sync meldet beim nächsten Speichern Konflikte.
- Traditionen und Leiteigenschaften stehen in
  `lib/rules/derived/tradition_rules.dart` (Wege der Zauberei S. 19). Die
  Traditionen eines Helden sind die Vereinigung aus `representationen` und den
  Namen seiner Ritualkategorien — Derwische, Zibiljas, Zaubertänzer und
  Schamanen haben laut Regelwerk keine Repräsentation, wären über sie also nie
  erreichbar. Trägt eine Repräsentation mehrere Traditionen (nur `Geo`: Herr
  der Erde → KL, Diener Sumus → IN), hält
  `HeroSheet.repraesentationsTraditionen` die Wahl fest;
  `HeroSheet.magicLeadAttribute` ist nur noch die bewusste Abweichung davon.
- Aktivierbare Hausregel-Pakete liegen eingebaut unter
  `assets/catalogs/house_rules_v1/packs/<packId>/manifest.json`.
- Eingebaute Pack-Manifeste muessen ausserdem explizit in `pubspec.yaml`
  als Flutter-Assets registriert sein, damit der Settings-Screen sie laden kann.
- Importierte Hausregel-Pakete liegen im Heldenspeicher unter
  `house_rule_packs/<version>/<packId>/manifest.json`.
- Die App besitzt dafuer eine eigene In-App-Verwaltung unter
  `Einstellungen > Hausregeln > Hausregelverwaltung`.
- Die adaptive Settings-Navigation wird von `lib/ui/screens/settings_screen.dart`
  orchestriert; wiederverwendbare Teilseiten liegen unter
  `lib/ui/screens/settings/`.
- **Die Oberfläche wird neu gebaut.** Bestand (`lib/ui/`) und Neubau
  (`lib/ui2/`, Bildsprache „Kartograph") laufen nebeneinander;
  `AppSettings.oberflaeche` wählt unter `Einstellungen > Darstellung`. Die
  Weiche ist `AppRootSwitch` (`lib/ui2/shell/karto_app_root.dart`) als `child`
  von `SyncConflictGate` — der **einzige Verdrahtungspunkt** beider Bäume und
  die einzige Datei unter `lib/ui2/`, die aus `lib/ui/`
  importiert. Sie muss dort bleiben: ein zweites `AppStartupGate` baute
  Heldenspeicher, Sync und Katalog ein zweites Mal auf. Dass ein Wechsel nichts
  darunter anfasst, hängt daran, dass der Settings-Listener des Gates nur auf
  `heroStoragePath` reagiert; `test/ui2/shell/app_root_switch_test.dart` pinnt
  das. Der Neubau liest nur `heroComputedProvider` (nie dessen vier
  Ableitungen einzeln) und schreibt nur über `heroActionsProvider`.
  Die UI-Variante `klassisch` ist entfallen, es gibt nur noch Hell und Dunkel.
- **Der Neubau hat drei Arbeitsbereiche für denselben Helden**
  (`KartoArbeitsbereich`: `spielen`, `verwalten`, `entwickeln`). `KartoShell`
  zeigt Heldenwahl oder `KartoWorkspace`, die Bereichsnavigation
  (`karto_modus_navigation.dart`) ist rein darstellend und ändert selbst keinen
  Provider. Die dunkle Navigation über dem hellen Codex hat eigene Token
  (`navigation`, `navigationText`, `navigationMuted`); `schriftAufSignal` gehört
  zu `meer`/`siegel` und darf dort **nicht** ersatzweise stehen.
- **`KartoBestandsAdapter` ist die dokumentierte Übergangsbrücke** zu den
  vorhandenen Fachansichten, solange UI2 sie noch nicht selbst trägt. Die
  Schnittstelle liegt in `lib/ui2/shell/karto_bestands_adapter.dart` und
  importiert nichts aus `lib/ui/`, `lib/data/` oder einem Repository; die
  Implementierung `KartoBestandsAdapterImpl`
  (`lib/ui/bridges/karto_bestands_adapter_impl.dart`) hält die Bestandswidgets.
  Die Richtung ist entscheidend: `lib/ui/` importiert aus `lib/ui2/`, nie
  umgekehrt. `AppRootSwitch` erzeugt die Implementierung und injiziert sie;
  produktive Konstruktoren bekommen keinen stillen Fallback-Adapter. Neue
  Adaptermethoden nur mit konkretem Aufrufer und Test, beide Seiten im selben
  Commit. Die Brücke wird abschnittsweise entbehrlich, ihre Entfernung ist kein
  Abnahmekriterium.
- **Die Spielansicht des Neubaus liegt in `lib/ui2/spielen/`.**
  `KartoSpielansicht` liest `heroComputedProvider(heroId)` **einmal** und reicht
  den `HeroComputedSnapshot` an alle Abschnitte weiter — auch an die
  Adaptermethoden, damit die Brücke für dieselben Werte keine zweite
  Providerbeobachtung aufmacht. Die Reihenfolge ist überall Ressourcen,
  Schnellaktionen, Eigenschaften, Vor- und Nachteile, Kampf, Effekte, Zustand,
  Würfelprotokoll; ab
  `KartoBreite.breit` wandern Kampf, Effekte und Zustand in eine Seitenspalte,
  das Protokoll bleibt der letzte Abschnitt beider Anordnungen. Den
  Re-Entrancy-Guard reicht `KartoWorkspace` als `KartoLaufzeitAktion` herein;
  die Spielansicht macht keinen zweiten Fehlerweg auf.
- **Vor- und Nachteile bearbeitet UI2 im Merkmalsblatt**
  (`lib/ui2/merkmale/`), nach dem Muster des Abenteuerblatts: modal, eigener
  Schreibweg über `HeroActions.updateHero` und `aendereMerkmale`
  (nur die Merkmalslisten samt Projektion), Fehler im Blatt, bei offener
  Planung schreibgeschützt. Eine Abweichung durch eine ältere App löst es nur
  über die beiden Knöpfe (`loeseMerkmalAbweichung`); bis dahin ist Anlegen und
  Ändern dieser Art gesperrt, `aendereMerkmale` wirft sonst. Karteninhalt
  (Katalogname, Stufe/Auswahl, Wirkungstexte, Herkunft) liefert
  `beschreibeMerkmal` (`hero_merkmal_anzeige_rules.dart`) aus denselben
  Beträgen wie die Rechnung. Einstieg ist der Abschnitt „Vor- und Nachteile“
  der Spielansicht; vor Abenteuer- und Merkmalsblatt läuft dieselbe
  Editorprüfung `vorHeldenbearbeitung`. Der Übersichts-Tab der Verwaltung
  bleibt parallel bestehen.
- `KartoRessourcenwert` ist rein darstellend. Der Balkenanteil wird auf 0..1
  begrenzt, der **gespeicherte Wert nie**: negative Lebenspunkte, Überheilung
  und Maximum 0 bleiben unverkürzt lesbar. AsP und KaP zeigt
  `KartoRessourcenleiste` nur bei tatsächlich aktivierter Ressource
  (`resourceActivation`), nie aufgrund einer Profession. Karma bekommt bewusst
  keine eigene Farbe — nur LeP, AsP und AuP haben ein Ressourcentoken.
  Bearbeitet wird über `ressourceBearbeiten`, das in der Brücke den vorhandenen
  `InspectorVitalBlock` in einem Blatt öffnet (±5/±1, Zurücksetzen,
  Untergrenze `kVitalFloor`). **Nicht** `showResourceStepperDialog`: der klemmt
  auf `0..max` und könnte negative Werte gar nicht erzeugen.
  Ressourcenänderungen verwenden `HeroActions.updateHeroState`: vor dem
  Schreiben den Zustand aus dem gemeinsamen Repository neu laden und nur das
  betroffene Feld ersetzen. Ein beim Rendern erfasster Gesamtsnapshot darf
  zwischenzeitliche Änderungen anderer Ressourcen nicht überschreiben.
  Dieser Weg ist keine Transaktion gegen parallele externe Schreibvorgänge.
- Eigenschafts- und Kampf-Schnellproben liegen seit R2 als
  `InspectorAttributeProbes` und `InspectorCombatProbes` in
  `inspector/widgets/`; `InspectorProbeTab` ist nur noch ihre Zusammenstellung.
  Beide Oberflächen benutzen dieselben Bausteine und dieselben Widget-Keys.
  Requests entstehen ausschließlich über `probe_request_factory.dart`
  (Re-Export von `rules/derived/probe_request_rules.dart`; TaW* je Talent
  liefert `talent_probe_rules.dart` für Probensuche und Gefecht),
  gewürfelt und protokolliert wird über `showLoggedProbeDialog` — UI2 kennt
  keine W20-/W6-Simulation. Strg/Cmd+K öffnet dieselbe Suche, aber nur im
  Bereich Spielen: der `IndexedStack` hält die anderen Bereiche am Leben,
  deshalb entscheidet der aktive Bereich, nicht die Position im Baum.
- `InspectorArcaneEffectsBlock` ist Consumer-Wrapper um die darstellende
  `InspectorArcaneEffectsView`. Die Chipliste baut
  `lib/rules/derived/active_spell_display_rules.dart` — eigene Datei, weil
  `active_spell_rules.dart` von `combat_rules` und `magic_rules` importiert
  wird und sie deshalb nicht zurückholen darf.
- „Schaden erhalten“ ist ein geführter Ablauf (ARCH-05):
  `rules/derived/schaden_rules.dart` rechnet SP, **Vorschlag** der Wundzahl
  (je echt überschrittene Wundschwellenstufe, verschoben um den
  Angriffsmodifikator, z. B. Armbrustbolzen −2) und Zusatzwürfe der Zone;
  `ablaeufe/schaden_erhalten.dart` bucht frisch mit Protokolleintrag
  (`ProbeType.damage`). Die Wundzahl entscheidet der Nutzer im Dialog
  (`ui/screens/workspace/schaden/`), UI2 öffnet ihn über
  `KartoBestandsAdapter.schadenErhalten`. Die Regeln sind per
  dsa-rules-MCP gegen WdS S. 57 f. validiert (Belege: Roadmap ARCH-05,
  Teilstand 4): LeP haben keine Untergrenze. TP(A) senken die AuP bis 0
  **und** zur Hälfte (kaufmännisch) als echte SP die LeP; diese können
  Wunden schlagen (WS dann +2, im Dialog vorbelegt). Es gibt genau **drei**
  Wundschwellen (0,5 / 1 / 1,5 KO, ganzzahlig kaufmännisch gerundet,
  Eisern/Glasknochen ±2), also höchstens 3 Wunden je Treffer;
  `computeWundschwelle` ist die erste davon. Wunden eines Angriffs werden nur **gemeinsam** unterdrückt
  (`bieteWundUnterdrueckungAn(neueWunden: n)`), nie einzeln. Die
  SB-Erschwernis zählt nach WdS S. 83/111 **alle bisher erlittenen Wunden,
  auch unterdrückte** (4 je Wunde), mehrere aus einem Treffer pauschal
  +8/+12 — nicht nur die neuen; so mit dem Nutzer entschieden (Roadmap
  ARCH-05, Nachtrag zu Teilstand 6).
- **Wunden wirken nach Gesamt- und Zonensystem** (Hausregel „Erweiterung und
  Überarbeitung“ S. 3, per dsa-rules-MCP belegt, Roadmap ARCH-05 Teilstand 6):
  je Wunde allgemein AT/PA/FK/INI-Basis/GE −2, GS −1, dazu die Zonentabelle
  aus `rules/derived/wund_zonen_rules.dart` (WdS S. 108 f.). Eine pauschale
  Proben-Erschwernis gibt es nicht. Eigenschaftsverluste wirken **nur auf
  Proben**: über `HeroComputedSnapshot.probenEigenschaften` bzw.
  `wendeWundVerlusteAn`, **nie** über `effectiveAttributes` (WdS S. 111: nicht
  auf Basiswerte; die App lässt auch LeP, MR und Wundschwelle unberührt). Wer
  würfelt, nimmt die Probenwerte. Armwunden sind armgebunden
  (`schwertarmAtPaMalus` auf die Hauptwaffe, `schildarmAtPaMalus` auf
  Nebenhandwaffe und Schild-PA, nicht auf Fernkampf); rechts ist der
  Schwertarm, mit dem Katalogschalter `linkshaender` (Vorteil Linkshänder)
  links. Die gespeicherten 2W6 der Kopfwunde (`kopfIniMalus`) betreffen nur die
  aktuelle INI und sind Hinweis, kein Basisabzug. Wunden senken die GS nie
  unter 1 (`begrenzeWundGs`). Anzeige über `wund_anzeige_rules.dart`.
- „Schaden zurücknehmen“ (ARCH-06) gibt es nur am Protokolleintrag einer
  gebuchten Schadensbuchung: `SchadenErhalten` vermerkt mit der Vorgangs-ID
  des Dialogs eine `ZustandsBuchung` (`HeroState.buchungen`, nur bei
  Belegung im JSON) und bucht dieselbe ID nie zweimal. `SchadenZuruecknehmen`
  bucht die Gegenbuchung: tatsächlich abgezogene LeP/AuP zurück, ohne
  Obergrenze, Wunden des Treffers soweit noch vorhanden, nur einmal je
  Buchung. Regeln in `schaden_ruecknahme_rules.dart`.
- Nicht enthalten und bewusst nicht erfunden: allgemeiner Rücknahmeknopf,
  KR-Zähler, persistente Favoriten, Offline-/Sync-Status ohne echten
  Providerzustand. Ein Test in `test/ui2/spielen/` hält das fest.
- Der Kopf von `WorkspaceManagementBody` (nur UI2) ist der
  `KartoSeitenkopf`: Kontext „Heldenbogen“ (schmal ohne), Tab als Titel,
  Helfertext als Unterzeile; `management-active-title`/`-helper` hängen über
  `titelSchluessel`/`unterzeileSchluessel` daran. Die oberste Reiterreihe
  setzt Meer-Unterstrich und Schrift selbst, alle inneren Reiter kommen als
  ruhige Pille aus dem Feinschliff. In UI2 zeigt der Planungsverlauf keine
  AP-Zeilen (`AdvancementHistoryPanel.zeigeApZeilen: false`), die Bilanz
  steht auf breiten Fenstern rechts über der Historie, mobil als Gleichung
  über dem Katalog. `HeroesHomeScreen` bekommt dort
  `onHeldOeffnen` und `onEinstellungen`: „Held öffnen“ wählt den Helden für
  den Kartograph-Workspace statt den klassischen `HeroWorkspaceScreen`
  aufzulegen.
- **Tabs, Editoraktionen und Leave-Guard der Heldenverwaltung liegen im
  `WorkspaceManagementCoordinator`** (`lib/ui/screens/workspace/`), den
  **beide** Oberflächen benutzen: der bestehende `HeroWorkspaceScreen` und der
  `WorkspaceManagementBody` des neuen Rahmens. Eine zweite
  Bearbeitungsimplementierung darf nicht entstehen, sonst laufen Speichern,
  Verwerfen und Tabwechsel auseinander. Die Abschnittsliste kommt weiterhin aus
  `buildWorkspaceTabs`/`visibleWorkspaceTabsForHero`; UI2 pflegt keine zweite.
  Eine laufende Verlassen-Prüfung sperrt auch die direkten Editoraktionen
  einschließlich Speichern und Abbrechen. Der Koordinator meldet Beginn und
  Ende dieser Sperre an beide Hosts, auch bei Abbruch oder Speicherfehler.
- **Offene Entwicklung erhält die Verwaltung zum Ansehen.** Vor Bearbeiten
  und direkten Heldenbogenaktionen fragt `shared/planung_bearbeiten_guard.dart`
  nach: „Abbrechen“ erhält die Sitzung; „Planung verwerfen und bearbeiten“
  verwirft ausschließlich den noch nicht übernommenen Plan. Der Guard
  serialisiert Rückfragen je Held, prüft die Sitzungs-ID nach dem Dialog und
  sperrt Bearbeiten während der Übernahme. `PlanungsBearbeitungsBereich`
  reicht die Helden-ID an eingebettete Ausrüstungseditoren weiter. Das Geldfeld
  und Ausrüstungsformen bleiben durch `PlanungsFormularSchutz` während einer
  Planung nur lesbar; Inventardetails lassen sich über den Namen öffnen.
  Scrollen und Abschnittswechsel bleiben möglich. `aendereHeldImEditor`
  behält die technische Schreibsperre als Rückfall. Wechsel, die den Workspace
  abbauen (Heldenwahl,
  Heldenliste, Rückkehr zur Bestandsoberfläche, System-Zurück), fragen
  zusätzlich nach dem offenen Plan; aufgelegte Screens (Einstellungen,
  Token-Blatt) prüfen nur den Editor, weil die Sitzung im gemeinsamen
  `ProviderScope` liegt und einen Push überlebt.
  Beim tatsächlichen Oberflächenwechsel in den Einstellungen greift jedoch
  dieselbe Planabfrage: `KartoBestandsAdapter.einstellungen` reicht
  `vorOberflaechenwechsel` an `SettingsScreen.beforeSurfaceChange` weiter.
  Beide Settings-Layouts prüfen vor dem Schreiben; Abbruch und fehlgeschlagene
  Planübernahme erhalten Oberfläche und Sitzung. Laufende Wechsel sind gesperrt.
- **Solange beide Oberflächen parallel laufen, müssen ihre Themes
  ineinander überblendbar sein.** `MaterialApp` animiert den Themenwechsel,
  und `TextStyle.lerp` wirft, sobald zwei Stile verschiedene `inherit`-Werte
  tragen oder einer von beiden `null` ist. Daraus folgen zwei Regeln für
  `buildKartoTheme`: Schriftrollen entstehen per `copyWith` auf
  `ThemeData.textTheme` (ein mit dem Konstruktor gebauter `TextStyle` trägt
  `inherit: true`, Materials Stile `false`), und kein Komponenten-Theme setzt
  einen Textstil, den das Codex-Theme nicht auch setzt. Beides ist in
  `test/ui2/theme/karto_theme_uebergang_test.dart` gepinnt. Der Fehler zeigt
  sich **nur** beim Übergang, nie beim Bau eines einzelnen Themes.
- Kartograph-Token liegen in `lib/ui2/theme/` (`KartoTheme` als
  `ThemeExtension`, 25 rollenbenannte Farben einschließlich der drei
  Ressourcenfarben, `messing`/`messingNavigation` und `schatten`, zwei
  Paletten), die
  helligkeitsunabhängigen Skalen in `lib/ui2/foundation/` (`Abstand`,
  `Strich`, `KartoBreite`, `KartoTiefe`, `Bewegung`). Abstände, Linienstärken und Breakpoints gehören
  bewusst **nicht** ins Theme. Linienstärke trägt die Hierarchie: `kueste`,
  `grat` und `hoehenlinie` sind fest an die gleichnamigen Farbtoken gepaart.
  Das Token-Blatt (`lib/ui2/debug/karto_token_sheet.dart`) zeigt alles auf
  einer Seite und ist im Debugmodus aus der neuen Oberfläche erreichbar.
- **Tiefe trägt die Fläche, Gliederung die Linie** — beide dreistufig.
  `senke` < `blatt` < `feld` gilt in **beiden** Paletten (hell wird `feld`
  heller, dunkel weniger dunkel); gesetzt wird eine Stufe nie direkt, sondern
  über `KartoFlaeche` / `KartoFlaechenstufe`
  (`lib/ui2/widgets/karto_flaeche.dart`), das auch die Paarung Strichgewicht ↔
  Farbtoken erzwingt. Verteilung: Seitengrund `blatt`, Abschnitte/Karten/
  Dialoge `feld`, Kontextspalten und Eingabefelder `senke`, schwebendes
  (Tooltip, Snackbar) `senke`. Ein Eingabefeld auf `feld` wäre innerhalb eines
  Abschnitts farbgleich und damit unsichtbar. **Liegendes wirft keinen
  Schatten, Schwebendes schon**: Dialog, Blatt, Menü, Snackbar, Tooltip und
  die Hover-Anhebung antippbarer Karten nehmen `KartoTiefe`
  (`lib/ui2/foundation/karto_tiefe.dart`, zwei Stufen, Farbe `schatten`);
  Karten, Chips und Knöpfe bleiben bei `elevation: 0`. Verläufe gibt es nur
  im Navigationsgrund und im Wappenschein. Radien: `kKartoRadius` 8 für
  Flächen, `kKartoRadiusKlein` 4 für Chips und Knöpfe — mehr Stufen nicht.
- **Atmosphäre kommt aus Ornament, Papier und kurzer Bewegung**, nie aus neuer
  Bedeutung. Ornamente (`lib/ui2/widgets/karto_ornamente.dart`: Kompassrose,
  Kompassring, Höhenlinien, Zierlinie, Stern) sind deterministische
  CustomPainter ohne Semantik und Hit-Test und zeichnen in `messing` — das ist
  **nie** Textfarbe, deshalb genügt 3:1 als Grafik. `KartoPapier`
  (`lib/ui2/widgets/karto_papier.dart`) legt hell die vorhandene
  Pergamenttextur per Multiplikation auf `blatt`, dunkel bleibt der Grund
  glatt; Rasterbilder müssen `KartoPapier.textur` vorab laden. Jede Animation
  nimmt ihre Dauer über `kartoDauer` (`lib/ui2/foundation/karto_bewegung.dart`)
  und steht bei abgeschalteten Systemanimationen sofort am Ziel. Begleitflächen
  heben sich nur über `KartoAkzent` (Messingkante, astrale Tönung) ab, nie
  über freie Farben.
- Im Bestandsbaum (`buildKartoCompatTheme`) trägt `bodySmall` die aufrechte
  Datenschrift statt der kursiven Spectral-Legende
  (`buildKartoBestandsTextTheme` in `karto_typography.dart`): die
  Altansichten setzen dort fast alle kleinen Beschriftungen. Von den
  Schriftrollen weicht nur dieser Slot ab;
  `test/ui/bridges/karto_compat_theme_test.dart` hält `inherit` und die
  Überblendbarkeit fest.
- **Komponenten-Textstile gibt es nur verschachtelt.** `buildKartoFeinschliff`
  (`lib/ui2/theme/karto_feinschliff.dart`) setzt Dialogtitel (`titel`),
  `DataTable`, `ExpansionTile`, die ruhigen inneren Reiter (`senke`-Pille),
  das Blatt (Radius 8, Küste) und `KartoRahmen` als Dialogform
  (`lib/ui2/theme/karto_rahmen.dart`: Küste rundum, Messingkante oben). Er
  liegt als `Theme` in `KartoShell` und wird in `buildKartoCompatTheme`
  erneut angewendet, weil Routen nur das Wurzeltheme sehen; das überblendete
  Wurzeltheme bleibt ohne Komponenten-Textstile
  (`test/ui2/theme/karto_feinschliff_test.dart`). Die Container-Rollen des
  `ColorScheme` sind dagegen reine Farben und liegen im Wurzeltheme
  (Auswahl in Messing, sonst fiele Material auf siegelrot zurück).
- Aufgelegte Seiten aus dem Bestand (Einstellungsdetail, Katalog- und
  Hausregelverwaltung, Heldenliste, Anmeldung) nehmen das Theme ihres
  Aufrufers per `InheritedTheme.captureAll` mit; sonst fiele unter
  Kartograph die Brücke weg und `CodexTheme` auf Pergament zurück.
- **Bestandsbausteine haben eine Kartograph-Variante, die klassische
  Oberfläche bleibt Zeichen für Zeichen, wie sie war.** Erkannt wird über
  `kartoVariante(context)` (`lib/ui/widgets/karto_variante.dart`): nur
  Kartograph führt `KartoTheme` im Theme, das Codex-Theme allein
  `CodexTheme` — nie `KartoTheme.of`, das fiele auf die helle Palette zurück.
  Dort liegen auch `epischerAkzent` (klassisch Goldgelb, Kartograph Messing)
  und `kartoRadiusOder`. Umgestellt sind u. a. `CodexSectionCard`,
  `CodexTabHeader`, `CodexMetricTile`, `CodexBadge`, `CodexEmptyState`,
  `CodexPageScaffold`, `FlexibleTable` (neu `numerischeSpalten`, nur unter
  Kartograph rechtsbündig), `ResponsiveAdaptiveTable`, `EditAwareTableCell`,
  `InspectorVitalBlock`, `AnimatedDiceRow`, `AdvancementOptionCard`,
  `skill_tree_branch.dart`, Reisebericht-Farben, Heldenliste und Anmeldung.
  `test/ui/widgets/karto_variante_test.dart` prüft jeden Baustein unter
  beiden Themes. Neue Bestandsbausteine folgen demselben Muster.
- Jede Arbeitsfläche beginnt mit `KartoSeitenkopf`
  (`lib/ui2/widgets/karto_seitenkopf.dart`): Kontextzeile, Titel, eine Aktion,
  getrennt durch Weißraum statt Linie. Er ist die **einzige** Verwendung von
  `titelGross`, und die Kontextzeile steht nur dort, nie über einem Abschnitt.
  In der Spielansicht trägt das erste laufende Abenteuer mit Titel den
  Seitentitel; `Am Spieltisch` rückt dann in die Kontextzeile, darunter folgen
  optional `unterzeile` (aventurisches Datum, aktueller Stand vor Startdatum,
  nur aus **demselben** Abenteuer) und eine auf 3 bzw. 2 Zeilen gekürzte
  `beschreibung` (Zusammenfassung). Ohne laufendes Abenteuer bleibt
  `Am Spieltisch` der Titel.
  Einen Knopf gibt es dafür nicht: `KartoSeitenkopf.onTap` macht den ganzen
  Abenteuerkopf antippbar (Pfeil hinter dem Titel, Tooltip „Abenteuer öffnen“,
  Key `karto-spiel-abenteuer`). Er öffnet das Abenteuerblatt
  (`lib/ui2/spielen/karto_abenteuerblatt.dart`, Dialoge in der Teildatei
  `karto_abenteuer_dialoge.dart`): Datum, Zusammenfassung,
  Notizen und Personen lesen und pflegen, Abschluss und Belohnungen bleiben in
  der Verwaltung. Das Blatt ist eine eigene Seite (Grund `blatt`); Personen
  und Notizen stehen als `feld`-Karten im `KartoKartenraster`
  (`lib/ui2/widgets/karto_kartenraster.dart`, geteilt mit der Heldenwahl),
  Personen mit demselben `KartoKompassring` wie die Heldenmarke, Anlegen als leise `senke`-Kachel am Rasterende. Es ist UI2-eigen, weil der Notizen-Tab beim Speichern seinen
  **ganzen** Entwurf (Notizen, Kontakte, alle Abenteuer) über den Helden legt.
  Das Blatt schreibt dagegen nur dieses eine Abenteuer, über
  `HeroActions.updateHero` (frisch laden, dann ändern, analog zu
  `updateHeroState`) und `ersetzeAbenteuer`
  (`karto_laufendes_abenteuer.dart`). Vor dem Öffnen läuft die Editorprüfung
  der Verwaltung, sonst überschriebe ein späteres Speichern dort die Einträge.
  Gespeichert und Fehler angezeigt wird im Blatt selbst, **nicht** über
  `KartoLaufzeitAktion`: das Öffnen läuft bereits in deren Re-Entrancy-Guard,
  jede weitere Aktion darin würde still verworfen. Bei offener Planung ist das
  Blatt schreibgeschützt, weil jede Heldenänderung den Inhalts-Hash der Runde
  bräche.
  Der Seitentitel `Am Spieltisch` darf die Navigationsbeschriftung nicht
  wiederholen; die Navigationsprüfungen erwarten sie genau einmal.
  In der Planung entfällt der zusätzliche Seitentitel auf allen Breiten:
  der Katalog führt bereits die Überschrift „Steigerungen planen“.
- Die dunkle Bereichsnavigation trägt oben die Markenzeile und
  `KartoHeldenmarke` (Avatar oder Monogramm im `KartoKompassring`, Name,
  Profession) und unten `Heldenauswahl` und `Workspace-Menü`; auf breiten Fenstern gibt es deshalb
  **keine** `AppBar`, auf schmalen bleibt sie. Beide Tooltips müssen wortgleich
  erhalten bleiben. Der Avatar kommt über `KartoBestandsAdapter.heldenbild`,
  nicht über ein eigenes Bildwidget auf `avatarBytesProvider`: Bilder rendert
  ausschließlich `AvatarGalleryImage`. Die Heldenwahl bekommt dieselbe
  Methode als `heldenbild` hereingereicht. „Entwicklung planen“ zeigt die Zahl
  vorgemerkter Einträge der offenen Runde als Marke; der Semantics-Name bleibt
  unverändert, die Zahl steht als Wert. Der Bereichswechsel blendet über, der
  `IndexedStack` darunter bleibt.
- Zahlen mit Bezugsgröße werden als **ein** `Text.rich` aus mehreren Spans
  gesetzt, nicht als mehrere `Text`. So trägt der aktuelle Wert das Gewicht und
  die Bezugsgröße bleibt leise, während `find.text` die Zeile weiterhin als
  Ganzes findet — der Finder fällt bei fehlendem `Text.data` auf
  `textSpan.toPlainText()` zurück. Genutzt von `KartoRessourcenwert`
  (`'27 / 22'`) und `KartoApUebersicht` (`'Frei zu Beginn: 1375 AP'`); beide
  Formate sind wörtlich gepinnt.
- Schriften des Neubaus: **Spectral** (statisch, vier eigene Schnitte) für
  Titel, **Inter Tight** (nur variabel, Gewicht über `fontVariations`) für
  Daten. Innerhalb einer Familie darf kein `asset:`-Pfad zweimal stehen —
  genau das machen Merriweather und Cinzel heute, deren Fettschnitt deshalb
  dieselben Glyphen liefert wie der reguläre. `test/ui2/theme/` prüft das
  doppelt: das Manifest auf doppelte Pfade, und `karto_weights_test.dart`
  **misst** die Zeichenbreiten, weil eine Behauptung im Manifest sonst nicht
  auffällt. Tests, die Schriften brauchen, laden sie über
  `test/ui2/theme/karto_test_fonts.dart`; ohne das misst `flutter test` die
  Ersatzschrift.
- Auf einen asynchronen Provider darf **nicht** mit
  `ref.read(provider.future)` gewartet werden. In Riverpod 3.2 wird diese
  Future bei einem Fehler nie erfüllt — der Provider geht in `AsyncLoading`
  **mit** angehängtem Fehler, und auch das `onError` der Future feuert nie;
  zusätzlich wird ein Provider ohne aktiven Listener nach einer Änderung
  seiner Abhängigkeiten gar nicht erst neu gebaut. Beides zusammen ergibt
  einen Ladezustand, der nie endet. Wer warten muss, abonniert stattdessen den
  `AsyncValue` (`ref.listenManual`) und wertet `error` und `hasValue` aus;
  Muster: `_awaitCatalogReady` in `lib/ui/screens/heroes_home_screen.dart`.
  Die Katalogkette in `lib/state/catalog_providers.dart` benutzt weiterhin
  `await ref.watch(dep.future)` — bewusst: ein `ref.watch(dep)` im
  Provider-Body macht den Provider rebuild-abhängig und bricht dadurch den
  Erfolgsfall, sobald niemand lauscht. Fehler in der Kette bleiben deshalb
  unsichtbar; auffangen muss sie die wartende Stelle per Timeout.
- Dialoge, die auf dem Root-Navigator liegen, müssen sich **selbst**
  schließen. Ein `Navigator.pop()` des Aufrufers hinter einem
  `context.mounted`-Guard genügt nicht: `SyncConflictGate` tauscht den
  `HeroesHomeScreen` unter der `MaterialApp` aus, die Dialog-Route überlebt
  das, und ein `canPop: false`-Dialog bleibt dann ohne jeden Schließweg
  stehen. Wartende Dialoge brauchen zusätzlich Timeout und Abbruch.
- `Einstellungen > Konto & Sync` steuert optionalen Firebase-Login,
  manuellen Konto-Sync und Konfliktaufloesung. Ohne Login nutzt die App das
  lokale Offline-Profil; mit Login nutzt sie ein getrenntes Profil unter
  `Helden/accounts/<uid>`.
- Konto-Sync für Helden läuft über `SyncingHeroRepository`, ein
  plattformspezifisches Remote-Gateway (`FirestoreHeroSyncGateway`, auf Windows
  `RestFirestoreHeroSyncGateway`), `HiveSyncMetadataStore` und die Modelle in
  `lib/domain/sync_models.dart`. Konflikte dürfen nicht still überschrieben
  werden; die UI muss lokal, online oder beide behalten anbieten.
- **Konflikte entstehen nur noch für echte Widersprüche** (ARCH-06): Nach
  jedem Abgleich legt `_saveMetadata` den Inhalt des Stands mit seiner
  Revision in `SyncBasisStore` ab (Box `sync_basis_v1`, je Konto; ohne
  Inhalt, etwa bei Löschungen, entfällt sie). Ändern beide Geräte, führt
  `fuehreSyncZusammen` (`lib/domain/sync_zusammenfuehrung.dart`) Basis,
  Lokal und Online zusammen: Maps je Schlüssel, Listen über `id`/`instanzId`,
  AP und Ressourcen als Zähler, Würfelprotokoll als Vereinigung. Ohne
  Widerspruch geschieht das still
  (`syncing_hero_repository_zusammenfuehrung.dart`), sonst bleibt der
  Konflikt: `konfliktVorschau` nennt nur die widersprüchlichen Werte,
  `resolveConflictAutomatisch` führt mit Entscheidungen je Wert zusammen
  (Schlüssel `held:`/`zustand:`), der gebundene Zustand läuft mit. Die UI
  (`SyncKonfliktKarte`, `lib/ui/widgets/sync_konflikt_karte.dart`, im Gate und
  in den Einstellungen) bietet „Nur Online“, „Nur Lokal“, „Beide behalten“ und
  „Automatisch“, in der Reihenfolge der Spalten. Ohne gültige Basis
  (Revision passt nicht, ältere Abgleiche) gibt es kein „Automatisch“; ein
  Abgleich ohne lokale Änderung trägt die Basis nach. Neue Listenmodelle
  brauchen eine stabile `id`, sonst gelten sie als unteilbar.
- Die Sync-Basis ist der **lokale** Stand: Nach dem Übernehmen eines
  Online-Stands merken `_storeHeroMetadata`/`_storeStateMetadata` den Hash
  dessen, was lokal liegt. Den Schreiber-Hash (`remoteHash`) **nie** als
  `localHash` merken: Kann diese Version den Stand nicht verlustfrei
  darstellen, gälte die verkürzte Fassung sonst als lokale Änderung und würde
  ohne Konflikt hochgeladen (Befund ARCH-07-B10). Ein lokaler Stand, der der
  hiesigen Darstellung des Online-Stands gleicht, gilt als identisch. Ein
  Abgleich allein schreibt nie. Getestet wird das mit
  `speichereFremdenStand` in `test/data/sync_app_versionen_test.dart`.
- Entscheidungen zu Offline-Helden (`Offline-Held: …`-Konflikte beim Wechsel in
  ein Konto) müssen persistiert werden, sonst wiederholt sich die Frage bei
  jedem Start: die Konfliktliste lebt nur im Speicher und keiner der drei
  Auflösungswege verändert das Offline-Profil. `SyncingHeroRepository` schreibt
  dafür ein `OfflineHeroReview` in die Box `offline_hero_review_v1` im
  Konto-Profil (`lib/data/hive_offline_hero_review_store.dart`). Der Offline-Held
  selbst wird nie gelöscht. Widerrufbar unter
  `Einstellungen > Konto & Sync > Offline-Helden`.
- Die Vergleichstabelle kennzeichnet Offline-Helden über
  `SyncConflict.isOfflineHeroConflict`: „Nur Lokal“ ersetzt den Konto-Stand
  durch den Offline-Stand oder übernimmt einen fehlenden Konto-Held. Die
  Namenszeile trägt nur den Konto-Namen bzw. `—`; ein fehlender Konto-Held ist
  keine Cloud-Löschung. „Gespeichert“ erscheint nur mit beiden Zeitstempeln.
- Avatar-Bilddateien synchronisiert der Konto-Sync **nicht** mit: sein Payload
  ist `HeroSheet.toJson()` und trägt nur Dateinamen. Die Bytes wandern über
  Firebase Storage (`avatars/{uid}/{fileName}`). `SyncingAvatarStorage`
  (`lib/data/syncing_avatar_storage.dart`) legt sich dafür um die
  plattformspezifische `AvatarFileStorage`: schreiben local-first mit
  Best-Effort-Upload, lesen mit Cloud-Fallback samt lokalem Cachen. Ob der
  Decorator greift, entscheidet `AvatarFileStorage.isCloudBacked` — im Web ist
  die Plattformimplementierung selbst der Cloud-Speicher, dort wäre er ein
  doppelter Weg. Löschen betrifft immer beide Seiten und alle Quellen; die
  frühere Sonderbehandlung von `quelle == 'ki'` gibt es nicht mehr.
- Bestandsbilder holt `AvatarBackfillService`
  (`lib/data/avatar_backfill_service.dart`) nach, angestoßen in
  `AppStartupGate` **nach** `syncNow()` und ohne `await`. Die Reihenfolge ist
  korrektheitsrelevant: vor dem Sync wäre die lokale Galerie veraltet, und ein
  auf einem anderen Gerät gelöschtes Bild käme wieder hoch. Der Service darf
  **nie** `saveHero()` aufrufen — das änderte `lastModified` und löste bei
  jedem Start eine Konfliktwelle aus. Abgeglichene Dateien vermerkt die Box
  `avatar_sync_v1` (`lib/data/hive_avatar_sync_marker_store.dart`); sie liegt
  im Kontoprofil, weil der `avatare`-Ordner bewusst profilübergreifend geteilt
  bleibt (eine Umstellung auf `accounts/<uid>/avatare/` würde jeden
  Bestandsavatar unsichtbar machen).
- Dateinamen dürfen nie aus `heroId` und `entryId` rekonstruiert werden:
  Bestandshelden tragen den Legacy-Eintrag `{heroId}_legacy` mit dem Dateinamen
  `{heroId}.png`, der dabei verlorenginge. Maßgeblich ist immer
  `AvatarGalleryEntry.fileName`. Der Import
  (`lib/ablaeufe/held_importieren.dart`) übernimmt deshalb den Namen, den die
  Ablage zurückgibt, nie den aus dem Export.
- Ob ein Held ein Bild hat, beantwortet `HeroAppearance.hatBild`, welches
  angezeigt wird `HeroAppearance.aktivesBild`. `avatarFileName` bleibt als
  Bestandsfeld im Modell (Entfernen erzeugte auf jedem Gerät einen Helden-Diff
  und damit Konflikte), wird aber nicht mehr gelesen. Bilder rendert
  ausschließlich `AvatarGalleryImage`
  (`lib/ui/widgets/avatar_gallery_image.dart`) über `avatarBytesProvider`. Die
  Bytes sind `Uint8List` und müssen unverändert an `Image.memory` gereicht
  werden — ein `Uint8List.fromList(...)` im Widget verfehlt den globalen
  `ImageCache` bei jedem Rebuild, weil `MemoryImage` seine Bytes per Identität
  vergleicht.
- Beschnittene Avatarflächen (Heldenmarke, Album, Header, Gruppen-Thumbnail)
  richten sich am erkannten Gesicht aus: `AvatarGalleryImage(rahmung: ...)`,
  Geometrie in `lib/rules/derived/avatar_rahmung_rules.dart`. Erkannt wird mit
  BlazeFace **in reinem Dart** (`lib/data/avatar_gesicht/`, Modell-Asset aus
  `tool/avatar_gesicht/`), ohne native Bibliothek und ohne CDN. Neue Bilder
  bekommen den Befund **beim Anlegen** (`uploadHeroImage`, `saveHeroAvatar`)
  als `AvatarGalleryEntry.gesichtsbefund` — im selben `saveHero`, der ohnehin
  läuft, im JSON (`gesicht`) nur bei belegtem Wert. **Nie nachträglich** in
  einen Helden schreiben: das Feld geht in `heroContentHash` ein, ein
  Nachtragen für Bestandsbilder löste Sync-Konflikte aus. Bestandsbilder
  nutzen den lokalen Cache `avatar_gesicht_v1` (`AvatarGesichtService`);
  `avatarGesichtProvider` nimmt zuerst den Eintrag, dann den Cache. Der Golden-Test
  `test/data/avatar_gesicht/blazeface_golden_test.dart` pinnt den Rechenkern
  gegen Googles LiteRT; seine Fixtures werden nicht angepasst, wenn er bricht.
  Nach Modellwechsel steigt `kAvatarGesichtDetektorVersion`. In Widget-Tests
  `avatarGesichtServiceProvider` mit `festerAvatarGesichtService()`
  überschreiben: die echte Erkennung rechnet im Isolate und wird im
  Fake-Async nie fertig. Details in `docs/technical_overview.md` Abschnitt 1.
- Ein fehlgeschlagener Bildzugriff darf nie stumm als „kein Bild" erscheinen.
  `AvatarLoadException` (`lib/data/avatar_load_failure.dart`) trägt den Grund
  (nicht angemeldet, keine Berechtigung, zu groß, Netzwerk, unbekannt);
  `AvatarGalleryImage` zeigt Laden, Fehlen und Fehlschlag als drei getrennte
  Zustände. Nur echtes `object-not-found` liefert weiterhin `null`. Wichtig für
  Web: `firebase_storage_web` lädt die Bytes nicht über das JS-SDK, sondern per
  `getMetadata()` → `getDownloadURL()` → `http.readBytes`, und `guard()` reicht
  alles außer Firebase-Fehlern unverändert durch — ein reines
  `on FirebaseException` verpasst deshalb Netzwerk- und Typfehler.
- Die Web-App läuft bewusst auch ohne Login (`WebAuthGate` reicht `null` durch).
  Ohne Konto gibt es keinen Cloud-Pfad und damit keine Avatarbilder.
- Beim lokalen Web-Debuggen ist `--web-port=5000` **Pflicht**, nicht Komfort:
  Firebase Auth und Hive persistieren pro Origin, und die CORS-Regel des
  Storage-Buckets nennt genau diesen Port. Ein zufälliger Port bedeutet
  abgemeldete Sitzung, leeren Speicher **und** blockierte Bilder. Die Pflicht
  hängt am Port, nicht am Browser: `flutter run -d chrome --web-port=5000`
  und `flutter run -d edge --web-port=5000` sind gleichwertig. Auf Maschinen
  ohne Chrome meldet `flutter doctor` „Cannot find Chrome" und `flutter
  devices` listet nur Edge — dann entweder `-d edge` nehmen oder
  `CHROME_EXECUTABLE` auf eine Chrome-Installation setzen.
- Der Storage-Bucket braucht eine **CORS-Konfiguration**, sonst sind Avatare im
  Web unsichtbar. `firebase_storage_web.getData()` lädt die Bytes per
  `http.readBytes` von der Download-URL — ein normaler Browser-Fetch. Diese
  Antwort trägt ohne Bucket-Konfiguration kein `Access-Control-Allow-Origin`,
  der Browser verwirft sie, und es kommt nur `ClientException: Failed to fetch`
  an. Achtung bei der Diagnose: Eine `OPTIONS`-Anfrage auf dieselbe URL
  antwortet mit `Access-Control-Allow-Origin: *` (Upload-Server) und führt in
  die Irre — geprüft werden muss der **GET**. Die Konfiguration liegt als
  `cors.json` im Repo und wird **nicht** von `firebase deploy` übertragen,
  sondern mit
  `gsutil cors set cors.json gs://heldensync-ccf0b.firebasestorage.app`
  (z. B. in der Google Cloud Shell). `cors.json` hat zwei Einträge: zuerst die
  drei bekannten Origins (die bekommen ihre exakte Origin zurückgespiegelt),
  danach eine Sammelregel `"origin": ["*"]` für lesende Zugriffe. Die
  Sammelregel deckt auch die feste Test-Site und manuelle Preview-Channels ab.
  Automatische Branch-Previews entfallen; siehe `docs/web_deployment.md`.
  GCS erlaubt keine Wildcard innerhalb einer Origin. Schreibzugriffe laufen
  über das Firebase-SDK und bleiben ohne CORS-Freigabe.
- Im Web liegen geladene Avatarbytes zusätzlich in der Hive-Box
  `avatar_blobs_v1` (IndexedDB, `lib/data/hive_avatar_blob_cache.dart`), damit
  ein Reload sie nicht erneut herunterlädt. Der Cache ist inhaltsadressiert und
  kann nicht veralten, weil `AvatarGalleryEntry.fileName` eine UUID trägt;
  aufzuräumen sind nur verwaiste Einträge, das erledigt
  `AvatarCacheReconciler` beim Start nach `syncNow()`. Bewusst **kein**
  `SyncingAvatarStorage` im Web: dort gilt der lokale Write als Erfolg, aber
  IndexedDB ist kein haltbarer Speicher — im Browser zählt ein Bild erst als
  gespeichert, wenn der Upload durch ist.
- Inhaltlich identische Datensätze sind aber kein Konflikt: `isSyncContentIdentical`
  (`lib/domain/sync_object_diff.dart`) entscheidet das mit derselben Logik wie
  die Konflikt-UI (umsortierte Listen, `lastModified`/`schemaVersion` zählen als
  gleich); in dem Fall übernimmt die App die Online-Version und überspringt den
  Datensatz. Nur echte Unterschiede erzeugen einen Konflikt und werden als
  Tabelle `Feld | Online | Lokal` gezeigt
  (`lib/ui/widgets/sync_conflict_comparison_table.dart` mit den deutschen
  Feldnamen aus `lib/ui/widgets/sync_conflict_field_labels.dart`), sowohl im
  Start-Gate als auch unter `Einstellungen > Konto & Sync`.
- Ein `HeroState` gehört zu genau einem Helden und wird nie gegenläufig zu ihm
  entschieden: Solange zu einem Helden ein Konflikt offen ist, bekommt sein
  Zustands-Konflikt keinen eigenen Listeneintrag, sondern hängt in
  `_boundStateConflicts` am Helden-Konflikt und folgt dessen Entscheidung
  (`keepLocal` schiebt die lokalen Laufzeitwerte hoch, `keepRemote` übernimmt
  die Online-Werte, `keepBoth` gibt der lokalen Kopie die lokalen Werte). Der
  lokale Zustand muss dafür **vor** dem ersten Schreibzugriff eingelesen
  werden, sonst bekommt die Kopie die bereits übernommenen Online-Werte. Ein
  eigener `Zustand:`-Konflikt entsteht nur ohne offenen Helden-Konflikt;
  `SyncConflict.includesHeroState` steuert den Hinweis in der Konflikt-UI.
- Laufzeitzustände (`HeroState`) tragen wie `HeroSheet` ein `lastModified`,
  damit die Konflikt-UI beim `Zustand:`-Konflikt nicht auf beiden Seiten
  `Unbekannt` anzeigt. Gehasht wird ein Zustand ausschließlich über
  `heroStateContentHash` (`lib/domain/sync_models.dart`), das den Zeitstempel
  entfernt — genau wie `heroContentHash`. Wer irgendwo `stableContentHash`
  direkt auf `state.toJson()` anwendet, baut einen Scheinkonflikt bei jedem
  Speichern ein.
- Ohne Helden **und** ohne Login zeigen beide Startseiten eine hervorgehobene
  Konto-Karte (`Anmelden`, `Konto anlegen`) vor dem Anlegen: Bestand über
  `HeroHomeAccountPrompt` (`lib/ui/screens/home/`), UI2 in `KartoHeldenwahl`
  über die Adaptermethode `KartoBestandsAdapter.anmelden`. Sichtbar nur, wenn
  `authServiceProvider` einen Dienst liefert. Geöffnet wird immer
  `openSignInScreen` (`lib/ui/screens/auth/open_sign_in.dart`); der
  `SignInScreen` schließt sich nach Erfolg selbst.
- `FirebaseBootstrapResult.isAccountSyncAvailable` steuert den privaten
  Konto-Sync; `isFirestoreAvailable` steht für native Firestore-Funktionen wie
  Gruppen-Cloudaktionen und bleibt auf Windows deaktiviert.
- Der Settings-Bereich `Rechtliches` enthaelt den inoffiziellen Fanprojekt-,
  Marken- und Rechtehinweis fuer DSA und Ulisses Spiele.
- Epische Helden waehlen je eine geistige und eine koerperliche
  Haupteigenschaft (`HeroSheet.epicMainAttributes`). Sie definieren die Boni
  aus Kap. 2.1 und sind vom 25-%-AP-Aufschlag ausgenommen
  (`isEpicMainAttribute` in `lib/rules/derived/epic_main_attribute_rules.dart`,
  Parameter `isMainAttribute` in `epic_ap_cost_rules.dart`). Der
  `EpicActivationDialog` hat dafuer einen Korrekturmodus; Einstieg ist das
  Stern-Symbol der Sektion `AP und Level`.
- Die Haupteigenschafts-Boni aus Kap. 2.1 liegen als
  `epicMainAttributeBonuses` mit `EpicBonusUmsetzung` je Einzelbonus vor.
  Gerechnet werden nur zwei: eBE-Halbierung bei KK-Talenten
  (`epicTalentEbeMultiplier` → `computeTalentEbe`) und bei KO die halbierte
  SB-Erschwernis beim Unterdrücken von Wunden
  (`computeSbUnterdrueckungErschwernis(halbiert:)`, Schalter
  `WundEffekte.unterdrueckungHalbiert`, gesetzt in `computeHeroWundEffekte`);
  die halbierte Erschöpfung ist nur Hinweis. Die IN-Finte
  erscheint als Hinweis in der Kampfvorschau (Muster:
  `buildAxxeleratusDefenseHint`). Alle uebrigen Boni sind in der UI
  ausdruecklich als `manuell` gekennzeichnet — mangels Modell fuer
  Tragkraft, Gift, Krankheit, Handwerk und gezieltes Ausweichen.
- `AppSettings.tabellenAnsicht` (`automatisch`, `tabelle`, `karten`)
  ueberstimmt die Breiten-Automatik von `ResponsiveAdaptiveTable`. Ohne diese
  Einstellung weichen breite Tabellen auf Tablet-Breiten zwingend auf Karten
  aus. Bedienbar im Talente-Tab und unter `Einstellungen > Darstellung`.
- `PersistedTableColumnLayout` bindet `FlexibleTable`, `ResponsiveAdaptiveTable`
  und `DataTable` an geraeteweite Breiten unter `AppSettings.tableColumnWidths`;
  nur stabile, textlastige Spalten-IDs erhalten Resize-Griffe im Tabellenmodus.
  Selektive Settings-Provider halten Breiten-Saves aus der Katalog-Pipeline und
  dem vollstaendigen Zaubertab heraus; die Tabellen selbst lesen ihre Breiten
  ueber `tableColumnWidthsProvider(tableId)`.
- Objekte, die `AppStartupGate._buildScope` per `overrideWithValue` in den
  `ProviderScope` reicht, brauchen Wertgleichheit **und** eine stabile Instanz
  ueber Rebuilds hinweg (`CustomCatalogRepository`, `HouseRulePackRepository`
  liegen dafuer im Bootstrap-Ergebnis). Eine neue Instanz gilt sonst als
  geaenderter Override, invalidiert die Katalogkette und laesst die App
  sichtbar neu laden. Aus demselben Grund reagiert der Settings-Listener des
  Gates nur auf `heroStoragePath` — jede andere Einstellung (etwa eine
  gespeicherte Spaltenbreite) darf dort kein `setState` ausloesen.
- Reisebericht-Daten bleiben separat unter `assets/catalogs/reiseberichte/house_rules_v1/`.
  Buchen und Zuruecknehmen der Reisebericht-Belohnungen haben eine Quelle:
  die Posten in `reisebericht_rules.dart` (ID, Inhalt, Bedingung).
  `berechneReiseberichtBuchung` bucht Neues und nimmt zurueck, was
  enthakt, geloescht oder unterschritten wurde (auch Schwellen-, Gruppen-
  und Meta-Boni). Altdaten werden nie rueckwirkend korrigiert. Neue
  Belohnungsarten gehoeren in `_buchungsposten`, nie in eine eigene
  Buchungsfunktion.
- Geschuetzte Katalog-Felder (Wirkung/Varianten von Zaubern, Erklaerungstexte
  von Manoevern und Kampf-Sonderfertigkeiten) sind v3-verschluesselt
  (AES-GCM, globaler Salt im Manifest `catalog_salt_v3`). Beim Unlock
  entschluesselt `decryptedCatalogSourceDataProvider` den ganzen Katalog
  einmal — Detail in `docs/technical_overview.md` Abschnitt 5.3. Passwoerter
  werden vor PBKDF2 NFC-normalisiert, damit Eingaben mit Umlauten
  unabhaengig von NFC/NFD-Codepoint-Repraesentation funktionieren.
- Projektsprache ist Deutsch; sichtbare UI-Texte sollen echte Umlaute und das Eszett verwenden, wenn technisch moeglich.
- ListTile-/SwitchListTile-Kacheln in farbig dekorierten Panels sollen ueber
  `lib/ui/widgets/list_tile_material.dart` einen lokalen Material-Layer
  erhalten, damit Flutter-3.44-Ink- und Tile-Hintergruende sichtbar bleiben.
- Der Windows-Release-Audit fuer EXE/MSIX-Artefakte ist in `docs/windows_antivirus_audit.md` beschrieben; der zugehoerige Helfer liegt unter `tool/audit_windows_artifact.ps1`.
- Spielunterstuetzung ("Spielmodus") ist in `docs/spielmodus_konzept.md` konzipiert.
  Phase 1 umfasst die tab-unabhaengige Proben-Schnellsuche
  (`lib/ui/screens/workspace/probe_quick_search.dart`), Filter-Chips im
  Wuerfelprotokoll und den Regel-Nachschlag. Der Nachschlag liest die vom
  dsa-rules MCP-Indexer erzeugte SQLite-DB read-only per FTS5 und ist auf
  Desktop und Web sichtbar (Mobile blendet den Einstieg weiterhin aus).
  Implementierung unter `lib/data/rules_search/` (Conditional-Import-Fassade
  `rules_index_search.dart` mit IO-/Web-/Stub-Variante, plattformneutrale
  Typen in `rules_index_types.dart`), UI in
  `lib/ui/screens/workspace/rules_lookup_dialog.dart`. Desktop liest die
  Datenbank direkt vom lokalen Standardpfad (`rules_index_search_io.dart`);
  Web hat keinen Dateisystemzugriff und nutzt stattdessen `package:sqlite3`
  im WASM-Modus (`rules_index_search_web.dart`, Binärdatei `web/sqlite3.wasm`)
  mit `IndexedDbFileSystem`-Persistenz — der Nutzer laedt die am Desktop
  erzeugte `index.sqlite` einmalig ueber einen Datei-Upload im Dialog hoch;
  sie bleibt danach origin-gebunden im Browser gespeichert.
  `web/sqlite3.wasm` ist eine eingecheckte Binaerdatei, kein Build-Artefakt:
  das `sqlite3`-Package liefert auf pub.dev nur C-Quellen fuer den WASM-Build
  (`assets/wasm/` im Package), keine fertige `.wasm`. Bei einem Versionswechsel
  von `sqlite3` in `pubspec.yaml` muss `web/sqlite3.wasm` manuell gegen die
  passende `sqlite3.wasm` aus den GitHub-Releases von
  github.com/simolus3/sqlite3.dart ersetzt werden — Tag `sqlite3-<version>`,
  aktuell `sqlite3-3.7.0`. Ein Versatz zwischen Package und `.wasm` faellt
  **nicht** beim Kompilieren auf, sondern erst zur Laufzeit im Browser.
- Die nativen SQLite-Bibliotheken fuer Desktop und Mobile liefert seit
  `sqlite3` 3.x dessen eigener Build-Hook, der SQLite direkt mit der App
  buendelt (unter Windows erscheint es als `sqlite3.dll` im Release-Ordner).
  Das frueher noetige `sqlite3_flutter_libs` ist entfallen: es ist mit
  `0.6.0+eol` end-of-life und enthaelt keinen Code mehr. Beide Pakete
  duerfen nur gemeinsam bewegt werden — ein isolierter Bump von
  `sqlite3_flutter_libs` liesse Desktop und Mobile ohne native Bibliothek
  zurueck. Aus demselben Grund gibt es keinen `open.overrideFor`-Aufruf
  mehr; das Laden uebernimmt vollstaendig der Hook.
- Zusaetzlich zum manuellen Weg (lokal bauen bzw. Web-Upload) kann die
  Index-DB per Server-Sync bezogen werden (`lib/domain/rules_index_remote_config.dart`,
  `lib/data/rules_search/rules_index_remote_client.dart`,
  `lib/data/rules_search/rules_index_sync_service.dart`; Desktop-Cache-Pfad
  `index_remote.sqlite` in `rules_index_search_io.dart`, UI in
  `_RulesIndexServerCard` (`settings_pages.dart`) und im
  Regel-Nachschlag-Dialog). Die Datei bleibt unverschluesselt; das Download-
  Feature ist stattdessen hinter dem bestehenden Katalog-Entschluesselungs-
  passwort gated (kein zweites Passwort). Details und der bewusste
  Schutz-Trade-off stehen in `docs/spielmodus_konzept.md` Abschnitt 6.

## Pflegehinweis

Schnell veraltende Details gehoeren nicht in diese Datei. Wenn sich Architektur, Workflows oder Fachlogik aendern, aktualisiere stattdessen die passende Datei in `README.md` oder unter `docs/`.
