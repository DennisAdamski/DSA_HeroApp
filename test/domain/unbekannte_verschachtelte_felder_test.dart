import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';

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
