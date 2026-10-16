# To-do-Liste: Weiterentwicklung der Heldenverwaltung

Stand: 16.10.2026. Diese Liste führt **nur Status und offene Punkte**. Abgenommene
Aufgaben und der Verlauf der Teilstände stehen unverändert im
[Archiv](archiv/README.md); Verweise wie „ARCH-05 Teilstand (3)“ in Code und
Dokumentation meinen den dortigen Text.

Grundlage ist die Diskussion „Wenn du die App komplett neu bauen würdest, was
würdest du anpassen?“ (18.09.2026) mit sieben Vorschlägen (ARCH-01 bis ARCH-07)
und dem fachlichen Ausbau MAG-EFF und TRANK. Vor einer Umsetzung den jeweiligen
Ist-Zustand erneut prüfen und den konkreten Teilumfang festlegen.

## Fachlicher Ausbau: MAG-EFF – Zaubereffekte

- [ ] **MAG-EFF – Zauberwirkungen auf Charaktere im Kampf und Spielgeschehen integrieren.**
  Recherche und Arbeitspakete: [Umsetzungsplan](zaubereffekte_integrationsplan.md)
  (Screening aller 288 Katalogzauber, Quellenbelege, Pakete MAG-EFF-01 bis -06).
  Voller bisheriger Statustext: [Archiv](archiv/mag-eff-trank.md).
  **Stand 16.10.2026:** 17 Zauberprofile umgesetzt (`spell_effects.json`):
  Axxeleratus, Attributo, Armatrutz, Fulminictus (Bestand); Blitz, Plumbumbarum,
  Adlerauge, Falkenauge, Psychostabilis, Ängste lindern, Gardianum, Balsam,
  Hexenspeichel, Ruhe Körper, Karnifilo, Seidenzunge, Lach dich gesund.
  Quellenbezogene `SpellEffectInstance`, Probenbeiträge, Verbrauch, Schutzvorrat
  und Heilereignisse stehen.
  **Zurückgestellt (Entscheidung 16.10.2026): alle weiteren Zauber bleiben
  offen** und werden zu einem anderen Zeitpunkt aufgenommen. Nächste
  Kandidaten laut Plan: Duplicatus, Klarum Purum und Folgetick-Profile
  (MAG-EFF-05); Hexenkrallen, Elementarpfeile, Eiseskälte, Horriphobus, Band und
  Fessel (MAG-EFF-06). Offene Befunde der Bestandszauber: Armatrutz kennt die
  Grenze ZfW/2 nicht, Axxeleratus ohne Athletik-Verdopplung, Blitz ohne
  Fernkampf-Zuschlag, Karnifilo-Eigenschaften nur als Hinweis.

- [ ] **TRANK — Trankdefinitionen aus den Regelbüchern in einen Katalog übernehmen.**
  Ziel: die wichtigsten Tränke und Heilmittel mit Regelwerten und Belegen als
  Katalog (`alchimika.json`), damit Inventar, Anlegen und Anwenden daraus
  vorbelegen. Voller bisheriger Text: [Archiv](archiv/mag-eff-trank.md).
  **Stand 16.10.2026:** Teilstand 1 (sechs Mittel, Editoranbindung,
  `Vitalwirkung` als Vorbelegung) und Teilstand 2 (acht Elixiere der Tugenden
  über MAG-EFF-Instanzen, `ElixierEinnehmen`) sind umgesetzt.
  **Offen:** Mutelixier-Brechreiz ohne Basiliskum, Kleptomanie und Mibelsucht
  (Nachteile auf Zeit), Mehrfachanwendung desselben Elixiers, Zauber- und
  Wandlungselixiere, Verbandszeug und Heilkräuter (Heilkunde-Probe,
  Zoo-Botanica), Hausregel-Abweichungen als eigenes Paket. Nicht Teil: Brauen,
  Rezepturenerwerb, Labor. Belege je Eintrag mit Buch und Seite, nichts ohne
  Beleg.

## Arbeitsweise und gemeinsame Grenzen

- Verbindlich bleibt [AGENTS.md](../AGENTS.md). Die Aufgaben sollen schrittweise
  in der bestehenden App umgesetzt werden. Ein vollständiger Neubau ist durch
  diese Liste nicht beschlossen.
