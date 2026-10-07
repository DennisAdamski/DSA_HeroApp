import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/abgelegter_kampfgegenstand.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_se_pools.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/zukunftsfelder.dart';

/// Ein verschachteltes Heldenmodell im Tabellentest: voll belegte Instanz,
/// Laden und eine Bearbeitung ueber `copyWith`.
///
/// Gegenstueck zu `unbekannte_ausruestungsfelder_test.dart` fuer alle
/// uebrigen Modelle unter `HeroSheet` und `HeroState`.
class _Modell {
  const _Modell(
    this.name, {
    required this.schluessel,
    required this.voll,
    required this.lade,
    required this.bearbeite,
    required this.unbekannt,
  });

  final String name;
  final Set<String> schluessel;

  /// JSON einer Instanz, in der auch alle bedingten Felder belegt sind.
  final Map<String, dynamic> Function() voll;

  /// `fromJson(...).toJson()`.
  final Map<String, dynamic> Function(Map<String, dynamic>) lade;

  /// Laden, ein bekanntes Feld bearbeiten, `toJson()`.
  final Map<String, dynamic> Function(Map<String, dynamic>) bearbeite;

  /// `fromJson(...).unbekannteFelder`.
  final Map<String, Object?> Function(Map<String, dynamic>) unbekannt;
}

const _zukunft = <String, dynamic>{
  'stufe': 2,
  'liste': <Object?>[1, 'zwei', null],
};

final _kampf = <_Modell>[
  _Modell(
    'AbgelegterKampfgegenstand',
    schluessel: AbgelegterKampfgegenstand.jsonSchluessel,
    voll: () => const AbgelegterKampfgegenstand(
      waffe: MainWeaponSlot(name: 'Dolch'),
      geschoss: RangedProjectile(name: 'Pfeil'),
      ruestungsteil: ArmorPiece(name: 'Helm'),
      nebenhandteil: OffhandEquipmentEntry(name: 'Schild'),
    ).toJson(),
    lade: (json) => AbgelegterKampfgegenstand.fromJson(json).toJson(),
    bearbeite: (json) =>
        AbgelegterKampfgegenstand.fromJson(json)
            .copyWith(waffe: const MainWeaponSlot(name: 'Säbel'))
            .toJson(),
    unbekannt: (json) =>
        AbgelegterKampfgegenstand.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'OffhandAssignment',
    schluessel: OffhandAssignment.jsonSchluessel,
    voll: () => const OffhandAssignment(equipmentIndex: 0).toJson(),
    lade: (json) => OffhandAssignment.fromJson(json).toJson(),
    bearbeite: (json) =>
        OffhandAssignment.fromJson(json).copyWith(weaponIndex: 1).toJson(),
    unbekannt: (json) => OffhandAssignment.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'CombatSpecialRules',
    schluessel: CombatSpecialRules.jsonSchluessel,
    voll: () => const CombatSpecialRules(
      kampfreflexe: true,
      activeCombatSpecialAbilityIds: <String>['ksf_a'],
      gladiatorStyleTalent: 'raufen',
      activeManeuvers: <String>['man_finte'],
    ).toJson(),
    lade: (json) => CombatSpecialRules.fromJson(json).toJson(),
    bearbeite: (json) =>
        CombatSpecialRules.fromJson(json).copyWith(flink: true).toJson(),
    unbekannt: (json) => CombatSpecialRules.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'CombatManualMods',
    schluessel: CombatManualMods.jsonSchluessel,
    voll: () => const CombatManualMods(atMod: 1).toJson(),
    lade: (json) => CombatManualMods.fromJson(json).toJson(),
    bearbeite: (json) =>
        CombatManualMods.fromJson(json).copyWith(iniWurf: 4).toJson(),
    unbekannt: (json) => CombatManualMods.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'WaffenmeisterConfig',
    schluessel: WaffenmeisterConfig.jsonSchluessel,
    voll: () => const WaffenmeisterConfig(
      talentId: 'tal_schwerter',
      bonuses: <WaffenmeisterBonus>[WaffenmeisterBonus()],
      additionalWeaponTypes: <String>['Säbel'],
    ).toJson(),
    lade: (json) => WaffenmeisterConfig.fromJson(json).toJson(),
    bearbeite: (json) =>
        WaffenmeisterConfig.fromJson(json).copyWith(styleName: 'Neu').toJson(),
    unbekannt: (json) => WaffenmeisterConfig.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'WaffenmeisterBonus',
    schluessel: WaffenmeisterBonus.jsonSchluessel,
    voll: () => const WaffenmeisterBonus(targetManeuver: 'man_finte').toJson(),
    lade: (json) => WaffenmeisterBonus.fromJson(json).toJson(),
    bearbeite: (json) =>
        WaffenmeisterBonus.fromJson(json).copyWith(value: 2).toJson(),
    unbekannt: (json) => WaffenmeisterBonus.fromJson(json).unbekannteFelder,
  ),
];

const _ritual = HeroRitualEntry(
  name: 'Kraft des Erzes',
  wirkung: 'Erdkraft bündeln',
  kosten: '7 AsP',
  additionalFieldValues: <HeroRitualFieldValue>[
    HeroRitualFieldValue(fieldDefId: 'probe', textValue: 'MU/IN/KO'),
  ],
);

