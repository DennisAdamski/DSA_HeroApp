import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'combat_special_ability_state.dart';
import 'gefecht_rules.dart';
import 'maneuver_rules.dart';
import 'ausweichen_rules.dart';
import 'hero_requirement_context.dart';
import 'requirement_evaluation_rules.dart';
import 'two_weapon_combat_rules.dart';

/// Ersetzt Vorschau-INI durch Sitzungswerte und übernimmt aktuelle Heldendaten.
Gefechtswerte gefechtswerteFuer(HeroComputedSnapshot snapshot) {
  final c = snapshot.combatPreviewStats;
  final config = snapshot.hero.combatConfig;
  final waffe = config.selectedWeaponOrNull;
  bool sf(String id) => isCombatSpecialAbilityActive(config, id);
  return Gefechtswerte(
    iniBasis:
        c.kampfInitiative -
        c.iniWurfEffective -
        snapshot.wundEffekte.aktuellerIniMalus,
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
    kampfgespuer: sf('ksf_kampfgespuer'),
    stabUmwandlung:
        waffe?.talentId == 'tal_staebe' &&
        (snapshot.hero.talents['tal_staebe']?.talentValue ?? 0) >= 10,
    zusatzaktionen:
        c.twoWeaponCombat?.options.any(
              (o) =>
                  o.isAvailable &&
                  (o.type == TwoWeaponActionType.extraOffhandAttack ||
                      o.type == TwoWeaponActionType.extraOffhandParry),
            ) ==
            true
        ? 1
        : 0,
    zusatzAttacke:
        c.twoWeaponCombat?.options.any(
          (o) =>
              o.isAvailable && o.type == TwoWeaponActionType.extraOffhandAttack,
        ) ==
        true,
    zusatzParade:
        c.twoWeaponCombat?.options.any(
          (o) =>
              o.isAvailable && o.type == TwoWeaponActionType.extraOffhandParry,
        ) ==
        true,
    waffeVorhanden: waffe != null && waffe.name.trim().isNotEmpty,
    fernkampf: c.isRangedWeapon,
    waffenDk: waffe?.distanceClass ?? '',
    waffe: waffe,
    scharfschuetze: sf('ksf_scharfschuetze'),
    meisterschuetze: sf('ksf_meisterschuetze'),
    waffenmeister:
        snapshot.combatPreviewStats.waffenmeisterAdditionalManeuvers.isNotEmpty,
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
  int distanzSchritte = 0,
}) {
  final config = snapshot.hero.combatConfig;
  final waffe = config.selectedWeapon;
  final sperren = <String>[];
  final gelernt = learnedManeuverIds(config, katalog);
  final talentGelernt = gelernt.contains('${m.id}::${waffe.talentId}');
  if (m.mussSeparatErlerntWerden && !gelernt.contains(m.id) && !talentGelernt) {
    sperren.add('Manöver nicht erlernt.');
  }
  final voraussetzungen = evaluateRequirements(
    m.voraussetzungenStruktur,
    buildHeroRequirementContext(
      snapshot.hero,
      catalog: katalog,
      mods: snapshot.derivedStats.modifiers,
    ),
  );
  for (final v in voraussetzungen) {
    if (v.status == RequirementStatus.nichtErfuellt) {
      sperren.add('${v.sollText}: ${v.istText}');
    }
  }
  final talentDef = katalog.talents
      .where((t) => t.id == waffe.talentId)
      .firstOrNull;
  final katalogWaffe = katalog.weapons
      .where(
        (w) => w.name == waffe.weaponType && w.combatSkill == talentDef?.name,
      )
      .firstOrNull;
  if (katalogWaffe != null && katalogWaffe.possibleManeuvers.isNotEmpty) {
    final erlaubte = normalizeManeuverIds([
      ...katalogWaffe.possibleManeuvers.map(
        (name) => name.split('(').first.trim(),
      ),
      ...katalogWaffe.activeManeuvers,
      ...snapshot.combatPreviewStats.waffenmeisterAdditionalManeuvers,
    ], catalogManeuvers: katalog.maneuvers);
    if (!erlaubte.contains(m.id)) {
      sperren.add('Waffe lässt dieses Manöver laut Katalog nicht zu.');
    }
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
  final typ = m.typ.toLowerCase();
  final parade = typ.contains('parade') || typ.contains('abwehr');
  return pruefeGefechtsaktion(
    s,
    gefechtswerteFuer(snapshot),
    parade ? Gefechtsaktion.parade : Gefechtsaktion.angriff,
    zuschlag: zuschlag,
    manuellerZielwert: zielwert,
    abwehrAufAttacke: m.name.toLowerCase() == 'gegenhalten',
    sperrGruende: sperren,
    eigenerAuftrag: eigenerAuftrag,
    distanzSchritte: distanzSchritte,
    pruefGruende: [
      'Manövervoraussetzungen, Aktionskosten und Folgen manuell prüfen.',
      if (snapshot.combatPreviewStats.waffenmeisterManeuverReductions
          .containsKey(m.id))
        'Waffenmeister-Erleichterung in der bestätigten Erschwernis berücksichtigen.',
      if (m.voraussetzungen.isNotEmpty) m.voraussetzungen,
      if (m.name.toLowerCase().contains('hammerschlag')) 'Alle nicht freien Aktionen müssen ungenutzt sein; Talent, Gegnergröße und Schild prüfen.',
    ],
  );
}

/// Sortiert nutzbare und zu prüfende Manöver vor die erklärbaren Sperren.
List<ManeuverDef> gefechtsManoeverliste(
  Gefechtszustand s,
  HeroComputedSnapshot snapshot,
  RulesCatalog katalog,
) {
  final status = <String, Gefechtsfreigabe>{
    for (final m in katalog.maneuvers)
      m.id: pruefeGefechtsmanoever(
        s,
        snapshot,
        katalog,
        m,
        zuschlag: gefechtsManoeverZuschlag(m),
      ).status,
  };
  final liste = List<ManeuverDef>.of(katalog.maneuvers);
  liste.sort((a, b) {
    final sortierung = status[a.id]!.index.compareTo(status[b.id]!.index);
    return sortierung != 0 ? sortierung : a.name.compareTo(b.name);
  });
  return liste;
}

/// Übernimmt eindeutig bezifferte Katalogzuschläge; variable Ansagen bleiben offen.
int gefechtsManoeverZuschlag(ManeuverDef m) {
  final treffer = RegExp(
    r'^(?:(?:Angriff|Abwehr|Attacke|Parade)\s*)?\+?(\d+)(?=\s|\+|$)',
    caseSensitive: false,
  ).firstMatch(m.erschwernis.trim());
  return treffer == null ? 0 : int.parse(treffer.group(1)!);
}