- Flutter und Riverpod sowie die Trennung zwischen `HeroSheet`, `HeroState`
  und reinen Regelberechnungen beibehalten. Berechnungen gehören weiterhin
  ausschließlich nach `lib/rules/derived/`.
- Die kanonischen Katalogquellen bleiben die Split-JSON-Dateien unter
  `assets/catalogs/house_rules_v1/`. Bestehende Regelmodule und Tests weiterverwenden.
- Vor Änderungen an gespeicherten Modellen Migration, JSON-Import/-Export und
  Sync-Kompatibilität festlegen. Unbekannte Bestandsdaten erhalten und unklare
  Zuordnungen sichtbar machen. Bestehende Krypto-Wire-Formate unverändert lassen.
- Offene Produktentscheidungen sind pro Aufgabe benannt. Bei ihrer Umsetzung
  anhand des dann gültigen Auftrags klären; sie gelten hier nicht als entschieden.
- Pro abgeschlossenem Teilumfang Tests, Dokumentation und Commit gemeinsam
  abschließen. Ergebnis mit Aufgaben-ID und Commit in dieser Liste nachführen;
  relevante Erkenntnisse nach Duplikatprüfung in Mempalace hinterlegen.

## Übersicht und Reihenfolge

Die IDs entsprechen den sieben Punkten der ursprünglichen Empfehlung.
„Grundlage“ bezeichnet technische Vorarbeiten, „Aufbau“ darauf aufsetzende
Verbesserungen und „Begleitend“ fortlaufende Absicherung.

- [x] **ARCH-01 — Oberfläche nach Spielsituationen organisieren** · Aufbau (abgenommen 15.10.2026)
- [ ] **ARCH-02 — Regelrelevante Eigenschaften strukturiert speichern** · Grundlage
- [x] **ARCH-03 — Gemeinsame Ausrüstungsdaten für Inventar und Kampf** · Grundlage (abgenommen 07.10.2026)
- [ ] **ARCH-04 — Versionierte Regelprofile und erklärbare Berechnungen** · Aufbau
- [x] **ARCH-05 — Schreibende Aktionen fachlich aufteilen** · Grundlage (abgenommen 07.10.2026)
- [x] **ARCH-06 — Zusammengehörige Änderungen gemeinsam speichern und synchronisieren** · Aufbau (technisch abgenommen 12.10.2026)
- [ ] **ARCH-07 — Nutzerabläufe und Datenmigrationen absichern** · Begleitend

Reihenfolge war: Fixtures (ARCH-07), dann ARCH-02/03, ARCH-05, ARCH-04, ARCH-06 und
zuletzt ARCH-01. Heute offen sind ARCH-02 (manuelle Prüfung), ARCH-04
(Regelprofil-Restpunkte) und ARCH-07 (begleitend). Der Oberflächen-Neubau läuft
nach den [Redesign-Plänen R1–R3](redesign_implementation.md).

## ARCH-01 — Oberfläche nach Spielsituationen organisieren

**Status: abgenommen** (funktional 11.10.2026, manuelle Bedienprüfung
15.10.2026). Verlauf, Paketstände R1–R3 und Prüfprotokoll:
[Archiv](archiv/arch-01.md), Nachweis in [redesign_acceptance.md](redesign_acceptance.md).

**Ergebnis:** Drei Arbeitsbereiche **Spielen**, **Held verwalten** und
**Entwicklung planen** im Neubau `lib/ui2/` (Bildsprache „Kartograph“) neben dem
Bestand `lib/ui/`. Die Weiche ist `AppRootSwitch`, die Übergangsbrücke
`KartoBestandsAdapter`. „Schaden erhalten“ ist ein geführter Ablauf mit
Rücknahme am Protokolleintrag.

**Offen bzw. abgespalten:**

- Persönliche Favoriten (eigener Auftrag; Persistenz und Sync zu entscheiden).
- Offline-/Sync-Statusanzeige (gehört zu ARCH-06).
- Ein persistenter Kampfrundenzähler bleibt bewusst aus, das Gefecht führt
  Runden flüchtig.
- Die Spielerrolle des Spielmodus-Konzepts bleibt; eine Spielleiterverwaltung
  ist kein impliziter Bestandteil.

