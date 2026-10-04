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
import 'waffenmeister_rules.dart';
import 'gefecht_kampfmittel_rules.dart';
import 'gefecht_filter_rules.dart';
import 'gefecht_hand_rules.dart';

/// Ersetzt Vorschau-INI durch Sitzungswerte und übernimmt aktuelle Heldendaten.
Gefechtswerte gefechtswerteFuer(
  HeroComputedSnapshot snapshot, {
  RulesCatalog? katalog,
  GefechtsKampfmittelwahl? kampfmittel,
}) {
  final c = snapshot.combatPreviewStats;
  final config = snapshot.hero.combatConfig;
  final profil = gefechtsKampfmittelFuer(snapshot, kampfmittel);
  final waffe = profil?.waffe ?? config.selectedWeaponOrNull;
  final haupt = config.selectedWeaponOrNull;
  final zusatzBelegung =
      haupt != null &&
      gefechtsWaffeEinhaendig(haupt) &&
      gefechtsKampfmittelprofile(snapshot).every((p) => p.sperren.isEmpty);
  final definition = katalog?.weapons
      .where((w) => w.name == waffe?.weaponType)
      .firstOrNull;
  final laenge = int.tryParse(definition?.length ?? '');
  bool sf(String id) => isCombatSpecialAbilityActive(config, id);
  final manoever = normalizeManeuverIds(config.specialRules.activeManeuvers);
  bool kennt(String id) =>
      manoever.contains(id) || manoever.contains('$id::${waffe?.talentId}');
  final schildZusatz =
      zusatzBelegung &&
      c.offhandIsShield &&
      sf('ksf_schildkampf_ii') &&
      waffe != null &&
      gefechtsWaffeEinhaendig(waffe) &&
      c.beKampf <= 4 &&
      !c.offhandName.toLowerCase().contains('turmschild');
  final nebenAttacke =
      zusatzBelegung &&
      c.twoWeaponCombat
              ?.optionFor(TwoWeaponActionType.extraOffhandAttack)
              ?.isAvailable ==
          true;
  final nebenParade =
      zusatzBelegung &&
      c.twoWeaponCombat
              ?.optionFor(TwoWeaponActionType.extraOffhandParry)
              ?.isAvailable ==
          true;
  return Gefechtswerte(
    konkreteKampfmittel: true,
    iniBasis:
        c.kampfInitiative -
        c.iniWurfEffective -
        snapshot.wundEffekte.aktuellerIniMalus,
    at: profil?.at ?? c.at,
    pa: profil?.pa ?? c.pa,
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
    schildWm: c.offhandIsShield
        ? config.offhandEquipment[config.offhandAssignment.equipmentIndex].paMod
        : 0,
    schildkampf2: sf('ksf_schildkampf_ii'),
    turmschild: c.offhandName.toLowerCase().contains('turmschild'),
    ausweichen1: sf('ksf_ausweichen_i'),
    aufmerksamkeit: sf('ksf_aufmerksamkeit'),
    kampfgespuer: sf('ksf_kampfgespuer'),
    klingentaenzerAktiv: sf('ksf_klingentaenzer') && c.beKampf <= 2,
    stabUmwandlung:
        waffe?.talentId == 'tal_staebe' &&
        (snapshot.hero.talents['tal_staebe']?.talentValue ?? 0) >= 10,
    zusatzaktionen: schildZusatz || nebenAttacke || nebenParade ? 1 : 0,
    zusatzAttacke: nebenAttacke,
    zusatzParade: nebenParade,
    waffeVorhanden: waffe != null && waffe.name.trim().isNotEmpty,
    fernkampf: kampfmittel?.art == GefechtsKampfmittelArt.nebenwaffe
        ? c.offhandPreview?.isRangedWeapon == true
        : c.isRangedWeapon,
    waffenDk: waffe?.distanceClass ?? '',
    waffe: waffe,
    scharfschuetze: kennt('man_scharfschuetze'),
    meisterschuetze: kennt('man_meisterschuetze'),
    waffenmeister: computeWaffenmeisterEffects(
      waffenmeisterschaften: config.waffenmeisterschaften,
      activeWeaponType: waffe?.weaponType ?? '',
      activeTalentId: waffe?.talentId ?? '',
    ).isActive,
    defensiverKampfstil: kennt('man_defensiver_kampfstil'),
    halbschwert: kennt('man_halbschwert'),
    umwandlungVerboten:
        (laenge != null && laenge >= 200) ||
        (definition?.name.toLowerCase().contains('improvisiert') ?? false),
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
  GefechtsKampfmittelwahl? kampfmittel,
}) {
  final config = snapshot.hero.combatConfig;
  final profil = gefechtsKampfmittelFuer(snapshot, kampfmittel);
  final waffe = profil?.waffe ?? config.selectedWeapon;
  final sperren = <String>[];
  if (m.typ.trim().isEmpty &&
      gefechtsManoeverkategorien(m).contains(GefechtsManoeverfilter.sonstige)) {
    sperren.add(
      'Diese Sonderfertigkeit besitzt keine ausführbare Einzelaktion.',
    );
  }
  final name = m.name.toLowerCase();
  final schild = gefechtsSchildmanoever(snapshot, m.name);
  sperren.addAll(schild.sperren);
  if (name.contains('klingenwand') ||
      name.contains('klingensturm') ||
      name.contains('doppelangriff') ||
      m.id == 'man_eisenhagel') {
    sperren.add(
      'Geteilte Pools und geordnete Einzelangriffe am Spieltisch '
      'führen; keine vollständige Abwicklung als Einzelprobe.',
    );
  }
  if (distanzSchritte != 0 && !name.contains('finte')) {
    sperren.add('Distanzänderung nur ohne Manöver oder mit bestätigter Finte.');
  }
  final gelernt = learnedManeuverIds(config, katalog);
  final basisAnsage = m.id == 'man_finte' || m.id == 'man_wuchtschlag';
  final talentGelernt = gelernt.contains('${m.id}::${waffe.talentId}');
  if (!basisAnsage &&
      m.mussSeparatErlerntWerden &&
      !gelernt.contains(m.id) &&
      !talentGelernt) {
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
    if (!basisAnsage && v.status == RequirementStatus.nichtErfuellt) {
      sperren.add('${v.sollText}: ${v.istText}');
    }
  }
  final talentDef = katalog.talents
      .where((t) => t.id == waffe.talentId)
      .firstOrNull;
  final katalogWaffe = katalog.weapons
      .where(
        (w) =>
            w.name ==
                (kampfmittel?.art == GefechtsKampfmittelArt.schild
                    ? profil?.name
                    : waffe.weaponType) &&
            (kampfmittel?.art == GefechtsKampfmittelArt.schild ||
                w.combatSkill == talentDef?.name),
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
  final aktion = gefechtsAktionMitKampfmittel(
    gefechtsManoeveraktion(m),
    kampfmittel,
  );
  return pruefeGefechtsaktion(
    s,
    gefechtswerteFuer(snapshot, katalog: katalog, kampfmittel: kampfmittel),
    aktion,
    zuschlag:
        zuschlag +
        gefechtsManoeverZuschlag(m) +
        schild.zuschlag -
        (kampfmittel?.art == GefechtsKampfmittelArt.nebenwaffe
            ? snapshot
                      .combatPreviewStats
                      .offhandPreview
                      ?.waffenmeisterManeuverReductions[m.id] ??
                  0
            : snapshot.combatPreviewStats.waffenmeisterManeuverReductions[m
                      .id] ??
                  0),
    manuellerZielwert: zielwert,
    abwehrAufAttacke: m.name.toLowerCase() == 'gegenhalten',
    sperrGruende: sperren,
    eigenerAuftrag: eigenerAuftrag,
    distanzSchritte: distanzSchritte,
    pruefGruende: [
      if (schild.zuschlag != 0)
        'Schildführung: zusätzlicher Manöverzuschlag +${schild.zuschlag}; AT-WM bereits im Grundwert.',
      'Manövervoraussetzungen, Aktionskosten und Folgen manuell prüfen.',
      if (snapshot.combatPreviewStats.waffenmeisterManeuverReductions
          .containsKey(m.id))
        'Waffenmeister-Erleichterung wurde automatisch genau einmal abgezogen.',
      if (m.voraussetzungen.isNotEmpty) m.voraussetzungen,
      if (m.name.toLowerCase().contains('hammerschlag')) 'Alle nicht freien Aktionen müssen ungenutzt sein; Talent, Gegnergröße und Schild prüfen.',
    ],
  );
}

/// Ordnet das Manöver für Budget, Pflichtkontext und Bedienung identisch ein.
Gefechtsaktion gefechtsManoeveraktion(ManeuverDef m) {
  final kategorien = gefechtsManoeverkategorien(m);
  if (kategorien.contains(GefechtsManoeverfilter.verteidigung)) {
    return Gefechtsaktion.parade;
  }
  return kategorien.contains(GefechtsManoeverfilter.angriff)
      ? Gefechtsaktion.angriff
      : Gefechtsaktion.handlung;
}

/// Sortiert nutzbare und zu prüfende Manöver vor die erklärbaren Sperren.
List<ManeuverDef> gefechtsManoeverliste(
  Gefechtszustand s,
  HeroComputedSnapshot snapshot,
  RulesCatalog katalog,
) {
  final status = <String, Gefechtsfreigabe>{
    for (final m in katalog.maneuvers)
      m.id: pruefeGefechtsmanoever(s, snapshot, katalog, m, zuschlag: 0).status,
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