final _talenteUndMagie = <_Modell>[
  _Modell(
    'HeroTalentEntry',
    schluessel: HeroTalentEntry.jsonSchluessel,
    voll: () => HeroTalentEntry(
      talentValue: 7,
      talentModifiers: <HeroTalentModifier>[
        HeroTalentModifier(modifier: 1, description: 'Haken'),
      ],
      combatSpecializations: const <String>['Säbel'],
    ).toJson(),
    lade: (json) => HeroTalentEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroTalentEntry.fromJson(json).copyWith(talentValue: 8).toJson(),
    unbekannt: (json) => HeroTalentEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroTalentModifier',
    schluessel: HeroTalentModifier.jsonSchluessel,
    voll: () => HeroTalentModifier(modifier: 1, description: 'Haken').toJson(),
    lade: (json) => HeroTalentModifier.fromJson(json)!.toJson(),
    bearbeite: (json) =>
        HeroTalentModifier.fromJson(json)!.copyWith(modifier: 2).toJson(),
    unbekannt: (json) => HeroTalentModifier.fromJson(json)!.unbekannteFelder,
  ),
  _Modell(
    'HeroMetaTalent',
    schluessel: HeroMetaTalent.jsonSchluessel,
    voll: () => const HeroMetaTalent(
      id: 'meta_x',
      name: 'Kräutersuchen',
      componentTalentIds: <String>['tal_a'],
      attributes: <String>['MU', 'IN', 'FF'],
    ).toJson(),
    lade: (json) => HeroMetaTalent.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroMetaTalent.fromJson(json).copyWith(be: 'x2').toJson(),
    unbekannt: (json) => HeroMetaTalent.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'TalentSpecialAbility',
    schluessel: TalentSpecialAbility.jsonSchluessel,
    voll: () => const TalentSpecialAbility(name: 'Kulturkunde').toJson(),
    lade: (json) => TalentSpecialAbility.fromJson(json).toJson(),
    bearbeite: (json) =>
        TalentSpecialAbility.fromJson(json).copyWith(note: 'Neu').toJson(),
    unbekannt: (json) => TalentSpecialAbility.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroSpellEntry',
    schluessel: HeroSpellEntry.jsonSchluessel,
    voll: () => const HeroSpellEntry(
      spellValue: 5,
      learnedRepresentation: 'Mag',
      learnedTradition: 'gildenmagier',
      specializations: <String>['Variante'],
      textOverrides: HeroSpellTextOverrides(wirkung: 'Eigene'),
    ).toJson(),
    lade: (json) => HeroSpellEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroSpellEntry.fromJson(json).copyWith(modifier: 1).toJson(),
    unbekannt: (json) => HeroSpellEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroSpellTextOverrides',
    schluessel: HeroSpellTextOverrides.jsonSchluessel,
    voll: () => const HeroSpellTextOverrides(
      aspCost: '4',
      variants: <String>['V'],
    ).toJson(),
    lade: (json) => HeroSpellTextOverrides.fromJsonValue(json)!.toJson(),
    bearbeite: (json) =>
        HeroSpellEntry(
              textOverrides: HeroSpellTextOverrides.fromJsonValue(json),
            ).copyWith(modifier: 1).toJson()['textOverrides']
            as Map<String, dynamic>,
    unbekannt: (json) =>
        HeroSpellTextOverrides.fromJsonValue(json)!.unbekannteFelder,
  ),
  _Modell(
    'HeroRitualCategory',
    schluessel: HeroRitualCategory.jsonSchluessel,
    voll: () => const HeroRitualCategory(
      id: 'rk',
      name: 'Rituale',
      knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
      ownKnowledge: HeroRitualKnowledge(name: 'Rituale'),
      rituals: <HeroRitualEntry>[_ritual],
    ).toJson(),
    lade: (json) => HeroRitualCategory.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroRitualCategory.fromJson(json).copyWith(name: 'Neu').toJson(),
    unbekannt: (json) => HeroRitualCategory.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroRitualKnowledge',
    schluessel: HeroRitualKnowledge.jsonSchluessel,
    voll: () => const HeroRitualKnowledge(name: 'Rituale').toJson(),
    lade: (json) => HeroRitualKnowledge.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroRitualKnowledge.fromJson(json).copyWith(value: 9).toJson(),
    unbekannt: (json) => HeroRitualKnowledge.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroRitualEntry',
    schluessel: HeroRitualEntry.jsonSchluessel,
    voll: () => _ritual.toJson(),
    lade: (json) => HeroRitualEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroRitualEntry.fromJson(json).copyWith(kosten: '9 AsP').toJson(),
    unbekannt: (json) => HeroRitualEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroRitualFieldDef',
    schluessel: HeroRitualFieldDef.jsonSchluessel,
    voll: () => const HeroRitualFieldDef(
      id: 'probe',
      label: 'Probe',
      type: HeroRitualFieldType.threeAttributes,
    ).toJson(),
    lade: (json) => HeroRitualFieldDef.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroRitualFieldDef.fromJson(json).copyWith(label: 'Neu').toJson(),
    unbekannt: (json) => HeroRitualFieldDef.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroRitualFieldValue',
    schluessel: HeroRitualFieldValue.jsonSchluessel,
    voll: () => const HeroRitualFieldValue(
      fieldDefId: 'probe',
      attributeCodes: <String>['MU', 'IN', 'KO'],
    ).toJson(),
    lade: (json) => HeroRitualFieldValue.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroRitualFieldValue.fromJson(json).copyWith(textValue: 'x').toJson(),
    unbekannt: (json) => HeroRitualFieldValue.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'MagicSpecialAbility',
    schluessel: MagicSpecialAbility.jsonSchluessel,
    voll: () => const MagicSpecialAbility(name: 'Gefäß der Sterne').toJson(),
    lade: (json) => MagicSpecialAbility.fromJson(json).toJson(),
    bearbeite: (json) =>
        MagicSpecialAbility.fromJson(json)
            .copyWith(beschreibung: 'Neu')
            .toJson(),
    unbekannt: (json) => MagicSpecialAbility.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroLanguageEntry',
    schluessel: HeroLanguageEntry.jsonSchluessel,
    voll: () => const HeroLanguageEntry(wert: 12).toJson(),
    lade: (json) => HeroLanguageEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroLanguageEntry.fromJson(json).copyWith(wert: 13).toJson(),
    unbekannt: (json) => HeroLanguageEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroScriptEntry',
    schluessel: HeroScriptEntry.jsonSchluessel,
    voll: () => const HeroScriptEntry(wert: 6).toJson(),
    lade: (json) => HeroScriptEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroScriptEntry.fromJson(json).copyWith(modifier: 1).toJson(),
    unbekannt: (json) => HeroScriptEntry.fromJson(json).unbekannteFelder,
  ),
];

final _begleiterAbenteuerNotizen = <_Modell>[
  _Modell(
    'HeroCompanion',
    schluessel: HeroCompanion.jsonSchluessel,
    voll: () => const HeroCompanion(
      id: 'b1',
      mu: 1,
      kl: 1,
      inn: 1,
      ch: 1,
      ff: 1,
      ge: 1,
      ko: 1,
      kk: 1,
      ini: 1,
      magieresistenz: 1,
      loyalitaet: 1,
      apGesamt: 1,
      apAusgegeben: 1,
      maxLep: 1,
      maxAup: 1,
      maxAsp: 1,
      gw: 1,
      au: 1,
      ritualCategories: <HeroRitualCategory>[
        HeroRitualCategory(
          id: 'rk',
          name: 'R',
          knowledgeMode: HeroRitualKnowledgeMode.derivedTalents,
        ),
      ],
      steigerungen: <String, int>{'mu': 1},
      startLep: 1,
      startAup: 1,
      startAsp: 1,
      startMr: 1,
    ).toJson(),
    lade: (json) => HeroCompanion.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroCompanion.fromJson(json).copyWith(name: 'Krähe').toJson(),
    unbekannt: (json) => HeroCompanion.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroCompanionAttack',
    schluessel: HeroCompanionAttack.jsonSchluessel,
    voll: () => const HeroCompanionAttack(
      id: 'a1',
      at: 10,
      pa: 5,
      steigerungAt: 1,
      steigerungPa: 1,
    ).toJson(),
    lade: (json) => HeroCompanionAttack.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroCompanionAttack.fromJson(json).copyWith(tp: '1W6').toJson(),
    unbekannt: (json) => HeroCompanionAttack.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroCompanionSonderfertigkeit',
    schluessel: HeroCompanionSonderfertigkeit.jsonSchluessel,
    voll: () => const HeroCompanionSonderfertigkeit(name: 'SF').toJson(),
    lade: (json) => HeroCompanionSonderfertigkeit.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroCompanionSonderfertigkeit.fromJson(json)
            .copyWith(beschreibung: 'Neu')
            .toJson(),
    unbekannt: (json) =>
        HeroCompanionSonderfertigkeit.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroCompanionSpeed',
    schluessel: HeroCompanionSpeed.jsonSchluessel,
    voll: () => const HeroCompanionSpeed(art: 'Fliegen', wert: 12).toJson(),
    lade: (json) => HeroCompanionSpeed.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroCompanionSpeed.fromJson(json).copyWith(wert: 14).toJson(),
    unbekannt: (json) => HeroCompanionSpeed.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroAdventureEntry',
    schluessel: HeroAdventureEntry.jsonSchluessel,
    voll: () => const HeroAdventureEntry(id: 'ab1', title: 'T').toJson(),
    lade: (json) => HeroAdventureEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroAdventureEntry.fromJson(json).copyWith(summary: 'S').toJson(),
    unbekannt: (json) => HeroAdventureEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroAdventureSeReward',
    schluessel: HeroAdventureSeReward.jsonSchluessel,
    voll: () => const HeroAdventureSeReward(targetId: 'tal_a').toJson(),
    lade: (json) => HeroAdventureSeReward.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroAdventureSeReward.fromJson(json).copyWith(count: 2).toJson(),
    unbekannt: (json) => HeroAdventureSeReward.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroAdventureDateValue',
    schluessel: HeroAdventureDateValue.jsonSchluessel,
    voll: () => const HeroAdventureDateValue(
      day: '1',
      month: 'praios',
      year: '1040',
    ).toJson(),
    lade: (json) => HeroAdventureDateValue.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroAdventureDateValue.fromJson(json).copyWith(day: '2').toJson(),
    unbekannt: (json) => HeroAdventureDateValue.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroAdventurePersonEntry',
    schluessel: HeroAdventurePersonEntry.jsonSchluessel,
    voll: () =>
        const HeroAdventurePersonEntry(id: 'p1', name: 'Answin').toJson(),
    lade: (json) => HeroAdventurePersonEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroAdventurePersonEntry.fromJson(json)
            .copyWith(description: 'D')
            .toJson(),
    unbekannt: (json) =>
        HeroAdventurePersonEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroAdventureLootEntry',
    schluessel: HeroAdventureLootEntry.jsonSchluessel,
    voll: () => const HeroAdventureLootEntry(id: 'l1', name: 'Kette').toJson(),
    lade: (json) => HeroAdventureLootEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroAdventureLootEntry.fromJson(json).copyWith(quantity: '2').toJson(),
    unbekannt: (json) => HeroAdventureLootEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroNoteEntry',
    schluessel: HeroNoteEntry.jsonSchluessel,
    voll: () => const HeroNoteEntry(title: 'T').toJson(),
    lade: (json) => HeroNoteEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroNoteEntry.fromJson(json).copyWith(description: 'D').toJson(),
    unbekannt: (json) => HeroNoteEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroConnectionEntry',
    schluessel: HeroConnectionEntry.jsonSchluessel,
    voll: () => const HeroConnectionEntry(name: 'Answin').toJson(),
    lade: (json) => HeroConnectionEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroConnectionEntry.fromJson(json).copyWith(ort: 'Punin').toJson(),
    unbekannt: (json) => HeroConnectionEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroReisebericht',
    schluessel: HeroReisebericht.jsonSchluessel,
    voll: () => const HeroReisebericht(
      checkedIds: <String>{'a'},
      wahlSeZuordnungen: <String, String>{'b': 'tal_a'},
    ).toJson(),
    lade: (json) => HeroReisebericht.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroReisebericht.fromJson(json)
            .copyWith(appliedRewardIds: <String>{'c'})
            .toJson(),
    unbekannt: (json) => HeroReisebericht.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'ReiseberichtOpenItem',
    schluessel: ReiseberichtOpenItem.jsonSchluessel,
    voll: () => const ReiseberichtOpenItem(
      name: 'Thorwal',
      klassifikation: 'normal',
      ap: 10,
    ).toJson(),
    lade: (json) => ReiseberichtOpenItem.fromJson(json).toJson(),
    bearbeite: (json) =>
        ReiseberichtOpenItem.fromJson(json).copyWith(ap: 15).toJson(),
    unbekannt: (json) => ReiseberichtOpenItem.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroGruppenMitgliedschaft',
    schluessel: HeroGruppenMitgliedschaft.jsonSchluessel,
    voll: () => const HeroGruppenMitgliedschaft(
      gruppenCode: 'g1',
      externeHeldIds: <String>['x'],
    ).toJson(),
    lade: (json) => HeroGruppenMitgliedschaft.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroGruppenMitgliedschaft.fromJson(json)
            .copyWith(gruppenName: 'N')
            .toJson(),
    unbekannt: (json) =>
        HeroGruppenMitgliedschaft.fromJson(json).unbekannteFelder,
  ),
];