## ARCH-02 — Regelrelevante Eigenschaften strukturiert speichern

**Status: alle Unterpunkte umgesetzt, Hauptpunkt offen bis zur manuellen
Bedienprüfung.** Vor- und Nachteile (28.09.2026) und Herkunftsmerkmale
(12./13.10.2026) sind strukturiert gespeichert; die Liste führt, die Textfelder
sind nur Projektion für ältere Apps. Verlauf, Entscheidungen, Commits und
Grenzen: [Archiv](archiv/arch-02.md), dazu
[Spezifikation](superpowers/specs/2026-10-10-arch02-herkunftsmerkmale-design.md)
und [Plan](superpowers/plans/2026-10-10-arch02-herkunftsmerkmale.md).

**Offen:** Manuelle Bedienprüfung auf einem echten Gerät, danach
ARCH-02-Gesamtstatus prüfen und abhaken. Nicht automatisiert geprüft sind
Gerätebedienung (360 px, Textfaktor 2) und Live-Sync mit Firebase.

*Automatisierte Abnahme wiederholt (16.10.2026).* `flutter analyze --no-pub`
ohne Befund; Gesamtsuite seriell (`--concurrency=1`, eigenes
`DSA_MCP_DATA_DIR`): 6177 bestanden, 3 übersprungen, 0 fehlgeschlagen. Damit
ist die in der Abnahme oben vermerkte unvollständige Wiederholung nachgeholt.

*Checkliste für die manuelle Bedienprüfung (offen, Gerät nötig).* Erst wenn
alle Punkte bestanden sind, ARCH-02 oben abhaken:

- [ ] Übersicht: je Gruppe Rasse/Kultur/Profession einen direkten Modifikator
  und ein freies Fragment anlegen, ändern, entfernen; Werte im Bogen stimmen.
- [ ] Merkmal: Herkunft über den gemeinsamen Dialog ändern (Übersicht und
  UI2-Merkmalsblatt); Wirkung bleibt unverändert, nur das Metadatum wechselt.
- [ ] Schmal (360 px) und Textfaktor 2: keine Überläufe in Herkunftskarten,
  Dialogen und Merkmalsblatt.
- [ ] Offene Planung: Bearbeiten fragt nach, „Abbrechen“ erhält die Sitzung,
  UI2-Merkmalsblatt ist schreibgeschützt.
- [ ] Abweichung durch ältere App (Textfeld geändert): Bearbeiten gesperrt bis
  „Text übernehmen“ oder „Liste behalten“; nichts wird still aufgelöst.
- [ ] Export → Import desselben Helden: Herkunft, Stufen, Varianten und
  Freitexte identisch.
- [ ] Live-Sync mit zwei Geräten (Firebase): gleiche Änderung in einer Gruppe
  auf beiden Geräten ergibt einen sichtbaren Konflikt, verschiedene Gruppen
  führen still zusammen.

## ARCH-03 — Gemeinsame Ausrüstungsdaten für Inventar und Kampf

**Status: abgenommen** (07.10.2026). Verlauf, Entscheidungen vom 04.10.2026,
Teilstände und Restrisiken: [Archiv](archiv/arch-03.md).

**Ergebnis:** Jeder konkrete Gegenstand trägt eine stabile Instanz-ID; Slots
verweisen über `inventarInstanzId` zurück, `slotRef` ergänzt den Namensverweis
`sourceRef`. Menge und Stapel, Ablegen/Zurückholen, Verkaufen und
Zusammenführen laufen über das gemeinsame Modell; der Namensabgleich ist nur
noch Migration. Alle verschachtelten Modelle von Held und Zustand sowie
unbekannte Aufzählungswerte bleiben erhalten (Vollständigkeitswächter in
`test/domain/unbekannte_verschachtelte_felder_test.dart`).

**Offen:** nichts im Hauptpunkt. Bekannte Restrisiken (Regeln rechnen bei
unbekannten Aufzählungswerten mit dem Ersatz; verknüpfte Einträge übernehmen
`itemType`/`source` aus dem Slot) stehen im Archiv.

## ARCH-04 — Versionierte Regelprofile und erklärbare Berechnungen

