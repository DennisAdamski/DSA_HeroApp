import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';

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

void main() {
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