const _rahmen = AvatarGesichtsrahmen(
  links: 0.25,
  oben: 0.25,
  breite: 0.5,
  hoehe: 0.5,
);

final _eintrag = HeroAdvancementEntry(
  id: 'e1',
  sessionId: 's1',
  createdAt: DateTime.utc(2026, 9, 20),
  kind: AdvancementKind.talent,
  targetId: 'tal_a',
  label: 'A',
  fromValue: 1,
  toValue: 2,
  apCost: 3,
);

// Voll belegter Merkmalseintrag (alle bedingten Felder gesetzt).
HeroMerkmal _merkmal() => const HeroMerkmal(
  katalogId: 'adv_hohe_lebenskraft',
  text: 'Hohe Lebenskraft 3',
  wert: 3,
  auswahl: 'A',
  kandidatenIds: <String>['adv_a'],
  zuordnung: HeroMerkmalZuordnung.migration,
);

final _merkmale = <_Modell>[
  _Modell(
    'HeroMerkmal',
    schluessel: HeroMerkmal.jsonSchluessel,
    voll: () => _merkmal().toJson(),
    lade: (json) => HeroMerkmal.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroMerkmal.fromJson(json).copyWith(wert: 4, text: 'X 4').toJson(),
    unbekannt: (json) => HeroMerkmal.fromJson(json).unbekannteFelder,
  ),
];

final _grundwerteAvatarVerlauf = <_Modell>[
  _Modell(
    'Attributes',
    schluessel: Attributes.jsonSchluessel,
    voll: () => const Attributes.zero().toJson(),
    lade: (json) => Attributes.fromJson(json).toJson(),
    bearbeite: (json) => Attributes.fromJson(json).copyWith(mu: 14).toJson(),
    unbekannt: (json) => Attributes.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'BoughtStats',
    schluessel: BoughtStats.jsonSchluessel,
    voll: () => const BoughtStats(lep: 1).toJson(),
    lade: (json) => BoughtStats.fromJson(json).toJson(),
    bearbeite: (json) => BoughtStats.fromJson(json).copyWith(mr: 2).toJson(),
    unbekannt: (json) => BoughtStats.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'StatModifiers',
    schluessel: StatModifiers.jsonSchluessel,
    voll: () => const StatModifiers(gs: 1).toJson(),
    lade: (json) => StatModifiers.fromJson(json).toJson(),
    bearbeite: (json) => StatModifiers.fromJson(json).copyWith(rs: 2).toJson(),
    unbekannt: (json) => StatModifiers.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroAttributeSePool',
    schluessel: HeroAttributeSePool.jsonSchluessel,
    voll: () => const HeroAttributeSePool(mu: 1).toJson(),
    lade: (json) => HeroAttributeSePool.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroAttributeSePool.fromJson(json).copyWith(kl: 2).toJson(),
    unbekannt: (json) => HeroAttributeSePool.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroStatSePool',
    schluessel: HeroStatSePool.jsonSchluessel,
    voll: () => const HeroStatSePool(lep: 1).toJson(),
    lade: (json) => HeroStatSePool.fromJson(json).toJson(),
    bearbeite: (json) => HeroStatSePool.fromJson(json).copyWith(mr: 2).toJson(),
    unbekannt: (json) => HeroStatSePool.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroResourceActivationConfig',
    schluessel: HeroResourceActivationConfig.jsonSchluessel,
    voll: () => const HeroResourceActivationConfig(
      magicEnabledOverride: true,
      divineEnabledOverride: false,
    ).toJson(),
    lade: (json) => HeroResourceActivationConfig.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroResourceActivationConfig.fromJson(json)
            .copyWith(magicEnabledOverride: null)
            .toJson(),
    unbekannt: (json) =>
        HeroResourceActivationConfig.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'AventurianDate',
    schluessel: AventurianDate.jsonSchluessel,
    voll: () =>
        const AventurianDate(day: '3', month: 'rondra', year: '1016').toJson(),
    lade: (json) => AventurianDate.fromJson(json).toJson(),
    bearbeite: (json) =>
        AventurianDate.fromJson(json).copyWith(day: '4').toJson(),
    unbekannt: (json) => AventurianDate.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'AvatarGalleryEntry',
    schluessel: AvatarGalleryEntry.jsonSchluessel,
    voll: () => const AvatarGalleryEntry(
      id: 'b1',
      fileName: 'b1.png',
      headerFocusX: 0.5,
      headerFocusY: 0.5,
      headerZoom: 1.5,
      gesichtsbefund: AvatarGesichtsbefund(bildBreite: 4, bildHoehe: 6),
    ).toJson(),
    lade: (json) => AvatarGalleryEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        AvatarGalleryEntry.fromJson(json).copyWith(headerZoom: 2).toJson(),
    unbekannt: (json) => AvatarGalleryEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'AvatarGesichtsbefund',
    schluessel: AvatarGesichtsbefund.jsonSchluessel,
    voll: () => const AvatarGesichtsbefund(
      bildBreite: 4,
      bildHoehe: 6,
      gesicht: _rahmen,
      konfidenz: 0.5,
    ).toJson(),
    lade: (json) => AvatarGesichtsbefund.fromJson(json)!.toJson(),
    // Ohne copyWith: bearbeitet wird der Galerieeintrag, der den Befund traegt.
    bearbeite: (json) =>
        AvatarGalleryEntry.fromJson(<String, dynamic>{
              'id': 'b1',
              'fileName': 'b1.png',
              'gesicht': json,
            }).copyWith(headerZoom: 2).toJson()['gesicht']
            as Map<String, dynamic>,
    unbekannt: (json) => AvatarGesichtsbefund.fromJson(json)!.unbekannteFelder,
  ),
  _Modell(
    'AvatarGesichtsrahmen',
    schluessel: AvatarGesichtsrahmen.jsonSchluessel,
    voll: () => _rahmen.toJson(),
    lade: (json) => AvatarGesichtsrahmen.fromJson(json)!.toJson(),
    bearbeite: (json) => AvatarGesichtsrahmen.fromJson(json)!.toJson(),
    unbekannt: (json) => AvatarGesichtsrahmen.fromJson(json)!.unbekannteFelder,
  ),
  _Modell(
    'AvatarSnapshot',
    schluessel: AvatarSnapshot.jsonSchluessel,
    voll: () => AvatarSnapshot(
      erstelltAm: 'x',
      attributes: const <String, int>{'MU': 1},
    ).toJson(),
    lade: (json) => AvatarSnapshot.fromJson(json).toJson(),
    // Unveraenderlich: bearbeitet wird das Aussehen, das ihn traegt.
    bearbeite: (json) =>
        HeroAppearance.fromJson(<String, dynamic>{'avatarSnapshot': json})
                .copyWith(haarfarbe: 'schwarz')
                .toJson()['avatarSnapshot']
            as Map<String, dynamic>,
    unbekannt: (json) => AvatarSnapshot.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroAdvancementEntry',
    schluessel: HeroAdvancementEntry.jsonSchluessel,
    voll: () => _eintrag.toJson(),
    lade: (json) => HeroAdvancementEntry.fromJson(json).toJson(),
    // Unveraenderlicher Erwerbsnachweis: er wird nur neu geschrieben.
    bearbeite: (json) => HeroAdvancementEntry.fromJson(json).toJson(),
    unbekannt: (json) => HeroAdvancementEntry.fromJson(json).unbekannteFelder,
  ),
];

