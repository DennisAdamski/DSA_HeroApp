# Regellogik, Herleitungen, Wunden und epische Boni

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- Regellogik gehoert nach `lib/rules/derived/`.
- Erklärbare Werte (ARCH-04) liefern Regelmodule als `Herleitung`
  (`lib/rules/derived/herleitung.dart`): additive Schritte mit Art, Formel,
  Quelle und Bedingung, der Wert ist die Summe. Begrenzungen und
  Vervielfachungen sind eigene Ausgleichsschritte. Basiswerte kommen aus
  `computeBasiswertHerleitungen` und liegen in `DerivedStats.herleitungen`,
  Eigenschaften aus `computeEigenschaftHerleitungen`
  (`HeroComputedSnapshot.eigenschaftHerleitungen`), die Kampfvorschau aus
  `kampf_herleitung_rules.dart`/`kampf_ini_herleitung_rules.dart`
  (`CombatPreviewStats.herleitungen`, Nebenhandwaffe in
  `OffhandCombatPreview.herleitungen`; AT, PA, TP, INI, Ausweichen, RS, BE und
  eBE werden dort abgelesen). Angezeigt über `HerleitungsAbschnitt`/
  `HerleitungsSchritte` (`ui/screens/hero_overview/herleitung_abschnitt.dart`)
  und `KampfHerleitungDetails` (`ui/screens/hero_combat/`). Alle Herleitungen
  eines Helden sind über ein (i) durchsuchbar: `sammleHerleitungen`/
  `filtereHerleitungen` (`herleitung_uebersicht_rules.dart`), Dialog
  `HerleitungsSucheDialog` (`ui/screens/workspace/herleitung_suche_dialog.dart`)
  neben „Regeln nachschlagen“ im Heldenbogen und in der UI2-Verwaltung, in UI2
  zusätzlich in der Navigation über `KartoBestandsAdapter.berechnungsschritte`.
  Eine neue Herleitung gehört dort in `sammleHerleitungen`. Talente
  (`talent_herleitung_rules.dart`): TaW\* und eBE sind Herleitungen, die
  Ausrüstung steht je Gegenstand (`talentQuellen`), der Talent-BE-Override
  als Schritt „BE-Anpassung (situativ)“; `talentProbenwertFuer` liest sie ab. Wer ein
  Talent proben darf, entscheidet allein `talentEintragFuerProbe`
  (`talent_nutzung_rules.dart`, Tabelle `talent_nutzung_katalog.dart`): Basis-Talente
  immer, Spezial-Talente nur aktiviert (TaW ≥ 0). Ausweichen auf verwandte
  Talente: `talentErsatzproben` (Meisterentscheid, Richtzuschläge aus WdS). Zauber: `zauber_herleitung_rules.dart` (ZfW*, gemeinsame
  Zauberprobe für Suche, Gefecht und Magie-Tab). Steigerungskosten:
  `steigerung_herleitung_rules.dart` (Grundkosten, SE, Aufschlag, Lehrmeister;
  der Steigerungsdialog liest nur ab). Lernspalte von
  Zaubern: `zauber_lernspalte_rules.dart` (Hauszauber, Merkmalskenntnis,
  Begabung, Unfähigkeit, fremde Repräsentation je Paar, Gegenelement,
  Hexalogie nach `hexalogie_katalog.dart`); Gedächtnis-Vorteile als
  Kostenfaktor in `lernkosten_faktor_rules.dart`; beides reist als `Lernregeln`
  an der `AdvancementOption`. Ein Lehrmeister gilt nur für Talente und Zauber,
  bis Stufe + 3. Die Oberfläche
  zeigt sie an und rechnet **nie** selbst Modifikatoren
  zusammen. Stand und nächste Bereiche: Roadmap ARCH-04.
- **Regelprofil am Helden** (ARCH-04, Teilstand 12): `HeroSheet.regelProfil`
  (nur bei Belegung im JSON) listet die aktiven Hausregelpakete mit Manifestkopie
  und Prüfsumme; `null` = der Held folgt den globalen Einstellungen. Hero-gebundene
  Leser nehmen `heroRulesCatalogProvider(heroId)` bzw.
  `heroEpicAdvantagesActiveProvider(heroId)`, nie `rulesCatalogProvider` direkt
  (der bleibt Gate, Einstellungen und Katalogverwaltung). Auflösung rein in
  `loeseRegelProfilAuf`. Ein Profil wird **nie** automatisch geschrieben (Hashes);
  nur bewusste Nutzeraktion. **Updatevorschau (Teilstand 13, ohne Oberfläche):**
  `erstelleRegelProfilVergleich`/`vergleicheAufloesungen`
  (`lib/catalog/regelprofil_vergleich.dart`) vergleichen zwei Auflösungen
  (Einträge, Sperrbedingungen über `ruleMeta.sourceKey`, Pakethinweise);
  `schlageProfilVor` hebt die Pakete des Profils auf den aktuellen Stand, neue
  nie von selbst. `erstelleRegelProfilVorschau`
  (`rules/derived/regelprofil_vorschau_rules.dart`) ergänzt Auswirkung auf
  erworbene Fähigkeiten und Herleitung vorher/nachher; Provider
  `regelProfilVorschauProvider(heroId)`. Der Basiskatalog bleibt nicht
  eingefroren. Geschrieben wird nur über den Ablauf `RegelProfilUebernehmen`
  (`uebernehmeRegelProfil` weist ein inzwischen geändertes Profil ab).
  Auflösungen bekommen `bekanntePaketIds`, sonst blieben Einträge eines nicht
  gewählten Pakets sichtbar. Oberfläche (Teilstand 14): Karte „Regelprofil“ in der Übersicht
  (`hero_regelprofil_section.dart`: Erstübernahme `null → Profil` über
  `globalesRegelProfilProvider`, Vorschaudialog, Übernahme über
  `aendereHeldMitMeldung(validationCatalog:)`). Zurück auf „folgt global“ nur
  über `setzeRegelProfilZurueck` (Knopf in derselben Karte). Das Profil reist
  im Export/Import mit (Kopien und Prüfsummen unverändert); epische Nachteile
  lesen `heroHouseRuleActiveProvider`, nicht den globalen Schalter. Offen:
  gewählte Zusatzpakete, Gruppenvorgabe, Einstieg in der UI2-Navigation.
- Aventurische Waehrungsumrechnung fuer Dukaten/Silber/Kreuzer liegt in
  `lib/rules/derived/currency_rules.dart`.
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
