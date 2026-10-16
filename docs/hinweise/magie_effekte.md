# Magie, Zaubereffekte und magische Kenntnisse

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- [Magische Kenntnisse](../magische_kenntnisse.md): Repräsentationen und
  Ritualkenntnisse in Editor und Entwicklungsplanung. `HeroSheet.ritualKnowledge`
  hält gemeinsame Werte je Tradition; `ritual_knowledge_rules.dart` löst
  Kategoriebezüge auf. `advancement_magic_knowledge_rules.dart` prüft Erwerb und
  Steigerung, `magic_setup_rules.dart` die kostenfreie Erfassung und bewusste
  Anbindung von Bestandsgruppen. Wiederverwendbare Dialoge liegen unter
  `lib/ui_shared/`, damit Verwaltung und Kartograph denselben Ablauf nutzen.
- [Zaubereffekte-Integrationsplan](../zaubereffekte_integrationsplan.md):
  MAG-EFF in der Roadmap; Screening aller 288 Zauber, Quellenbelege und
  vorgeschlagene Pakete für Effekte auf Charaktere. MAG-EFF-01 ist umgesetzt:
  `assets/catalogs/house_rules_v1/spell_effects.json` (Manifest-Schlüssel
  `spell_effects`, `SpellEffectProfile` in `lib/catalog/spell_effect_def.dart`,
  `RulesCatalog.spellEffects`) hält je Zauber Pruefstand (`bestand`/`belegt`/
  `manuell`), Quelle und Eingabenamen — **keine Formeln, keine Zahlen**; die
  folgen erst in MAG-EFF-03. `spell_effect_profile_rules.dart` validiert
  (Zauber-ID existiert, Beleg gesetzt, Bestandsprofile nennen ihre
  Legacy-`effect_spell_*`-ID) und `istAutomatisiert` bremst unbelegte Profile.
  MAG-EFF-02 (Kern): `SpellEffectInstance` (`lib/domain/spell_effect_instance.dart`)
  in `ActiveSpellEffectsState.instanzen` (nur bei Belegung im JSON) trägt
  mehrere Quellen je Zauber; die drei Legacy-IDs bleiben unverändert und
  erscheinen nur als abgeleitete Instanzen (`aktiveEffektInstanzen`). Eigenschaften
  rechnen **nur** über `effektiveTempAttributeMods`
  (`spell_effect_instance_rules.dart`), nie über `tempAttributeMods` allein;
  Beenden einer Quelle entfernt nur sie. Tischregel: bei mehreren Attributo
  zählt je Eigenschaft nur der **beste** Wert (nicht Summe). „(A)“ in
  `SpellDef.duration` = aufrechterhalten (`aufrechterhaltungsBefund`); der
  Gefecht-Wirkdialog belegt die Anzahl daraus nur vor. MAG-EFF-03
  (Teilstand 1): empfangene Kampf-Mali Blitz (AT/PA-Basis, Helden-INI) und
  Plumbumbarum (AT, INI-Basis) rechnet `spell_effect_combat_rules.dart` aus
  Instanzen (`zfpStern`, `zfw`); sie laufen als benannte Quellen in die
  Basiswert-Herleitung (`DerivedStats.zauberKampf`). Teilstand 2: Adlerauge (Sinnesschärfe),
  Blitz-Probenzuschlag und Psychostabilis (MR) rechnet dasselbe Modul;
  `spell_effect_probe_rules.dart` legt Probenbeiträge als Startwert des
  situativen Modifikators in Talent-/Zauberproben (`probeMitSpellEffekten`,
  zentral in `showLoggedProbeDialog`/`zeigeGefechtsprobe`). Unbelegtes
  (Blindkampf-/Konzentrationsstärke-Halbierung, Fernkampf-Blitz) wird nie
  geraten, sondern als Hinweis gemeldet; andere Profile rechnen noch keine
  Zahlen. MAG-EFF-04 (teilweise): einmalige, zielgebundene Wirkungen in
  `spell_effect_event_rules.dart` – Falkenauge erleichtert den Gefecht-Schuss
  auf `SpellEffectInstance.ziel` und wird nach dem bestätigten Wurf verbraucht
  (`fuehreGefechtsAuftragAus`), Ängste lindern geht über „In Mut-Probe
  einsetzen“ im Effektdialog. Dauern werden nur vorgeschlagen, wo das
  Regelwerk sie eindeutig nennt (Psychostabilis: „nach AsP“ aus den
  eingegebenen Zusatz-AsP in `amount`, 1 AsP = 1 SR; laufende Kosten gibt es
  nicht, „(A)“ kostet nur Konzentration); Abgelaufenes wird markiert, nie automatisch
  beendet. MAG-EFF-05 (Teilstand 1): Schutzvorräte wie das Gardianum liegen in
  `SpellEffectInstance.amount` (Kapazität) und `schutzRest`; auffangen darf
  nur, was der Nutzer als direkten magischen Angriff einordnet
  (`spell_effect_protection_rules.dart`, `fangeMagischenSchadenAuf` mit
  erwartetem Restvorrat gegen Doppelbuchung); der Durchschlag geht in den
  Schadensdialog, ein aufgezehrter Schild bleibt bis zum Beenden am Tisch.
  Teilstand 2: Zauberheilung (Balsam, Hexenspeichel) ist ein einmaliges
  Ereignis über „Heilzauber erhalten“; Regeln in `spell_effect_healing_rules.dart`,
  Schreibweg `HeilungErhalten` (ein Dokument mit `ZustandsBuchung` Art
  `heilung`, `aspDelta` und Protokoll, idempotent über die Vorgangs-ID). Nie
  geraten: ungerade AsP bei Wunden (Hexenspeichel) und Rettung von der
  Schwelle des Todes. Teilstand 3: Ruhe Körper ist ein eigener Schlafablauf
  (`spell_effect_rest_rules.dart`, `RuheKoerperErhalten`), der die normale
  Regeneration der Stunden ersetzt; Heilungs-Vor-/Nachteile und „evtl. 1 AsP“
  werden nicht gerechnet, der Zaubernde trägt die Kosten.
  Einfache Zauber (Runde 1): Karnifilo (AT-Basis +5/PA-Basis −5 fest, die
  Eigenschaften ±5 nur als Hinweis), Seidenzunge (Überreden-Startwert +ZfP*),
  Lach dich gesund (Heilung im Heilungsdialog).
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