SpellDuration _dauer() =>
    SpellDuration(amount: 4, remaining: 2, unit: SpellDurationUnit.spielrunden);

final _zustand = <_Modell>[
  _Modell(
    'AttributeModifiers',
    schluessel: AttributeModifiers.jsonSchluessel,
    voll: () => const AttributeModifiers(ge: 1).toJson(),
    lade: (json) => AttributeModifiers.fromJson(json).toJson(),
    bearbeite: (json) =>
        AttributeModifiers.fromJson(json).copyWith(kk: 2).toJson(),
    unbekannt: (json) => AttributeModifiers.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'ActiveSpellEffectsState',
    schluessel: ActiveSpellEffectsState.jsonSchluessel,
    voll: () => const ActiveSpellEffectsState()
        .withToggled('e1', true)
        .withDetail('e1', const ActiveSpellEffectDetail(amount: 2))
        .toJson(),
    lade: (json) => ActiveSpellEffectsState.fromJson(json).toJson(),
    bearbeite: (json) =>
        ActiveSpellEffectsState.fromJson(json).withToggled('e2', true).toJson(),
    unbekannt: (json) =>
        ActiveSpellEffectsState.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'ActiveSpellEffectDetail',
    schluessel: ActiveSpellEffectDetail.jsonSchluessel,
    voll: () => ActiveSpellEffectDetail(amount: 2, duration: _dauer()).toJson(),
    lade: (json) => ActiveSpellEffectDetail.fromJson(json).toJson(),
    bearbeite: (json) =>
        ActiveSpellEffectDetail.fromJson(json).copyWith(amount: 3).toJson(),
    unbekannt: (json) =>
        ActiveSpellEffectDetail.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'SpellDuration',
    schluessel: SpellDuration.jsonSchluessel,
    voll: () => _dauer().toJson(),
    lade: (json) => SpellDuration.fromJson(json).toJson(),
    bearbeite: (json) =>
        SpellDuration.fromJson(json).copyWith(remaining: 1).toJson(),
    unbekannt: (json) => SpellDuration.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'WundZustand',
    schluessel: WundZustand.jsonSchluessel,
    voll: () => const WundZustand(
      wundenProZone: <WundZone, int>{WundZone.brust: 2},
      kopfIniMalus: 1,
      unterdrueckteWundenProZone: <WundZone, int>{WundZone.brust: 1},
      kampfunfaehigIgnoriert: true,
    ).toJson(),
    lade: (json) => WundZustand.fromJson(json).toJson(),
    bearbeite: (json) =>
        WundZustand.fromJson(json).mitWundeHinzu(WundZone.kopf).toJson(),
    unbekannt: (json) => WundZustand.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'DiceLogEntry',
    schluessel: DiceLogEntry.jsonSchluessel,
    voll: () => DiceLogEntry(
      timestamp: DateTime.utc(2026, 9, 28),
      type: ProbeType.attribute,
      title: 'Mut',
      subtitle: '',
      success: true,
      diceValues: const <int>[3],
      targetValue: 14,
      total: 3,
      isNeutral: true,
    ).toJson(),
    lade: (json) => DiceLogEntry.fromJson(json).toJson(),
    // Unveraenderlich: bearbeitet wird der Zustand, der das Protokoll traegt.
    bearbeite: (json) =>
        (HeroState.fromJson(<String, dynamic>{
                      'diceLog': <Object?>[json],
                    }).copyWith(currentLep: 3).toJson()['diceLog']
                    as List)
                .single
            as Map<String, dynamic>,
    unbekannt: (json) => DiceLogEntry.fromJson(json).unbekannteFelder,
  ),
];

/// Ein Aufzaehlungsfeld im Tabellentest.
///
/// [lade] laedt und schreibt, [gleich] setzt per `copyWith` denselben
/// (Ersatz-)Wert und aendert ein anderes Feld, [anders] setzt einen anderen
/// Wert, dessen JSON [andersJson] ist; [ersatz] liefert den geladenen Wert,
/// mit dem Regeln rechnen.
class _EnumFeld {
  const _EnumFeld(
    this.name,
    this.schluessel, {
    required this.voll,
    required this.lade,
    required this.gleich,
    required this.ersatz,
    required this.erwarteterErsatz,
    this.anders,
    this.andersJson,
  });

  final String name;
  final String schluessel;
  final Map<String, dynamic> Function() voll;
  final Map<String, dynamic> Function(Map<String, dynamic>) lade;
  final Map<String, dynamic> Function(Map<String, dynamic>) gleich;
  final Map<String, dynamic> Function(Map<String, dynamic>)? anders;
  final Object? andersJson;
  final Object? Function(Map<String, dynamic>) ersatz;
  final Object? erwarteterErsatz;
}