**Ist-Zustand:** Aktive Hausregelpakete werden aus gemeinsamen Einstellungen
aufgelöst. `ModifierSourceBreakdown` erklärt bereits einen Teil der
Modifikatorherkunft; eine einheitliche Herleitung aller Regelwerte fehlt.

**Ziel:** Helden erhalten ein explizites Regelprofil mit festgelegten
Paketversionen. Gruppen können eine gemeinsame Vorgabe liefern. Ein Regelupdate
zeigt vor Übernahme seine Auswirkungen. Berechnungen liefern neben Ergebnissen
ihre Basis, Modifikatoren, Bedingungen und Quellen.

**Einstieg:** `lib/state/house_rules_providers.dart`,
`lib/state/catalog_providers.dart`, `lib/catalog/house_rule_pack.dart`,
`lib/catalog/house_rule_catalog_resolver.dart`,
`lib/catalog/house_rule_provenance.dart`, `lib/domain/hero_sheet.dart`,
`lib/rules/derived/modifier_source_breakdown.dart` und
[Katalog-Workflow](catalog_import_workflow.md).

- [ ] Profilzuordnung, Versionierung und Auflösung definieren; Bestandshelden
  mit ihrem bisher wirksamen Regelsatz übernehmen. *(Modell und Auflösung
  Teilstand 12, Erstübernahme per Knopf Teilstand 14; Gruppenvorgabe offen.)*
- [x] Vorschau für Profil-/Paketupdates implementieren: geänderte Werte und
  Erwerbsvoraussetzungen anzeigen, erst durch Übernahme verbindlich machen.
  *(Teilstand 13 ohne, Teilstand 14 mit Oberfläche.)*
- [x] Ein gemeinsames Ergebnisformat für Regelherleitungen einführen und
  schrittweise auf Basiswerte, Kampf, Talente, Magie und Steigerungen anwenden.
  Die UI zeigt die Herleitung aus dem Regelmodul, ohne sie selbst nachzurechnen.
  *(Format und Basiswerte seit Teilstand 1, Eigenschaften seit Teilstand 2,
  Kampfvorschau seit Teilstand 3, Schild- und Parierwaffen-PA seit
  Teilstand 4, Gefechtswerte Teilstand 6, Begleiter Teilstand 7, Talente
  Teilstand 8, Zauber Teilstand 9, Steigerungskosten Teilstand 10, Lernregeln Teilstand 11; Regelprofil-Grundlage Teilstand 12, Updatevorschau Teilstand 13, Oberfläche je Held Teilstand 14; offen bleibt
  der Erwerbsdialog, siehe Teilstand 10/11.)*

**Abnahme:** Zwei Helden mit verschiedenen Profilen können parallel geöffnet
werden, ohne einander zu beeinflussen. Gleiche Eingaben und Regelversionen
liefern reproduzierbare Ergebnisse. Ein Update verändert den Helden erst nach
Übernahme; angezeigte Herleitung und tatsächlich verwendeter Wert stimmen überein.

**Prüfung:** `test/state/house_rules_providers_test.dart`,
`test/catalog/house_rule_catalog_resolver_test.dart` sowie Regel- und UI-Tests
für Profilwechsel, Updatevorschau und Herleitungen ergänzen.

**Abhängigkeiten / offene Entscheidungen:** ARCH-02/03 erleichtern eindeutige
Wirkungsquellen. Gruppenvererbung gegenüber einer festen Profilkopie, Aufbewahrung
alter Paketstände und Verhalten bei fehlenden Paketen klären. Import/Export und
Sync müssen die reproduzierbare Profilzuordnung mittragen.

**Status: Herleitungen und Regelprofil umgesetzt, Hauptpunkt offen.** Die
Teilstände 1–14 (13./14.10.2026) mit Entscheidungen, Prüfungen und Grenzen stehen
im [Archiv](archiv/arch-04.md):

- Herleitungsformat `Herleitung` und Basiswerte (1), Eigenschaften (2),
  Kampfvorschau (3), Schild und Parierwaffe (4), Gefechtswerte (5), Zielwert und
  Erschwernis im Gefechtsdialog (6), Begleiter (7), Talente (8), Zauber (9),
  Steigerungskosten (10, Nachtrag 16.10.2026: Erwerbs- und Abbaukosten in
  `erwerb_herleitung_rules.dart`), Lernregeln (11).
