import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_type.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

import '../test_support/hero_fixtures.dart';

/// Formatwaechter: Inhalts-Hashes der geladenen Bestandshelden.
///
/// Aendert sich einer dieser Werte, erzeugt die App fuer **jeden** gleich
/// gespeicherten Bestandshelden einen neuen Hash, und der Konto-Sync meldet
/// beim naechsten Speichern Konflikte (siehe CLAUDE.md zu `geburtsdatum`).
/// Nur zusammen mit einer bewusst eingefuehrten Migration anpassen.
const Map<Bestandsheld, String> _heldenHashes = <Bestandsheld, String>{
  Bestandsheld.kriegerNormal: 'eXqxBlphUDJS5Yd421Mv43RnA4LLdAd7_nVF-S1SDqI=',
  Bestandsheld.geodeMagisch: 'ps_Vd_oV2ug2lXeY_wH0snYZWnukcX7WTny7NvLUS8Y=',
  Bestandsheld.geweihterKarmal: 'vLCzKgAFwmZSwLvYNI5LxIjCbottabPf8Noxw6ydTvE=',
  Bestandsheld.episch: 'Ke5FIb-VWW4jc5_1Ak9u-yk9DRfaIKqxC046mXczKD8=',
  // f05 und f07 laden seit der Behebung von Befund ARCH-07-B1 ohne Kopie der
  // Inspector-Werte in `statModifiers`.
  Bestandsheld.freitextMerkmale: 'Jnwfp6I0Esdy3uCTb7QzmptyqEVPVhGvnPy75vb9XcU=',
  Bestandsheld.gleichnamigeAusruestung:
      'KUmCzbjUsamNmpnLs7OMe6Vk-qPHvlVRKIYk61o_DRg=',
  Bestandsheld.legacySchema1: 'ZkQmLrSS6y7Vl6txFL0F_0i4smrZilDLbscfa2HL3eM=',
  Bestandsheld.steigerungshistorie:
      'hnMwYN9ZXVqwdsDvsjKeSZc3WnCNKaGQ8pXMm1Nns7E=',
};

/// Wie [_heldenHashes], fuer den Laufzeitzustand.
const Map<Bestandsheld, String> _zustandsHashes = <Bestandsheld, String>{
  Bestandsheld.kriegerNormal: '9MJT_Fbe4pjWHnkrzQQiNnTii7BFNbFbS8Ny8AGOO-Y=',
  Bestandsheld.geodeMagisch: 'mpSNmnIi1BIv_CPct5DVPlXswwTBUlPacnzGClX9Aq0=',
  Bestandsheld.geweihterKarmal: 'w7ywdlw39gK0lpwXSjpxJQ3h0xYmHVLpYAxeda0U5zs=',
  Bestandsheld.episch: '_ggtDVeoQrQxEKt7lBzLFD8fMCsUTzvaLFlYbblszG0=',
  Bestandsheld.freitextMerkmale: 'n8MYpP6owr0GHvWjIDPcngQdQLvl1Nn19eHGSwXBrBk=',
  Bestandsheld.gleichnamigeAusruestung:
      'jSHr3ffvCMWK2uuHMe5rHrMX79Mu-c7M38qbcpX4oao=',
  Bestandsheld.legacySchema1: 'bFjrodz1bjEVi_oDMUKMBygjlZcSoWag99kpcyNuwf8=',
  Bestandsheld.steigerungshistorie:
      '-28KqI3XR9AU_NmwHCm2BpNgH4qYPj0C5Py8kuHSbGA=',
};