final _enumFelder = <_EnumFeld>[
  for (final (schluessel, anders, andersJson, ersatz)
      in <
        (
          String,
          HeroInventoryEntry Function(HeroInventoryEntry),
          String,
          Object,
        )
      >[
        (
          'itemType',
          (e) => e.copyWith(itemType: InventoryItemType.wertvolles),
          'wertvolles',
          InventoryItemType.sonstiges,
        ),
        (
          'source',
          (e) => e.copyWith(source: InventoryItemSource.ruestung),
          'ruestung',
          InventoryItemSource.manuell,
        ),
        (
          'traegerTyp',
          (e) => e.copyWith(traegerTyp: InventoryTraeger.begleiter),
          'begleiter',
          InventoryTraeger.held,
        ),
      ])
    _EnumFeld(
      'HeroInventoryEntry.$schluessel',
      schluessel,
      voll: () => const HeroInventoryEntry(gegenstand: 'Seil').toJson(),
      lade: (json) => HeroInventoryEntry.fromJson(json).toJson(),
      gleich: (json) {
        final e = HeroInventoryEntry.fromJson(json);
        return e
            .copyWith(
              itemType: e.itemType,
              source: e.source,
              traegerTyp: e.traegerTyp,
              wert: '3',
            )
            .toJson();
      },
      anders: (json) => anders(HeroInventoryEntry.fromJson(json)).toJson(),
      andersJson: andersJson,
      ersatz: (json) => switch (schluessel) {
        'itemType' => HeroInventoryEntry.fromJson(json).itemType,
        'source' => HeroInventoryEntry.fromJson(json).source,
        _ => HeroInventoryEntry.fromJson(json).traegerTyp,
      },
      erwarteterErsatz: ersatz,
    ),
  _EnumFeld(
    'InventoryItemModifier.kind',
    'kind',
    voll: () => const InventoryItemModifier(
      kind: InventoryModifierKind.stat,
      targetId: 'gs',
      wert: 1,
    ).toJson(),
    lade: (json) => InventoryItemModifier.fromJson(json).toJson(),
    gleich: (json) {
      final m = InventoryItemModifier.fromJson(json);
      return m.copyWith(kind: m.kind, wert: 2).toJson();
    },
    anders: (json) =>
        InventoryItemModifier.fromJson(json)
            .copyWith(kind: InventoryModifierKind.talent)
            .toJson(),
    andersJson: 'talent',
    ersatz: (json) => InventoryItemModifier.fromJson(json).kind,
    erwarteterErsatz: InventoryModifierKind.stat,
  ),
  _EnumFeld(
    'MainWeaponSlot.combatType',
    'combatType',
    voll: () => const MainWeaponSlot(name: 'Bogen').toJson(),
    lade: (json) => MainWeaponSlot.fromJson(json).toJson(),
    gleich: (json) {
      final w = MainWeaponSlot.fromJson(json);
      return w.copyWith(combatType: w.combatType, name: 'Neu').toJson();
    },
    anders: (json) =>
        MainWeaponSlot.fromJson(json)
            .copyWith(combatType: WeaponCombatType.ranged)
            .toJson(),
    andersJson: 'ranged',
    ersatz: (json) => MainWeaponSlot.fromJson(json).combatType,
    erwarteterErsatz: WeaponCombatType.melee,
  ),
  _EnumFeld(
    'OffhandEquipmentEntry.type',
    'type',
    voll: () => const OffhandEquipmentEntry(name: 'Schild').toJson(),
    lade: (json) => OffhandEquipmentEntry.fromJson(json).toJson(),
    gleich: (json) {
      final o = OffhandEquipmentEntry.fromJson(json);
      return o.copyWith(type: o.type, paMod: 1).toJson();
    },
    anders: (json) =>
        OffhandEquipmentEntry.fromJson(json)
            .copyWith(type: OffhandEquipmentType.shield)
            .toJson(),
    andersJson: 'shield',
    ersatz: (json) => OffhandEquipmentEntry.fromJson(json).type,
    erwarteterErsatz: OffhandEquipmentType.parryWeapon,
  ),
  _EnumFeld(
    'OffhandEquipmentEntry.shieldSize',
    'shieldSize',
    voll: () => const OffhandEquipmentEntry(name: 'Schild').toJson(),
    lade: (json) => OffhandEquipmentEntry.fromJson(json).toJson(),
    gleich: (json) {
      final o = OffhandEquipmentEntry.fromJson(json);
      return o.copyWith(shieldSize: o.shieldSize, paMod: 1).toJson();
    },
    anders: (json) =>
        OffhandEquipmentEntry.fromJson(json)
            .copyWith(shieldSize: ShieldSize.large)
            .toJson(),
    andersJson: 'large',
    ersatz: (json) => OffhandEquipmentEntry.fromJson(json).shieldSize,
    erwarteterErsatz: ShieldSize.small,
  ),
  _EnumFeld(
    'WaffenmeisterBonus.type',
    'type',
    voll: () => const WaffenmeisterBonus().toJson(),
    lade: (json) => WaffenmeisterBonus.fromJson(json).toJson(),
    gleich: (json) {
      final b = WaffenmeisterBonus.fromJson(json);
      return b.copyWith(type: b.type, value: 1).toJson();
    },
    anders: (json) =>
        WaffenmeisterBonus.fromJson(json)
            .copyWith(type: WaffenmeisterBonusType.iniBonus)
            .toJson(),
    andersJson: 'iniBonus',
    ersatz: (json) => WaffenmeisterBonus.fromJson(json).type,
    erwarteterErsatz: WaffenmeisterBonusType.customAdvantage,
  ),
  _EnumFeld(
    'HeroRitualCategory.knowledgeMode',
    'knowledgeMode',
    voll: () => const HeroRitualCategory(
      id: 'rk',
      name: 'R',
      knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
    ).toJson(),
    lade: (json) => HeroRitualCategory.fromJson(json).toJson(),
    gleich: (json) {
      final k = HeroRitualCategory.fromJson(json);
      return k.copyWith(knowledgeMode: k.knowledgeMode, name: 'N').toJson();
    },
    anders: (json) =>
        HeroRitualCategory.fromJson(json)
            .copyWith(knowledgeMode: HeroRitualKnowledgeMode.derivedTalents)
            .toJson(),
    andersJson: 'derivedTalents',
    ersatz: (json) => HeroRitualCategory.fromJson(json).knowledgeMode,
    erwarteterErsatz: HeroRitualKnowledgeMode.ownKnowledge,
  ),
  _EnumFeld(
    'HeroRitualFieldDef.type',
    'type',
    voll: () => const HeroRitualFieldDef(
      id: 'f',
      label: 'F',
      type: HeroRitualFieldType.text,
    ).toJson(),
    lade: (json) => HeroRitualFieldDef.fromJson(json).toJson(),
    gleich: (json) {
      final f = HeroRitualFieldDef.fromJson(json);
      return f.copyWith(type: f.type, label: 'G').toJson();
    },
    anders: (json) =>
        HeroRitualFieldDef.fromJson(json)
            .copyWith(type: HeroRitualFieldType.threeAttributes)
            .toJson(),
    andersJson: 'threeAttributes',
    ersatz: (json) => HeroRitualFieldDef.fromJson(json).type,
    erwarteterErsatz: HeroRitualFieldType.text,
  ),
  _EnumFeld(
    'HeroCompanion.typ',
    'typ',
    voll: () => const HeroCompanion(id: 'b1').toJson(),
    lade: (json) => HeroCompanion.fromJson(json).toJson(),
    gleich: (json) {
      final b = HeroCompanion.fromJson(json);
      return b.copyWith(typ: b.typ, name: 'Rabe').toJson();
    },
    anders: (json) =>
        HeroCompanion.fromJson(json)
            .copyWith(typ: BegleiterTyp.reittier)
            .toJson(),
    andersJson: 'reittier',
    ersatz: (json) => HeroCompanion.fromJson(json).typ,
    erwarteterErsatz: BegleiterTyp.sonstigerBegleiter,
  ),
  _EnumFeld(
    'HeroAdventureEntry.status',
    'status',
    voll: () => const HeroAdventureEntry(id: 'a1').toJson(),
    lade: (json) => HeroAdventureEntry.fromJson(json).toJson(),
    gleich: (json) {
      final a = HeroAdventureEntry.fromJson(json);
      return a.copyWith(status: a.status, title: 'T').toJson();
    },
    anders: (json) =>
        HeroAdventureEntry.fromJson(json)
            .copyWith(status: HeroAdventureStatus.completed)
            .toJson(),
    andersJson: 'completed',
    ersatz: (json) => HeroAdventureEntry.fromJson(json).status,
    erwarteterErsatz: HeroAdventureStatus.current,
  ),
  _EnumFeld(
    'HeroAdventureSeReward.targetType',
    'targetType',
    voll: () => const HeroAdventureSeReward(targetId: 'x').toJson(),
    lade: (json) => HeroAdventureSeReward.fromJson(json).toJson(),
    gleich: (json) {
      final r = HeroAdventureSeReward.fromJson(json);
      return r.copyWith(targetType: r.targetType, count: 2).toJson();
    },
    anders: (json) =>
        HeroAdventureSeReward.fromJson(json)
            .copyWith(targetType: HeroAdventureSeTargetType.grundwert)
            .toJson(),
    andersJson: 'grundwert',
    ersatz: (json) => HeroAdventureSeReward.fromJson(json).targetType,
    erwarteterErsatz: HeroAdventureSeTargetType.talent,
  ),
  _EnumFeld(
    'HeroAdventureLootEntry.itemType',
    'itemType',
    voll: () => const HeroAdventureLootEntry(id: 'l', name: 'K').toJson(),
    lade: (json) => HeroAdventureLootEntry.fromJson(json).toJson(),
    gleich: (json) {
      final l = HeroAdventureLootEntry.fromJson(json);
      return l.copyWith(itemType: l.itemType, quantity: '2').toJson();
    },
    anders: (json) =>
        HeroAdventureLootEntry.fromJson(json)
            .copyWith(itemType: InventoryItemType.wertvolles)
            .toJson(),
    andersJson: 'wertvolles',
    ersatz: (json) => HeroAdventureLootEntry.fromJson(json).itemType,
    erwarteterErsatz: InventoryItemType.sonstiges,
  ),
  _EnumFeld(
    'HeroMerkmal.zuordnung',
    'zuordnung',
    voll: () => _merkmal().toJson(),
    lade: (json) => HeroMerkmal.fromJson(json).toJson(),
    gleich: (json) {
      final m = HeroMerkmal.fromJson(json);
      return m.copyWith(zuordnung: m.zuordnung, wert: 5).toJson();
    },
    anders: (json) =>
        HeroMerkmal.fromJson(json)
            .copyWith(zuordnung: HeroMerkmalZuordnung.frei)
            .toJson(),
    andersJson: 'frei',
    ersatz: (json) => HeroMerkmal.fromJson(json).zuordnung,
    erwarteterErsatz: HeroMerkmalZuordnung.katalog,
  ),
  _EnumFeld(
    'SpellDuration.unit',
    'unit',
    voll: () => _dauer().toJson(),
    lade: (json) => SpellDuration.fromJson(json).toJson(),
    gleich: (json) {
      final d = SpellDuration.fromJson(json);
      return d.copyWith(unit: d.unit, remaining: 1).toJson();
    },
    anders: (json) =>
        SpellDuration.fromJson(json)
            .copyWith(unit: SpellDurationUnit.minuten)
            .toJson(),
    andersJson: 'minuten',
    ersatz: (json) => SpellDuration.fromJson(json).unit,
    erwarteterErsatz: SpellDurationUnit.kampfrunden,
  ),
  for (final (schluessel, ersatz) in <(String, Object)>[
    ('type', ProbeType.attribute),
    ('automaticOutcome', AutomaticOutcome.none),
  ])
    _EnumFeld(
      'DiceLogEntry.$schluessel',
      schluessel,
      voll: () => DiceLogEntry(
        timestamp: DateTime.utc(2026, 9, 28),
        type: ProbeType.talent,
        title: 'T',
        subtitle: '',
        success: true,
        diceValues: const <int>[1],
        automaticOutcome: AutomaticOutcome.success,
      ).toJson(),
      lade: (json) => DiceLogEntry.fromJson(json).toJson(),
      // Unveraenderlich: bearbeitet wird der Zustand, der ihn traegt.
      gleich: (json) =>
          (HeroState.fromJson(<String, dynamic>{
                        'diceLog': <Object?>[json],
                      }).copyWith(currentLep: 3).toJson()['diceLog']
                      as List)
                  .single
              as Map<String, dynamic>,
      ersatz: (json) => schluessel == 'type'
          ? DiceLogEntry.fromJson(json).type
          : DiceLogEntry.fromJson(json).automaticOutcome,
      erwarteterErsatz: ersatz,
    ),
  _EnumFeld(
    'AventurianDate.month',
    'month',
    voll: () =>
        const AventurianDate(day: '3', month: 'rondra', year: '1016').toJson(),
    lade: (json) => AventurianDate.fromJson(json).toJson(),
    gleich: (json) {
      final d = AventurianDate.fromJson(json);
      return d.copyWith(month: d.month, day: '4').toJson();
    },
    anders: (json) =>
        AventurianDate.fromJson(json).copyWith(month: 'phex').toJson(),
    andersJson: 'phex',
    ersatz: (json) => AventurianDate.fromJson(json).month,
    erwarteterErsatz: '',
  ),
];