- Regelprofil am Helden `HeroSheet.regelProfil` mit Auflösung (12),
  Updatevorschau (13) und Oberfläche je Held in der Übersicht (14).

**Entscheidungen 13.10.2026 (Nutzer).**

- **Reihenfolge:** zuerst das Herleitungsformat (ohne Daten- und
  Syncänderung), danach Regelprofil und Updatevorschau.
- **Profilquelle: live von der Gruppe.** Ein Gruppenheld folgt der aktuellen
  Vorgabe seiner Gruppe; eine geänderte Vorgabe wird ihm als Vorschau
  angeboten. Das braucht Firestore und ist deshalb unter Windows nicht
  verfügbar; dort und ohne Gruppe gilt die eigene Auswahl. Offen für den
  Profilteilumfang: Verhalten bei mehreren Gruppen eines Helden, beim
  Verlassen der Gruppe und ohne Verbindung.
- **Paketstand am Helden.** Der Held trägt die Patches seiner Pakete als
  Kopie und rechnet nach einem App-Update mit dem alten Stand weiter, bis die
  Vorschau übernommen wird. Ein fehlendes Paket rechnet aus der Kopie weiter
  und zeigt einen Hinweis. Der Basiskatalog selbst wird nicht eingefroren.

**Offene Punkte (Stand 16.10.2026).**

*Regelprofil:*

- [x] Profil auf „folgt global“ zurückführen: Knopf „Wieder den globalen
  Hausregeln folgen“ in der Karte „Regelprofil“ (`setzeRegelProfilZurueck`,
  16.10.2026); ein inzwischen geändertes Profil wird nie überschrieben.
- [ ] Zusätzliche Pakete in der Vorschau wählen (`zusaetzlichePaketIds`).
- [x] Import/Export: das Profil reist mit dem Helden-JSON (Manifestkopien und
  Prüfsummen unverändert); ein Import rechnet nicht neu, ein abweichender
  Paketstand der Ziel-App erscheint als Updatevorschau
  (`test/data/hero_actions_import_export_test.dart`, 16.10.2026).
- [ ] Einstieg in der UI2-Navigation (heute nur die Übersichtskarte
  „Regelprofil“).
- [x] Epische Nachteile folgen dem Profil des Helden
  (`heroHouseRuleActiveProvider`, 16.10.2026).
- [ ] Gruppenvorgabe („live von der Gruppe“): Verhalten bei mehreren Gruppen,
  beim Verlassen und ohne Verbindung klären; die Firestore-Regeln verbieten
  heute Gruppen-Updates, unter Windows ist Firestore nicht verfügbar.

*Herleitungen:*

- [ ] Lernspalte als Herleitung für Talente (heute Text „Lernkomplexität X“,
  `effectiveTalentLernkomplexitaet`); die Sondererfahrungs-Ausnahme greift auf
  die schon verbilligten Kosten.
- [ ] Probenziele des Würfelknopfs im Talente-Tab nutzen `wendeWundVerlusteAn`
  direkt; der Probendialog zeigt TaW\* nur als Zahl.
- [ ] Eigenschaftsprobe als Ausweichen (Zuschlag ≥ 7) bleibt eigene
  Eigenschaftsprobe.
- [ ] Bewusst offen aus den Lernregeln: zweite Repräsentation desselben Zaubers,
  Hexalogien für eigene Katalogzauber, Gedächtnis-Vorteile bei SF/Ritualen,
  Selbststudium und Lehrmeister-Gebühren, Gegenelement in der
  Zauberkatalog-Vorschau und im Repräsentationsdialog.
- [ ] Zauberspezialisierung, Merkmalskenntnis- und Repräsentationsboni sowie
  AsP-Kosten stehen nicht in der ZfW\*-Herleitung.

**Abnahme** erst, wenn Profilzuordnung (inkl. Gruppenvorgabe) abgehakt ist.

## ARCH-05 — Schreibende Aktionen fachlich aufteilen

**Status: abgenommen** (07.10.2026). Elf Teilstände (29.09.–07.10.2026),
Befunde, Prüfungen und die Abnahme gegen die Kriterien: [Archiv](archiv/arch-05.md);
Bestandsaufnahme der Schreibwege in [schreibpfade_inventar.md](schreibpfade_inventar.md).

