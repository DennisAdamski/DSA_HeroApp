import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/weapon_def.dart';
import 'package:dsa_heldenverwaltung/domain/abgelegter_kampfgegenstand.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/zukunftsfelder.dart';

/// Ein Ausruestungsmodell im Tabellentest: voll belegte Instanz, Laden und
/// eine Bearbeitung ueber `copyWith`.
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

  /// `fromJson(...).copyWith(<bekanntes Feld>).toJson()`.
  final Map<String, dynamic> Function(Map<String, dynamic>) bearbeite;

  /// `fromJson(...).unbekannteFelder`.
  final Map<String, Object?> Function(Map<String, dynamic>) unbekannt;
}

const _zukunft = <String, dynamic>{
  'stufe': 2,
  'liste': <Object?>[1, 'zwei', null],
};

final _modelle = <_Modell>[
  _Modell(
    'CombatConfig',
    schluessel: CombatConfig.jsonSchluessel,
    voll: () => const CombatConfig(
      weapons: <MainWeaponSlot>[MainWeaponSlot(id: 'w1', name: 'Säbel')],
    ).toJson(),
    lade: (json) => CombatConfig.fromJson(json).toJson(),
    bearbeite: (json) =>
        CombatConfig.fromJson(json).copyWith(selectedWeaponIndex: 0).toJson(),
    unbekannt: (json) => CombatConfig.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'MainWeaponSlot',
    schluessel: MainWeaponSlot.jsonSchluessel,
    voll: () => const MainWeaponSlot(
      id: 'w1',
      inventarInstanzId: 'i1',
      name: 'Säbel',
    ).toJson(),
    lade: (json) => MainWeaponSlot.fromJson(json).toJson(),
    bearbeite: (json) =>
        MainWeaponSlot.fromJson(json).copyWith(name: 'Neu').toJson(),
    unbekannt: (json) => MainWeaponSlot.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'RangedWeaponProfile',
    schluessel: RangedWeaponProfile.jsonSchluessel,
    voll: () => const RangedWeaponProfile().toJson(),
    lade: (json) => RangedWeaponProfile.fromJson(json).toJson(),
    bearbeite: (json) =>
        RangedWeaponProfile.fromJson(json).copyWith(reloadTime: 3).toJson(),
    unbekannt: (json) => RangedWeaponProfile.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'RangedProjectile',
    schluessel: RangedProjectile.jsonSchluessel,
    voll: () => const RangedProjectile(
      id: 'p1',
      inventarInstanzId: 'i2',
      name: 'Pfeil',
    ).toJson(),
    lade: (json) => RangedProjectile.fromJson(json).toJson(),
    bearbeite: (json) =>
        RangedProjectile.fromJson(json).copyWith(count: 7).toJson(),
    unbekannt: (json) => RangedProjectile.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'RangedDistanceBand',
    schluessel: RangedDistanceBand.jsonSchluessel,
    voll: () => const RangedDistanceBand(label: 'Nah').toJson(),
    lade: (json) => RangedDistanceBand.fromJson(json).toJson(),
    bearbeite: (json) =>
        RangedDistanceBand.fromJson(json).copyWith(tpMod: 1).toJson(),
    unbekannt: (json) => RangedDistanceBand.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'ArmorConfig',
    schluessel: ArmorConfig.jsonSchluessel,
    voll: () => const ArmorConfig().toJson(),
    lade: (json) => ArmorConfig.fromJson(json).toJson(),
    bearbeite: (json) =>
        ArmorConfig.fromJson(json)
            .copyWith(globalArmorTrainingLevel: 2)
            .toJson(),
    unbekannt: (json) => ArmorConfig.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'ArmorPiece',
    schluessel: ArmorPiece.jsonSchluessel,
    voll: () => const ArmorPiece(
      id: 'a1',
      inventarInstanzId: 'i3',
      name: 'Helm',
    ).toJson(),
    lade: (json) => ArmorPiece.fromJson(json).toJson(),
    bearbeite: (json) => ArmorPiece.fromJson(json).copyWith(rs: 3).toJson(),
    unbekannt: (json) => ArmorPiece.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'OffhandEquipmentEntry',
    schluessel: OffhandEquipmentEntry.jsonSchluessel,
    voll: () => const OffhandEquipmentEntry(
      id: 'oh1',
      inventarInstanzId: 'i4',
      name: 'Schild',
    ).toJson(),
    lade: (json) => OffhandEquipmentEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        OffhandEquipmentEntry.fromJson(json).copyWith(paMod: 2).toJson(),
    unbekannt: (json) => OffhandEquipmentEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'HeroInventoryEntry',
    schluessel: HeroInventoryEntry.jsonSchluessel,
    voll: () => const HeroInventoryEntry(
      gegenstand: 'Säbel',
      source: InventoryItemSource.waffe,
      sourceRef: 'w#w1',
      traegerTyp: InventoryTraeger.begleiter,
      traegerId: 'b1',
      instanzId: 'i1',
      menge: 1,
      abgelegt: AbgelegterKampfgegenstand(waffe: MainWeaponSlot(name: 'Säbel')),
    ).toJson(),
    lade: (json) => HeroInventoryEntry.fromJson(json).toJson(),
    bearbeite: (json) =>
        HeroInventoryEntry.fromJson(json).copyWith(wert: '12').toJson(),
    unbekannt: (json) => HeroInventoryEntry.fromJson(json).unbekannteFelder,
  ),
  _Modell(
    'InventoryItemModifier',
    schluessel: InventoryItemModifier.jsonSchluessel,
    voll: () => const InventoryItemModifier(
      kind: InventoryModifierKind.stat,
      targetId: 'gs',
      wert: 1,
    ).toJson(),
    lade: (json) => InventoryItemModifier.fromJson(json).toJson(),
    bearbeite: (json) =>
        InventoryItemModifier.fromJson(json).copyWith(wert: 2).toJson(),
    unbekannt: (json) => InventoryItemModifier.fromJson(json).unbekannteFelder,
  ),
];