// Voll belegtes JSON eines Modells samt Zukunftsfeld, frisch kopiert.
Map<String, dynamic> _mitZukunft(_Modell modell) {
  final json = jsonDecode(jsonEncode(modell.voll())) as Map<String, dynamic>;
  json['zukunftsfeld'] = jsonDecode(jsonEncode(_zukunft));
  return json;
}

// Prueft einen Satz Modelle nach demselben Muster.
void _pruefeModelle(String gruppe, List<_Modell> modelle) {
  group(gruppe, () {
    for (final modell in modelle) {
      test('${modell.name}: jeder geschriebene Schlüssel gilt als bekannt', () {
        final geschrieben = modell.voll().keys.toSet();

        expect(geschrieben.difference(modell.schluessel), isEmpty);
        expect(modell.unbekannt(modell.voll()), isEmpty);
      });

      test('${modell.name}: Laden und Bearbeiten erhalten das Feld', () {
        final json = _mitZukunft(modell);

        expect(modell.unbekannt(json), <String, Object?>{
          'zukunftsfeld': _zukunft,
        });
        expect(modell.lade(json)['zukunftsfeld'], _zukunft);
        expect(modell.bearbeite(json)['zukunftsfeld'], _zukunft);
      });

      test('${modell.name}: ohne unbekannte Felder bleibt das JSON gleich', () {
        final json = modell.voll();

        expect(modell.lade(json), json);
      });
    }
  });
}

/// JSON-Stellen, die Woerterbuecher (Schluessel → Wert) sind und keine
/// Modelle: dort ist jeder Schluessel ein Eintrag, kein Feld.
final _woerterbuecher = <RegExp>[
  RegExp(r'^(talents|spells|sprachen|schriften)$'),
  RegExp(r'^(repraesentationsTraditionen|statModifiers|attributeModifiers)$'),
  RegExp(r'^reisebericht/(openEntries|wahlSeZuordnungen)$'),
  RegExp(r'^companions/\d+/steigerungen$'),
  RegExp(r'^advancementHistory/\d+/options$'),
  RegExp(r'^avatarSnapshot/attributes$'),
  RegExp(r'^activeSpellEffects/effectDetails$'),
  RegExp(r'^wpiZustand/(wundenProZone|unterdrueckteWundenProZone)$'),
  // Spiegelt nur die gewaehlte Waffe und wird aus ihr neu geschrieben.
  RegExp(r'^combatConfig/mainWeapon(/|$)'),
];

// Alle Pfade in [json], an denen ein Modell (eine Map) steht.
List<String> _objektPfade(Object? json, [String pfad = '']) {
  if (json is Map) {
    return <String>[
      if (pfad.isNotEmpty && !_woerterbuecher.any((m) => m.hasMatch(pfad)))
        pfad,
      for (final eintrag in json.entries)
        ..._objektPfade(
          eintrag.value,
          pfad.isEmpty ? '${eintrag.key}' : '$pfad/${eintrag.key}',
        ),
    ];
  }
  if (json is List) {
    return <String>[
      for (var i = 0; i < json.length; i++)
        ..._objektPfade(json[i], pfad.isEmpty ? '$i' : '$pfad/$i'),
    ];
  }
  return const <String>[];
}

// Prueft fuer jede Objektebene von [json], ob [lade] ein dort gesetztes
// Zukunftsfeld zurueckschreibt; liefert die Pfade, an denen es verloren geht.
List<String> _verloreneEbenen(
  Map<String, dynamic> json,
  Map<String, dynamic> Function(Map<String, dynamic>) lade,
) {
  final verloren = <String>[];
  for (final pfad in _objektPfade(json)) {
    final kopie = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
    (wertAn(kopie, pfad) as Map)['zukunftsfeld'] = 1;
    if (wertAn(lade(kopie), '$pfad/zukunftsfeld') != 1) {
      verloren.add(pfad);
    }
  }
  return verloren;
}