**Ergebnis:** Fachlich benannte Abläufe in `lib/ablaeufe/` (Rast, Schaden
erhalten, Steigerungsrunde, Held importieren), ohne Riverpod und Flutter, geprüft durch
`test/ablaeufe/abhaengigkeiten_test.dart`. Bogen und Zustand schreiben frisch
und eingereiht (`aendereGespeichertenHelden`, `aendereGespeichertenZustand`,
`aendereHeldMitMeldung`, `aendereZustandMitMeldung`); Editorentwürfe
über `speichereEditorEntwurf`. Zonenwunden nach WdS stehen in
`wund_zonen_rules.dart`.

**Offen:** nichts im Hauptpunkt. Avatar- und Gruppenoperationen bleiben schmale
Methoden in `HeroActions`; „Ausrüstung wechseln“ ist bewusst keine eigene
Ablaufklasse. Neue Schreibwege folgen dem Muster aus CLAUDE.md.

## ARCH-06 — Zusammengehörige Änderungen gemeinsam speichern und synchronisieren

**Status: technisch abgenommen** (12.10.2026). Teilstände 1–3, Entscheidungen
vom 07.10.2026 und Abnahmeprüfung: [Archiv](archiv/arch-06.md) und
[arch06_abnahme.md](arch06_abnahme.md).

**Ergebnis:** Speichervertrag „ein Dokument je Ablauf“ mit `Vorgangsjournal`
(Import), Buchungsprotokoll und Schaden-Rücknahme, Konflikte nur für echte
Widersprüche (`fuehreSyncZusammen`, Sync-Basis), dauerhafter Wiederanlauf von
Konfliktentscheidungen (`SyncKonfliktVorgang`, `KonfliktWiederanlauf`).

**Offen:**

- [ ] Geräte- und Live-Firebase-Prüfung (nur manuell möglich).
- Bekannte Grenzen: Bogen und Zustand liegen online in zwei getrennten
  Schreibzugriffen; Online-Tombstone mit „Nur Online“, Löschkonflikte,
  eigenständige Zustandskonflikte, `deleteHero` während eines offenen
  Vorgangs und Avatare sind nicht abgedeckt.

## ARCH-07 — Nutzerabläufe und Datenmigrationen absichern

**Ist-Zustand:** Regel-, Domain-, Daten-, Provider- und Widgettests sind bereits
getrennt vorhanden. Die CI prüft unter anderem Analyse, Tests und einen
Web-Release-Build. Für den Umbau braucht es zusätzlich gezielte Nachweise über
vollständige Abläufe, alte Datenformate und unterbrochene Synchronisierung.

**Ziel:** Repräsentative Bestandshelden und kritische Nutzerabläufe sichern die
schrittweise Weiterentwicklung ab. Die Trennung der Testverantwortlichkeiten aus
der [Teststrategie](test_strategy.md) bleibt erhalten.

**Einstieg:** `test/domain/hero_sheet_model_test.dart`,
`test/data/hero_actions_import_export_test.dart`,
`test/data/syncing_hero_repository_test.dart`, `test/state/advancement_session_test.dart`,
`test/ui/smoke/widget_test.dart` und `.github/workflows/flutter-tests.yml`.

- [x] Kleine, anonymisierte bzw. synthetische Bestandsfixtures mit erwarteten
  Ergebnissen anlegen: normale, magische/karmale und epische Helden, eigene
  Textmerkmale, gleichnamige Ausrüstung und ältere Schema-Versionen.
- [x] Den Ablauf „importieren → steigern → ausrüsten → Spielaktion → schließen
  → wieder öffnen → exportieren“ auf Erhalt der gespeicherten Daten absichern.
  Tests für jede neue Migration direkt im jeweiligen Modellumbau ergänzen.
- [x] Unterbrochenen Sync, Wiederholung und Konflikte zweier Geräte reproduzierbar
  testen; automatisierte Prüfungen und nötige manuelle Plattformprüfungen in der
  Teststrategie sowie der CI nachvollziehbar verorten.

