# Gefecht, Reittiere und Vertraute

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- Das [Codex-Mockup](../mockups/README.md) zeigt den geplanten Workspace mit
  drei Arbeitsbereichen als eigenständigen HTML/CSS/JavaScript-Prototyp.
  Es nutzt ausschließlich flüchtige Beispieldaten und keine produktive Regellogik.
  Der [Gefecht-Plan](../mockups/gefecht-plan.md) ergänzt das klickbare
  Gefechts-Mockup. `gefecht-aktionen.js` bündelt dessen Freigaben und kompakte
  Rundensteuerung, `gefecht-ausruestung.js` enthält das separate Ausrüstungspopup.
  Die freigegebene Flutter-Umsetzung wird in
  [docs/gefecht_implementation.md](../gefecht_implementation.md) nachgeführt.
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
  `gefecht_kampfwerte.dart` zeigt INI/AT/PA/Ausweichen/TP/RS/BE als fixierte
  AppBar-Leiste mit Rechenweg (`gefecht_kampfwerte_rules.dart`, inkl. Herleitung der Gefechts-INI).
  Normale Nahkampf-PA benötigt keine allgemeine Paradebestätigung; bekannte
  Verbote und konkrete fehlende Angriffsdaten bleiben in den Kontextregeln wirksam.
  Der Folgeplan steht in [docs/gefecht_next_plan.md](../gefecht_next_plan.md).
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
  alles bleibt flüchtig. Stand und Grenzen: [docs/gefecht_abschluss_entwurf.md](../gefecht_abschluss_entwurf.md).
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
  ([docs/reittier_plan.md](../reittier_plan.md), Pakete P1–P3).
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
  [docs/vertraute_plan.md](../vertraute_plan.md) (V1 und V2 fertig, V3 offen).
  V2: `HeroState.begleiterZustaende` hält laufende LeP/AsP/AuP **aller**
  Begleiter (`null` = voll, Eintrag nur bei Belegung; Rechnung vom gespeicherten
  Wert in `begleiter_zustand_rules.dart`, Schreibweg `aendereBegleiterPool`;
  im Sync Zähler). Vereinigung (`VertrautenVereinigung`) und Rast-Regeneration
  schreiben ein Dokument, ein versäumtes Treffen zwei getrennte Buchungen.
  Die UI2-Spielansicht führt „Begleiter“ nach „Zustand“, noch vor dem
  Würfelprotokoll. Fehlt der Hexe die SF Vertrautenbindung, ist das nur ein
  Hinweis beim Binden (Meisterentscheid).
