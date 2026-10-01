import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'combat_special_ability_state.dart';
import 'gefecht_rules.dart';
import 'maneuver_rules.dart';
import 'ausweichen_rules.dart';

/// Ersetzt Vorschau-INI durch Sitzungswerte und übernimmt aktuelle Heldendaten.
Gefechtswerte gefechtswerteFuer(HeroComputedSnapshot snapshot) {
  final c = snapshot.combatPreviewStats;
  final config = snapshot.hero.combatConfig;
  final waffe = config.selectedWeaponOrNull;
  bool sf(String id) => isCombatSpecialAbilityActive(config, id);
  return Gefechtswerte(
    iniBasis: c.kampfInitiative - c.iniWurfEffective,
    at: c.at,
    pa: c.pa,
    ausweichen: computeAusweichen(
      paBase: c.paBase,
      sfAusweichenBonus: c.sfAusweichenBonus,
      akrobatikBonus: computeAkrobatikBonus(snapshot.hero.talents),
      axxAusweichenBonus: c.axxAusweichenBonus,
      iniAusweichenBonus: 0,
      ausweichenMod: c.ausweichenMod,
      beKampf: 0,
    ),
    be: c.beKampf,
    schildPa: c.offhandIsShield ? c.shieldPa : null,
    schildkampf2: sf('ksf_schildkampf_ii'),
    turmschild: c.offhandName.toLowerCase().contains('turmschild'),
    ausweichen1: sf('ksf_ausweichen_i'),
    aufmerksamkeit: sf('ksf_aufmerksamkeit'),
    waffeVorhanden: waffe != null && waffe.name.trim().isNotEmpty,
    fernkampf: c.isRangedWeapon,
    waffenDk: waffe?.distanceClass ?? '',
  );
}

/// Bewertet bekannte Manöversperren; nicht unterstützte Folgen bleiben manuell.
Gefechtspruefung pruefeGefechtsmanoever(
  Gefechtszustand s,
  HeroComputedSnapshot snapshot,
  RulesCatalog katalog,
  ManeuverDef m, {
  required int zuschlag,
  int? zielwert,
  bool eigenerAuftrag = false,
}) {
  final config = snapshot.hero.combatConfig;
  final waffe = config.selectedWeapon;
  final sperren = <String>[];
  final gelernt = learnedManeuverIds(config, katalog);
  if (m.mussSeparatErlerntWerden && !gelernt.contains(m.id)) {
    sperren.add('Manöver nicht erlernt.');
  }
  if (m.nurFuerTalente.isNotEmpty &&
      !m.nurFuerTalente.contains(waffe.talentId)) {
    final talent = katalog.talents
        .where((t) => t.id == waffe.talentId)
        .firstOrNull;
    if (talent == null || !m.nurFuerTalente.contains(talent.name)) {
      sperren.add('Manöver für dieses Waffentalent nicht zugelassen.');
    }
  }
  if (m.nurEpisch && !snapshot.hero.isEpisch) {
    sperren.add('Nur für epische Helden.');
  }
  final parade = m.typ.toLowerCase().contains('parade');
  return pruefeGefechtsaktion(
    s,
    gefechtswerteFuer(snapshot),
    parade ? Gefechtsaktion.parade : Gefechtsaktion.angriff,
    zuschlag: zuschlag,
    manuellerZielwert: zielwert,
    sperrGruende: sperren,
    eigenerAuftrag: eigenerAuftrag,
    pruefGruende: [
      'Manövervoraussetzungen, Aktionskosten und Folgen manuell prüfen.',
      if (m.voraussetzungen.isNotEmpty) m.voraussetzungen,
      if (m.name.toLowerCase().contains('hammerschlag')) 'Alle nicht freien Aktionen müssen ungenutzt sein; Talent, Gegnergröße und Schild prüfen.',
    ],
  );
}