void main() {
  group('Vollständigkeit: jede Objektebene bewahrt unbekannte Felder', () {
    test('Held (f01 samt allen Beispielinhalten)', () {
      final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal);
      final basis = mitZukunftsfeldern(
        (roh['hero'] as Map).cast<String, dynamic>(),
      ).basis;
      final json = HeroSheet.fromJson(basis).toJson();
      final pfade = _objektPfade(json);

      // Das Werkzeug deckt jede Objektebene ab, die der Held hat.
      expect(pfade.length, greaterThan(60));
      expect(
        _verloreneEbenen(json, (j) => HeroSheet.fromJson(j).toJson()),
        isEmpty,
      );
    });

    test('Laufzeitzustand (f01 samt Zaubereffekt)', () {
      final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal);
      final basis = zustandMitZukunftsfeldern(
        (roh['state'] as Map).cast<String, dynamic>(),
      ).basis;
      final json = HeroState.fromJson(basis).toJson();

      expect(_objektPfade(json), hasLength(greaterThan(6)));
      expect(
        _verloreneEbenen(json, (j) => HeroState.fromJson(j).toJson()),
        isEmpty,
      );
    });

    for (final held in Bestandsheld.values) {
      test('${held.datei}: jede vorhandene Objektebene', () {
        final bundle = ladeBestandsheld(held);
        final heldJson = bundle.hero.toJson();
        final zustandJson = bundle.state.toJson();

        expect(
          _verloreneEbenen(heldJson, (j) => HeroSheet.fromJson(j).toJson()),
          isEmpty,
        );
        expect(
          _verloreneEbenen(zustandJson, (j) => HeroState.fromJson(j).toJson()),
          isEmpty,
        );
      });
    }
  });

  _pruefeModelle('Kampfeinstellungen bewahren unbekannte Felder', _kampf);
  _pruefeModelle(
    'Talente, Zauber und Rituale bewahren unbekannte Felder',
    _talenteUndMagie,
  );

  _pruefeModelle(
    'Begleiter, Abenteuer, Notizen und Reisebericht bewahren unbekannte '
    'Felder',
    _begleiterAbenteuerNotizen,
  );

  _pruefeModelle('Vor- und Nachteile bewahren unbekannte Felder', _merkmale);

  _pruefeModelle(
    'Eigenschaften, Grundwerte, Bilder und Verlauf bewahren unbekannte Felder',
    _grundwerteAvatarVerlauf,
  );

  group('Grundwerte und Bilder: Sonderfälle', () {
    test('ein Geburtsdatum nur mit unbekannten Feldern wird geschrieben', () {
      final aussehen = HeroAppearance.fromJson(<String, dynamic>{
        'geburtsdatum': <String, dynamic>{'zukunftsfeld': 1},
      });

      expect(aussehen.toJson()['geburtsdatum'], <String, dynamic>{
        'day': '',
        'month': '',
        'year': '',
        'zukunftsfeld': 1,
      });
    });

    test('ein leeres Geburtsdatum schreibt weiterhin nichts', () {
      final aussehen = HeroAppearance.fromJson(<String, dynamic>{
        'geburtsdatum': <String, dynamic>{'day': '', 'month': '', 'year': ''},
      });

      expect(aussehen.toJson().containsKey('geburtsdatum'), isFalse);
    });

    test('effektive Startwerte behalten die Felder der Startwerte', () {
      const feld = <String, Object?>{'zukunftsfeld': 1};
      const start = Attributes(
        mu: 1,
        kl: 1,
        inn: 1,
        ch: 1,
        ff: 1,
        ge: 1,
        ko: 1,
        kk: 1,
        unbekannteFelder: feld,
      );

      final neu = start.uebernimmWerte(const Attributes.zero());

      expect(neu.mu, 0);
      expect(neu.unbekannteFelder, feld);
    });

    test('ein nicht numerisches Zukunftsfeld in persistentMods stört das '
        'Laden der benannten Modifikatoren nicht', () {
      final held = HeroSheet.fromJson(<String, dynamic>{
        'id': 'h1',
        'persistentMods': <String, dynamic>{
          'ws': <String, dynamic>{'wert': 1},
        },
        'statModifiers': <String, dynamic>{
          'ws': <Object?>[
            <String, dynamic>{'modifier': 1, 'description': 'Manuell'},
          ],
        },
      });

      expect(held.persistentMods.unbekannteFelder['ws'], <String, dynamic>{
        'wert': 1,
      });
      expect(held.statModifiers['ws']!.single.modifier, 1);
    });
  });

  _pruefeModelle(
    'Laufzeitzustand bewahrt unbekannte Felder in allen Teilmodellen',
    _zustand,
  );

  group('Laufzeitzustand: Sonderfälle', () {
    const feld = <String, Object?>{'zukunftsfeld': 1};

    test('Zusatzdaten nur mit unbekannten Feldern gelten nicht als leer', () {
      final effekte = ActiveSpellEffectsState.fromJson(<String, dynamic>{
        'activeEffectIds': <Object?>['e1'],
        'effectDetails': <String, dynamic>{
          'e1': <String, dynamic>{'amount': 0, ...feld},
        },
      });

      expect(effekte.detailFor('e1').unbekannteFelder, feld);
      expect(effekte.toJson()['effectDetails'], <String, dynamic>{
        'e1': <String, dynamic>{'amount': 0, ...feld},
      });
    });

    test('Wunden hinzufügen und entfernen behält die Felder', () {
      const zustand = WundZustand(unbekannteFelder: feld);

      final mitWunde = zustand.mitWundeHinzu(WundZone.kopf, iniWuerfelWert: 4);
      final ohneWunde = mitWunde.mitWundeEntfernt(WundZone.kopf);

      expect(mitWunde.unbekannteFelder, feld);
      expect(ohneWunde.unbekannteFelder, feld);
    });

    test('die volle Rast heilt die Wunden und behält die Felder', () {
      const zustand = HeroState(
        currentLep: 1,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 1,
        wpiZustand: WundZustand(
          wundenProZone: <WundZone, int>{WundZone.brust: 2},
          kampfunfaehigIgnoriert: true,
          unbekannteFelder: feld,
        ),
      );

      final nachRast = buildFullRestoreState(
        currentState: zustand,
        derivedStats: const DerivedStats(
          maxLep: 30,
          maxAu: 30,
          maxAsp: 0,
          maxKap: 0,
          mr: 0,
          iniBase: 0,
          atBase: 0,
          paBase: 0,
          fkBase: 0,
          gs: 0,
          ausweichen: 0,
        ),
      );

      expect(nachRast.wpiZustand.gesamtWunden, 0);
      expect(nachRast.wpiZustand.kampfunfaehigIgnoriert, isFalse);
      expect(nachRast.wpiZustand.unbekannteFelder, feld);
    });

    test('eine neue Wirkungsdauer per copyWith läuft voll und behält die '
        'Felder', () {
      final dauer = SpellDuration(
        amount: 4,
        remaining: 1,
        unit: SpellDurationUnit.kampfrunden,
        unbekannteFelder: feld,
      );

      final neu = dauer.copyWith(amount: 6, unit: SpellDurationUnit.minuten);

      expect(neu.remaining, 6);
      expect(neu.unbekannteFelder, feld);
    });
  });

  group('Unbekannte Aufzählungswerte bleiben erhalten', () {
    for (final feld in _enumFelder) {
      Map<String, dynamic> mitRohwert() =>
          jsonDecode(jsonEncode(feld.voll())) as Map<String, dynamic>
            ..[feld.schluessel] = 'zukunftsWert';

      test('${feld.name}: Regeln sehen den Ersatz, geschrieben wird der '
          'Rohwert', () {
        final json = mitRohwert();

        expect(feld.ersatz(json), feld.erwarteterErsatz);
        expect(feld.lade(json)[feld.schluessel], 'zukunftsWert');
        expect(feld.lade(feld.lade(json)), feld.lade(json), reason: 'Fixpunkt');
      });

      test(
        '${feld.name}: derselbe Wert und andere Felder lassen ihn stehen',
        () {
          expect(feld.gleich(mitRohwert())[feld.schluessel], 'zukunftsWert');
        },
      );

      if (feld.anders != null) {
        test('${feld.name}: ein anderer Wert überschreibt ihn', () {
          expect(feld.anders!(mitRohwert())[feld.schluessel], feld.andersJson);
        });
      }

      test('${feld.name}: bekannte Werte und fehlende Angaben wie bisher', () {
        final json = feld.voll();
        final ohne = Map<String, dynamic>.of(json)..remove(feld.schluessel);
        final leer = Map<String, dynamic>.of(json)..[feld.schluessel] = '';

        expect(feld.lade(json), json);
        expect(feld.lade(ohne)[feld.schluessel], isNot('zukunftsWert'));
        // Leer gilt als fehlend: Ersatz, kein Rohwert.
        expect(feld.ersatz(leer), feld.erwarteterErsatz);
        if (feld.erwarteterErsatz != '') {
          expect(feld.lade(leer)[feld.schluessel], isNot(''));
        }
      });
    }

    test('Wundzonen einer neueren Version bleiben, zählen nicht und heilen '
        'bei der vollen Rast', () {
      final zustand = HeroState.fromJson(<String, dynamic>{
        'wpiZustand': <String, dynamic>{
          'wundenProZone': <String, dynamic>{'brust': 1, 'schwanz': 2},
          'unterdrueckteWundenProZone': <String, dynamic>{'schwanz': 1},
          'kopfIniMalus': 0,
        },
      });
      final wunden = zustand.wpiZustand;

      expect(wunden.gesamtWunden, 1);
      final bearbeitet = wunden
          .mitWundeHinzu(WundZone.kopf, iniWuerfelWert: 3)
          .mitWundeEntfernt(WundZone.brust)
          .mitUnterdrueckung(WundZone.kopf, 1)
          .toJson();
      expect(bearbeitet['wundenProZone'], <String, dynamic>{
        'kopf': 1,
        'schwanz': 2,
      });
      expect(bearbeitet['unterdrueckteWundenProZone'], <String, dynamic>{
        'kopf': 1,
        'schwanz': 1,
      });

      final nachRast = buildFullRestoreState(
        currentState: zustand,
        derivedStats: const DerivedStats(
          maxLep: 30,
          maxAu: 30,
          maxAsp: 0,
          maxKap: 0,
          mr: 0,
          iniBase: 0,
          atBase: 0,
          paBase: 0,
          fkBase: 0,
          gs: 0,
          ausweichen: 0,
        ),
      );
      expect(nachRast.wpiZustand.toJson(), <String, dynamic>{
        'wundenProZone': <String, dynamic>{},
        'kopfIniMalus': 0,
      });
    });

    group('Inventarabgleich', () {
      late HeroSheet held;

      setUp(() {
        final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal);
        held = HeroSheet.fromJson((roh['hero'] as Map).cast<String, dynamic>());
      });

      List<HeroInventoryEntry> gleicheAb(HeroSheet h) =>
          reconcileInventoryWithCombat(h.inventoryEntries, h.combatConfig);

      test('Befund ARCH-07-B12: ein verknüpfter Eintrag mit unbekannter '
          'Quelle bleibt unverändert und bekommt keinen Doppelgänger', () {
        final json = held.toJson();
        final eintraege = json['inventoryEntries'] as List;
        final index = eintraege.indexWhere(
          (e) => (e as Map)['gegenstand'] == 'Leichte Armbrust',
        );
        (eintraege[index] as Map)['source'] = 'zukunftsWert';
        final zukunft = HeroSheet.fromJson(json);
        final vorher = zukunft.inventoryEntries[index];

        final ergebnis = gleicheAb(zukunft);

        final armbrust = ergebnis
            .where((e) => e.gegenstand == 'Leichte Armbrust')
            .toList();
        expect(armbrust, hasLength(1));
        expect(armbrust.single.toJson(), vorher.toJson());
        expect(armbrust.single.toJson()['source'], 'zukunftsWert');
        expect(ergebnis, hasLength(zukunft.inventoryEntries.length));
      });

      test('Befund ARCH-07-B13: eine unbekannte Kampfart behält die '
          'Geschosse samt Inventardaten', () {
        // Einmal abgeglichen wie nach dem ersten Speichern: Seit dem
        // 07.10.2026 gilt nur die geführte Waffe als ausgerüstet.
        final json = held.copyWith(inventoryEntries: gleicheAb(held)).toJson();
        final waffen = (json['combatConfig'] as Map)['weapons'] as List;
        (waffen[1] as Map)['combatType'] = 'zukunftsWert';
        final zukunft = HeroSheet.fromJson(json);

        final ergebnis = gleicheAb(zukunft);

        expect(zukunft.combatConfig.weaponSlots[1].isRanged, isFalse);
        expect(
          ergebnis.where((e) => e.gegenstand == 'Bolzen').single.slotRef,
          isNotNull,
        );
        expect(
          HeroSheet.fromJson(
            zukunft.copyWith(inventoryEntries: ergebnis).toJson(),
          ).toJson(),
          zukunft.toJson(),
          reason: 'Laden und Abgleich ändern nichts',
        );
      });
    });
  });

  group('Begleiter: Altschlüssel', () {
    test('eigenAp und vorNachteile gehen beim Laden auf', () {
      final begleiter = HeroCompanion.fromJson(<String, dynamic>{
        'id': 'b1',
        'eigenAp': 30,
        'vorNachteile': 'Treu',
      });

      expect(begleiter.apGesamt, 30);
      expect(begleiter.vorteile, 'Treu');
      expect(begleiter.unbekannteFelder, isEmpty);
      expect(begleiter.toJson().containsKey('eigenAp'), isFalse);
      expect(begleiter.toJson().containsKey('vorNachteile'), isFalse);
    });
  });

  group('Talente, Zauber und Rituale: Sonderfälle', () {
    test('Overrides nur mit unbekannten Feldern gelten nicht als leer', () {
      final eintrag = HeroSpellEntry.fromJson(<String, dynamic>{
        'spellValue': 3,
        'textOverrides': <String, dynamic>{'zukunftsfeld': 1},
      });

      expect(eintrag.textOverrides, isNotNull);
      expect(eintrag.toJson()['textOverrides'], <String, dynamic>{
        'aspCost': null,
        'targetObject': null,
        'range': null,
        'duration': null,
        'castingTime': null,
        'wirkung': null,
        'modifications': null,
        'variants': null,
        'zukunftsfeld': 1,
      });
    });

    test('leere Overrides schreiben weiterhin nichts', () {
      final eintrag = HeroSpellEntry.fromJson(<String, dynamic>{
        'spellValue': 3,
        'textOverrides': <String, dynamic>{'wirkung': null},
      });

      expect(eintrag.textOverrides, isNull);
      expect(eintrag.toJson().containsKey('textOverrides'), isFalse);
    });

    test('der Alias note der magischen SF gilt als bekannt', () {
      final sf = MagicSpecialAbility.fromJson(<String, dynamic>{
        'name': 'Alt',
        'note': 'Beschreibung',
      });

      expect(sf.beschreibung, 'Beschreibung');
      expect(sf.unbekannteFelder, isEmpty);
    });

    test('Normalisierung der Talentmodifikatoren behält die Felder', () {
      const feld = <String, Object?>{'zukunftsfeld': 1};
      final eintrag = HeroTalentEntry(
        talentModifiers: <HeroTalentModifier>[
          HeroTalentModifier(
            modifier: 1,
            description: '  Haken  ',
            unbekannteFelder: feld,
          ),
        ],
      ).copyWith(talentValue: 3);

      expect(eintrag.talentModifiers.single.description, 'Haken');
      expect(eintrag.talentModifiers.single.unbekannteFelder, feld);
    });
  });

  group('Kampfeinstellungen: Altschlüssel und Normalisierung', () {
    test('schnellladenBogen geht in activeManeuvers auf', () {
      final regeln = CombatSpecialRules.fromJson(<String, dynamic>{
        'schnellladenBogen': true,
      });

      expect(regeln.activeManeuvers, <String>['man_schnellladen_bogen']);
      expect(regeln.unbekannteFelder, isEmpty);
      expect(regeln.toJson().containsKey('schnellladenBogen'), isFalse);
    });

    test('fkMod der manuellen Modifikatoren wird zu atMod', () {
      final mods = CombatManualMods.fromJson(<String, dynamic>{'fkMod': 2});

      expect(mods.atMod, 2);
      expect(mods.unbekannteFelder, isEmpty);
      expect(mods.toJson().containsKey('fkMod'), isFalse);
    });

    test('die Normalisierung der Nebenhand-Auswahl behält die Felder', () {
      const feld = <String, Object?>{'zukunftsfeld': 1};
      const config = CombatConfig(
        weapons: <MainWeaponSlot>[
          MainWeaponSlot(name: 'Säbel'),
          MainWeaponSlot(name: 'Dolch'),
        ],
        offhandAssignment: OffhandAssignment(
          weaponIndex: 7,
          equipmentIndex: 3,
          unbekannteFelder: feld,
        ),
      );

      final geladen = CombatConfig.fromJson(config.toJson());
      final gewaehlt = geladen.copyWith(
        offhandAssignment: geladen.offhandAssignment.copyWith(weaponIndex: 1),
      );
      final gleicheWaffe = gewaehlt.copyWith(selectedWeaponIndex: 1);

      expect(geladen.offhandAssignment.isNone, isTrue);
      expect(geladen.offhandAssignment.unbekannteFelder, feld);
      expect(gewaehlt.offhandAssignment.weaponIndex, 1);
      expect(gewaehlt.offhandAssignment.unbekannteFelder, feld);
      expect(gleicheWaffe.offhandAssignment.isNone, isTrue);
      expect(gleicheWaffe.toJson()['offhandAssignment'], <String, dynamic>{
        'weaponIndex': -1,
        'equipmentIndex': -1,
        ...feld,
      });
    });
  });
}