void main() {
  group('Bestandshelden laden', () {
    for (final held in Bestandsheld.values) {
      test(
        '${held.datei}: Held und Zustand sind nach einmaligem Laden stabil',
        () {
          final bundle = ladeBestandsheld(held);
          final einmal = bundle.hero.toJson();
          final zweimal = HeroSheet.fromJson(einmal).toJson();
          expect(jsonUnterschiede(einmal, zweimal), isEmpty);

          final zustandEinmal = bundle.state.toJson();
          final zustandZweimal = HeroState.fromJson(zustandEinmal).toJson();
          expect(jsonUnterschiede(zustandEinmal, zustandZweimal), isEmpty);

          expect(
            heroContentHash(HeroSheet.fromJson(einmal)),
            heroContentHash(bundle.hero),
          );
          expect(
            heroStateContentHash(HeroState.fromJson(zustandEinmal)),
            heroStateContentHash(bundle.state),
          );
        },
      );

      test('${held.datei}: Inhalts-Hashes bleiben unverändert', () {
        final bundle = ladeBestandsheld(held);
        expect(heroContentHash(bundle.hero), _heldenHashes[held]);
        expect(heroStateContentHash(bundle.state), _zustandsHashes[held]);
      });
    }

    for (final held in Bestandsheld.values.where((h) => h.istAktuellesFormat)) {
      test(
        '${held.datei}: aktuelles Format übersteht das Laden unverändert',
        () {
          final roh = ladeBestandsheldJson(held);
          final bundle = ladeBestandsheld(held);

          expectNurGeaendert(
            (roh['hero'] as Map).cast<String, dynamic>(),
            bundle.hero.toJson(),
            const <String>{},
          );
          expectNurGeaendert(
            (roh['state'] as Map).cast<String, dynamic>(),
            bundle.state.toJson(),
            const <String>{},
          );
        },
      );
    }
  });

  group('Inspector-Werte zählen einfach (Befund ARCH-07-B1)', () {
    // Baut einen Helden-JSON mit Inspector-Werten und benannten Einträgen.
    HeroSheet lade({
      required Map<String, int> inspector,
      required Map<String, List<Map<String, Object>>> benannt,
    }) {
      final roh = ladeBestandsheldJson(Bestandsheld.freitextMerkmale);
      final heldJson = (roh['hero'] as Map).cast<String, dynamic>()
        ..['persistentMods'] = inspector
        ..['statModifiers'] = benannt;
      return HeroSheet.fromJson(heldJson);
    }

    test('f05 lädt den Inspector-Wert ohne Kopie', () {
      final gespeichert = ladeBestandsheldJson(Bestandsheld.freitextMerkmale);
      final heldJson = (gespeichert['hero'] as Map).cast<String, dynamic>();
      expect(heldJson['statModifiers'], isEmpty);
      expect((heldJson['persistentMods'] as Map)['iniBase'], 1);

      final geladen = ladeBestandsheld(Bestandsheld.freitextMerkmale).hero;

      expect(geladen.persistentMods.iniBase, 1);
      expect(geladen.statModifiers, isEmpty);
    });

    test('eine gespeicherte Kopie „Manuell“ mit gleichem Wert entfällt', () {
      final held = lade(
        inspector: const <String, int>{'iniBase': 1, 'lep': 2},
        benannt: const <String, List<Map<String, Object>>>{
          'iniBase': <Map<String, Object>>[
            <String, Object>{'modifier': 1, 'description': 'Manuell'},
            <String, Object>{'modifier': 2, 'description': 'Segen'},
          ],
          'lep': <Map<String, Object>>[
            <String, Object>{'modifier': 2, 'description': 'Manuell'},
          ],
        },
      );

      expect(held.persistentMods.iniBase, 1);
      expect(held.statModifiers['iniBase']?.single.description, 'Segen');
      expect(held.statModifiers.containsKey('lep'), isFalse);
      expect(
        heroContentHash(HeroSheet.fromJson(held.toJson())),
        heroContentHash(held),
        reason: 'die Reparatur ist nach einmaligem Laden stabil',
      );
    });

    test('abweichende oder eigene Einträge bleiben erhalten', () {
      final held = lade(
        inspector: const <String, int>{'iniBase': 2, 'at': 0},
        benannt: const <String, List<Map<String, Object>>>{
          // Seit der Kopie im Inspector nachgesteuert: bleibt stehen.
          'iniBase': <Map<String, Object>>[
            <String, Object>{'modifier': 1, 'description': 'Manuell'},
          ],
          // Kein Inspector-Wert zu diesem Feld: keine Kopie.
          'at': <Map<String, Object>>[
            <String, Object>{'modifier': 1, 'description': 'Manuell'},
          ],
          'mr': <Map<String, Object>>[
            <String, Object>{'modifier': 1, 'description': 'Amulett'},
          ],
        },
      );

      expect(held.statModifiers['iniBase']?.single.modifier, 1);
      expect(held.statModifiers['at']?.single.modifier, 1);
      expect(held.statModifiers['mr']?.single.description, 'Amulett');
    });
  });

  group('Altstand f07 (Transferversion 1, ohne Schemaversion)', () {
    late HeroSheet held;
    late HeroState zustand;

    setUp(() {
      final bundle = ladeBestandsheld(Bestandsheld.legacySchema1);
      held = bundle.hero;
      zustand = bundle.state;
    });

    test('Eigenschaften werden Start- und Rohstartwerte', () {
      expect(held.schemaVersion, 1);
      expect(held.level, 1);
      expect(held.attributes.kk, 12);
      expect(held.rawStartAttributes.toJson(), held.attributes.toJson());
      expect(held.startAttributes.toJson(), held.attributes.toJson());
    });

    test('alte persistentMods bleiben die einzige Quelle', () {
      expect(held.persistentMods.lep, 2);
      expect(held.persistentMods.iniBase, 1);
      expect(held.statModifiers, isEmpty);
    });

    test('Textfelder werden in strukturierte Einträge übersetzt', () {
      expect(held.talentSpecialAbilities.map((entry) => entry.name), <String>[
        'Kulturkunde (Svellttal)',
        'Ortskenntnis (Lowangen)',
      ]);
      expect(held.talents['tal_schwerter']?.combatSpecializations, <String>[
        'Langschwert',
      ]);
      final trank = held.inventoryEntries.first;
      expect(trank.isMagisch, isTrue);
      expect(trank.magischDescription, 'Wirkt 1W6 LeP');
    });

    test('alte Kampfkonfiguration wird auf Slots abgebildet', () {
      final kampf = held.combatConfig;
      expect(kampf.weaponSlots.map((slot) => slot.name), <String>[
        'Langschwert',
      ]);
      expect(kampf.offhandEquipment.single.name, 'Holzschild');
      expect(kampf.offhandEquipment.single.type, OffhandEquipmentType.shield);
      expect(kampf.offhandAssignment.equipmentIndex, 0);
      expect(kampf.specialRules.kampfreflexe, isTrue);
      expect(
        kampf.specialRules.activeManeuvers,
        contains('man_schnellladen_bogen'),
      );
    });

    test('Altbild wird Galerieeintrag mit stabiler ID', () {
      final bild = held.appearance.avatarGallery.single;
      expect(bild.id, 'bestand-f07_legacy');
      expect(bild.fileName, 'bestand-f07.png');
      expect(held.appearance.aktivesBild?.fileName, 'bestand-f07.png');
    });

    test('leere Historie und fehlende Zustandsversion', () {
      expect(held.toJson().containsKey('advancementHistory'), isFalse);
      expect(zustand.schemaVersion, 6);
      expect(zustand.currentLep, 25);
    });
  });

  group('Grenzen des heutigen Formats', () {
    test('Befund ARCH-07-B5: unbekannte Steigerungsart macht den Helden '
        'unlesbar', () {
      final roh = ladeBestandsheldRoh(unbekannteSteigerungsartDatei);
      expect(
        () => const HeroTransferCodec().decode(roh),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Befund ARCH-07-B6: unbekannte Felder gehen beim Laden verloren', () {
      final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal);
      final heldJson = (roh['hero'] as Map).cast<String, dynamic>()
        ..['zukunftsfeld'] = <String, dynamic>{'stufe': 2};

      final geladen = HeroSheet.fromJson(heldJson).toJson();

      expect(geladen.containsKey('zukunftsfeld'), isFalse);
    });

    test('Transferversion 2 wird weiterhin angenommen', () {
      final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal)
        ..['transferSchemaVersion'] = 2;

      final bundle = const HeroTransferCodec().decode(jsonEncode(roh));

      expect(bundle.hero.id, 'bestand-f01');
    });
  });
}