**Abnahme:** Jede eingeführte Migration hat einen Bestandsfall und einen Test
für erneutes Laden ohne weitere Veränderung. Kritische Abläufe prüfen reale
Speicher-/Ladegrenzen. Erwartungen für Regelwerte stehen in Regeltests, während
UI-/Ablauftests Navigation, Persistenz und Fehlerbehandlung prüfen. Abgedeckte
Plattformen und verbleibende manuelle Prüfungen sind ausdrücklich dokumentiert.

**Abhängigkeiten / offene Entscheidungen:** Vor ARCH-02/03 mit Fixtures beginnen
und alle Aufgaben begleiten. Umfang echter Integrationstests, Geräteauswahl und
CI-Ausführung anhand der betroffenen Plattformpfade konkretisieren.

**Status: Grundausstattung fertig, Hauptpunkt bleibt als begleitende Aufgabe
offen** (jede neue Migration braucht eine Fixture und einen Reload-Test).
Neun Bestandshelden unter `test/fixtures/heroes/`, Ablauf- und
Zwei-Geräte-Sync-Tests; die Befunde B1–B13 sind alle behoben. Umsetzungsstand,
Befundtabelle und Aktualisierungen: [Archiv](archiv/arch-07.md); Regeln in der
[Teststrategie](test_strategy.md#bestandsfixtures-arch-07).

**Offen:** die manuellen Plattformprüfungen aus der Teststrategie (Web/IndexedDB,
native Speicherpfade, `file_picker`, Konto-Sync gegen echtes Firebase).

**Abdeckungsaudit neuer Modelle (16.10.2026).** Geprüft wurde, ob jedes seit der
Grundausstattung additiv eingeführte Modell die ARCH-07-Anforderungen erfüllt
(Schlüsselliste, Erhalt unbekannter Felder, unverändertes JSON nach erneutem
Laden). `test/domain/unbekannte_verschachtelte_felder_test.dart` führt dafür
67 Modelle in einer Tabelle (`_pruefeModelle`), darunter `HeroRegelProfil`,
`HeroRegelProfilPaket`, `HeroHerkunftsModifikator(en)`, `HeroMerkmal`,
`SpellEffectInstance`, `AlchimikumBezug`, `Vitalwirkung`, `ReittierAusbildung`,
`VertrautenBindung`, `BegleiterZustand` und `ZustandsBuchung`; `ArtefaktDaten`
deckt `unbekannte_ausruestungsfelder_test.dart` ab. Der Vollständigkeitswächter
im selben Test fängt jedes weitere Modell ab, die Hash-Pins aus
`bestandshelden_kompatibilitaet_test.dart` halten die Bestandsfixtures
unverändert. Migrationen mit Bestandsfall und Reload-Test: Herkunft
(`herkunft_migration_test.dart`, `herkunft_sync_test.dart`), Merkmale
(`merkmal_migration_test.dart`), Inventarverweise
(`bestandshelden_ausruestung_test.dart`). **Keine Lücke gefunden**, es wurden
keine Tests ergänzt. Gesamtsuite: 6177 bestanden, 3 übersprungen, 0 fehlgeschlagen.
Der Hauptpunkt bleibt bewusst offen (begleitend); verbleibend sind die
manuellen Plattformprüfungen aus der Teststrategie (Web/IndexedDB, native
Pfade, `file_picker`, Live-Firebase).

## Abschluss und Übergabe je Aufgabe

Eine Aufgabe erst in der Übersicht abhaken, wenn ihre Abnahmekriterien erfüllt
und die zugehörigen Prüfungen erfolgreich sind. Bei Teilergebnissen bleibt der
Hauptpunkt offen. Unter dem jeweiligen Abschnitt ergänzen:

- umgesetzter Teilumfang und Datum;
- zugehörige Commits und gegebenenfalls weiterführender Detailplan;
- tatsächlich ausgeführte Prüfungen und Ergebnis;
- verbleibende Entscheidungen, Risiken und nächster konkreter Schritt.

Als Mindestprüfung gelten `flutter analyze` und die relevanten `flutter test`-
Läufe gemäß AGENTS.md. README, CLAUDE.md und betroffene Dokumentation im selben
Commit aktualisieren. Diese Liste hält Aufgabenstatus und offene Arbeit fest;
die technische Gesamtdokumentation beschreibt weiterhin das tatsächlich
implementierte Verhalten.