// Voll belegtes JSON eines Modells samt Zukunftsfeld, frisch kopiert.
Map<String, dynamic> _mitZukunft(_Modell modell) {
  final json = jsonDecode(jsonEncode(modell.voll())) as Map<String, dynamic>;
  json['zukunftsfeld'] = jsonDecode(jsonEncode(_zukunft));
  return json;
}

void main() {
  group('Ausrüstungsmodelle bewahren unbekannte Felder', () {
    for (final modell in _modelle) {
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
    }

    test('ein bekanntes Feld gleichen Namens wird nie überschrieben', () {
      final json = const MainWeaponSlot(name: 'Säbel').toJson();

      final slot = MainWeaponSlot.fromJson(json);

      expect(
        slot.copyWith(unbekannteFelder: {'name': 'Alt'}).toJson()['name'],
        'Säbel',
      );
    });
  });

  group('Altschlüssel gehen beim Laden auf und kommen nicht zurück', () {
    test('wmFk wird zu wmAt', () {
      final slot = MainWeaponSlot.fromJson(<String, dynamic>{
        'name': 'Bogen',
        'combatType': 'ranged',
        'wmFk': 2,
      });

      expect(slot.wmAt, 2);
      expect(slot.unbekannteFelder, isEmpty);
      expect(slot.toJson().containsKey('wmFk'), isFalse);
    });

    test('fkMod wird zu atMod', () {
      final geschoss = RangedProjectile.fromJson(<String, dynamic>{
        'name': 'Pfeil',
        'fkMod': 1,
      });

      expect(geschoss.atMod, 1);
      expect(geschoss.unbekannteFelder, isEmpty);
      expect(geschoss.toJson().containsKey('fkMod'), isFalse);
    });

    test('ein gelöschter migrierter Schild kommt nicht wieder (f07)', () {
      final held = ladeBestandsheld(Bestandsheld.legacySchema1).hero;
      expect(held.combatConfig.offhandEquipment, isNotEmpty);
      expect(held.combatConfig.unbekannteFelder, isEmpty);

      final ohneSchild = held.copyWith(
        combatConfig: held.combatConfig.copyWith(
          offhandEquipment: const <OffhandEquipmentEntry>[],
        ),
      );
      final neuGeladen = HeroSheet.fromJson(
        jsonDecode(jsonEncode(ohneSchild.toJson())) as Map<String, dynamic>,
      );

      expect(ohneSchild.toJson()['combatConfig'], isNot(contains('offhand')));
      expect(neuGeladen.combatConfig.offhandEquipment, isEmpty);
    });
  });

  test('ArmorPiece: unbekannte Felder zählen zur Gleichheit', () {
    const basis = ArmorPiece(id: 'a1', name: 'Helm');
    final mitFeld = basis.copyWith(
      unbekannteFelder: <String, Object?>{
        'a': <String, Object?>{'x': 1, 'y': 2},
      },
    );
    final gleich = basis.copyWith(
      unbekannteFelder: <String, Object?>{
        'a': <String, Object?>{'y': 2, 'x': 1},
      },
    );

    expect(mitFeld, isNot(basis));
    expect(mitFeld, gleich);
    expect(mitFeld.hashCode, gleich.hashCode);
  });

  test('stabile IDs und Normalisierung behalten die Felder', () {
    const feld = <String, Object?>{'zukunftsfeld': 1};
    const config = CombatConfig(
      weapons: <MainWeaponSlot>[
        MainWeaponSlot(
          name: 'Bogen',
          combatType: WeaponCombatType.ranged,
          unbekannteFelder: feld,
          rangedProfile: RangedWeaponProfile(
            unbekannteFelder: feld,
            projectiles: <RangedProjectile>[
              RangedProjectile(
                name: ' Pfeil ',
                count: -3,
                unbekannteFelder: feld,
              ),
            ],
          ),
        ),
      ],
      armor: ArmorConfig(
        unbekannteFelder: feld,
        pieces: <ArmorPiece>[ArmorPiece(name: 'Helm', unbekannteFelder: feld)],
      ),
      offhandEquipment: <OffhandEquipmentEntry>[
        OffhandEquipmentEntry(name: 'Schild', unbekannteFelder: feld),
      ],
      unbekannteFelder: feld,
    );

    var zaehler = 0;
    final mitIds = config.withStableIds(neueId: () => 'id${zaehler++}');
    final waffe = mitIds.weaponSlots.single;
    final profil = waffe.rangedProfile.copyWith(reloadTime: 1);

    expect(waffe.id, isNotEmpty);
    expect(waffe.unbekannteFelder, feld);
    expect(profil.unbekannteFelder, feld);
    expect(profil.projectiles.single.name, 'Pfeil');
    expect(profil.projectiles.single.unbekannteFelder, feld);
    expect(mitIds.armor.unbekannteFelder, feld);
    expect(mitIds.armor.pieces.single.unbekannteFelder, feld);
    expect(mitIds.offhandEquipment.single.unbekannteFelder, feld);
    expect(mitIds.unbekannteFelder, feld);
  });

  test('Katalogschlüssel gelangen nicht in die Heldendaten', () {
    final waffe = WeaponDef.fromJson(<String, dynamic>{
      'id': 'wpn_bogen',
      'name': 'Bogen',
      'type': 'Fernkampf',
      'rangedDistanceBands': <Object?>[
        <String, dynamic>{'label': 'Nah', 'tpMod': 1, 'quelle': 'Katalog'},
      ],
      'rangedProjectiles': <Object?>[
        <String, dynamic>{'name': 'Pfeil', 'quelle': 'Katalog'},
      ],
    });

    expect(waffe.rangedDistanceBands.single.unbekannteFelder, isEmpty);
    expect(waffe.rangedProjectiles.single.unbekannteFelder, isEmpty);
  });

  group('Held mit Zukunftsfeldern in der Ausrüstung (f01)', () {
    late Zukunftsheld zukunft;

    setUp(() {
      final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal);
      zukunft = mitZukunftsfeldern(
        (roh['hero'] as Map).cast<String, dynamic>(),
      );
    });

    test('Laden ändert genau die Zukunftsfelder, nichts sonst', () {
      final basis = HeroSheet.fromJson(zukunft.basis).toJson();
      final geladen = HeroSheet.fromJson(zukunft.json).toJson();

      expect(jsonUnterschiede(basis, geladen).toSet(), zukunft.pfade.toSet());
      for (final pfad in zukunft.pfade) {
        expect(wertAn(geladen, pfad), wertAn(zukunft.json, pfad), reason: pfad);
      }
    });

    test('erneutes Laden ist ein Fixpunkt mit stabilem Hash', () {
      final einmal = HeroSheet.fromJson(zukunft.json);
      final zweimal = HeroSheet.fromJson(
        jsonDecode(jsonEncode(einmal.toJson())) as Map<String, dynamic>,
      );

      expect(jsonUnterschiede(einmal.toJson(), zweimal.toJson()), isEmpty);
      expect(heroContentHash(zweimal), heroContentHash(einmal));
    });
  });
}
