import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_type.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/inventar_verweise.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

import '../test_support/hero_fixtures.dart';

/// Formatwaechter: Inhalts-Hashes der geladenen Bestandshelden nach Migration.
///
/// Aendert sich einer dieser Werte, erzeugt die App fuer **jeden** gleich
/// gespeicherten Bestandshelden einen neuen Hash, und der Konto-Sync meldet
/// beim naechsten Speichern Konflikte (siehe CLAUDE.md zu `geburtsdatum`).
/// Nur zusammen mit einer bewusst eingefuehrten Migration anpassen.
///
/// f01, f02, f04 und f06 haben verknuepfte Inventareintraege. Seit dem
/// altversionsvertraeglichen Verweisformat behalten sie beim Laden ihren
/// Namensverweis in `sourceRef` und bekommen `slotRef` dazu.
const Map<Bestandsheld, String> _heldenHashes = <Bestandsheld, String>{
  Bestandsheld.kriegerNormal: 'nUrDqy2kw2B08LU66tMD6ITlLy9PNzk04JC1uyk8dac=',
  Bestandsheld.geodeMagisch: 'aCn3WMhvMh96_iurZS7Ui-2QacmAQ-38Ctz1g1w8FRc=',
  Bestandsheld.geweihterKarmal: 'vLCzKgAFwmZSwLvYNI5LxIjCbottabPf8Noxw6ydTvE=',
  Bestandsheld.episch: '0ThP26-BCDnT9rH5Az_WTYEE7aOq_XfkCmPPwDZ0TE8=',
  // f05 und f07 laden seit der Behebung von Befund ARCH-07-B1 ohne Kopie der
  // Inspector-Werte in `statModifiers`.
  Bestandsheld.freitextMerkmale: 'Jnwfp6I0Esdy3uCTb7QzmptyqEVPVhGvnPy75vb9XcU=',
  Bestandsheld.gleichnamigeAusruestung:
      'vrgtUzPhCxYNgYn8ZMu4rXXA1gHXhTa9DH-L83YlEWU=',
  Bestandsheld.legacySchema1: 'XZX57WQQ4-gMfMGY7S7YdFeKNHVKXxbXYznvG1VMrcU=',
  Bestandsheld.steigerungshistorie:
      'hnMwYN9ZXVqwdsDvsjKeSZc3WnCNKaGQ8pXMm1Nns7E=',
  Bestandsheld.unbekannteSteigerungsart:
      'OEpxoV0GgDW13q6GaptyPTDx7Tpou3GPtLmwynfwoIc=',
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
  Bestandsheld.unbekannteSteigerungsart:
      '-28KqI3XR9AU_NmwHCm2BpNgH4qYPj0C5Py8kuHSbGA=',
};

void main() {
  test(
    'Namensmigration lässt manuelle Einträge mit ähnlichem Ref unberührt',
    () {
      final kampf = ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung)
          .hero
          .combatConfig;
      const manuell = HeroInventoryEntry(
        source: InventoryItemSource.manuell,
        sourceRef: 'w:Dolch',
      );
      const verknuepft = HeroInventoryEntry(
        source: InventoryItemSource.waffe,
        sourceRef: 'w:Dolch',
      );
      const fremdeQuelle = HeroInventoryEntry(
        source: InventoryItemSource.ruestung,
        sourceRef: 'w:Dolch',
      );

      final migriert = migriereInventarVerweise(<HeroInventoryEntry>[
        manuell,
        fremdeQuelle,
        verknuepft,
      ], kampf);

      expect(migriert[0].sourceRef, 'w:Dolch');
      expect(migriert[0].slotRef, isNull);
      expect(migriert[1].sourceRef, 'w:Dolch');
      expect(migriert[1].slotRef, isNull);
      // Der Namensverweis bleibt, damit die veroeffentlichte App den Eintrag
      // weiter zuordnen kann; die ID kommt als slotRef dazu.
      expect(migriert[2].sourceRef, 'w:Dolch');
      expect(migriert[2].slotRef, 'w#w1');
    },
  );

  test('Namensmigration reserviert per ID verknüpfte Slots, auch aus der '
      'Vorabfassung', () {
    final kampf = ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung)
        .hero
        .combatConfig;
    const erster = HeroInventoryEntry(
      source: InventoryItemSource.waffe,
      sourceRef: 'w#w1',
      beschreibung: 'Erbstück mit Runen',
    );
    const zweiter = HeroInventoryEntry(
      source: InventoryItemSource.waffe,
      sourceRef: 'w:Dolch',
      beschreibung: 'Beutestück',
    );

    final migriert = migriereInventarVerweise(<HeroInventoryEntry>[
      erster,
      zweiter,
    ], kampf);

    // Die Vorabfassung trug die ID in sourceRef; sie wandert nach slotRef.
    expect(migriert[0].sourceRef, 'w:Dolch');
    expect(migriert[0].slotRef, 'w#w1');
    expect(migriert[1].sourceRef, 'w:Dolch');
    expect(migriert[1].slotRef, 'w#w2');
    expect(migriert[1].beschreibung, 'Beutestück');
  });

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
      test('${held.datei}: Laden ändert nur Ausrüstungsverweise', () {
        final roh = ladeBestandsheldJson(held);
        final bundle = ladeBestandsheld(held);

        final vorher = (roh['hero'] as Map).cast<String, dynamic>();
        final unterschiede = jsonUnterschiede(vorher, bundle.hero.toJson());
        final erlaubteAenderung = RegExp(
          r'^combatConfig/(mainWeapon|weapons/\d+|'
          r'weapons/\d+/rangedProfile/projectiles/\d+|'
          r'armor/pieces/\d+|offhandEquipment/\d+)/id$'
          r'|^inventoryEntries/\d+/slotRef$',
        );
        expect(
          unterschiede.where((pfad) => !erlaubteAenderung.hasMatch(pfad)),
          isEmpty,
          reason:
              'Die ID-Migration darf nur IDs ergänzen; den Namensverweis in '
              'sourceRef braucht die veröffentlichte App.',
        );
        expectNurGeaendert(
          (roh['state'] as Map).cast<String, dynamic>(),
          bundle.state.toJson(),
          const <String>{},
        );
      });
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

  group('Daten neuerer App-Versionen bleiben erhalten', () {
    test('ein Verlaufseintrag unbekannter Art bleibt an seiner Stelle '
        '(Befund ARCH-07-B5)', () {
      final roh = ladeBestandsheldJson(Bestandsheld.unbekannteSteigerungsart);
      final rohVerlauf = ((roh['hero'] as Map)['advancementHistory'] as List);

      final held = ladeBestandsheld(Bestandsheld.unbekannteSteigerungsart).hero;

      expect(held.advancementHistory, hasLength(rohVerlauf.length - 1));
      expect(held.unbekannteVerlaufseintraege.single.json['kind'], 'companion');
      expect(
        jsonUnterschiede(rohVerlauf, held.toJson()['advancementHistory']),
        isEmpty,
      );
    });

    test('neue Einträge folgen hinter dem unbekannten', () {
      final held = ladeBestandsheld(Bestandsheld.unbekannteSteigerungsart).hero;
      final neu = HeroAdvancementEntry(
        id: 'neu',
        sessionId: 'runde-2',
        createdAt: DateTime.utc(2026, 9, 27),
        kind: AdvancementKind.attribute,
        targetId: 'kl',
        label: 'Klugheit',
        fromValue: 12,
        toValue: 13,
        apCost: 150,
      );

      final verlauf =
          held
                  .copyWith(
                    advancementHistory: <HeroAdvancementEntry>[
                      ...held.advancementHistory,
                      neu,
                    ],
                  )
                  .toJson()['advancementHistory']
              as List;

      expect(
        verlauf.map((eintrag) => (eintrag as Map)['kind']).toList(),
        <String>[
          'attribute',
          'talent',
          'talent',
          'maneuver',
          'combatAbility',
          'companion',
          'attribute',
        ],
      );
    });

    test('unbekannte Felder von Held und Zustand bleiben erhalten '
        '(Befund ARCH-07-B6)', () {
      final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal);
      final heldJson = (roh['hero'] as Map).cast<String, dynamic>()
        ..['zukunftsfeld'] = <String, dynamic>{
          'stufe': 2,
          'liste': <int>[1, 2],
        };
      final zustandJson = (roh['state'] as Map).cast<String, dynamic>()
        ..['zukunftszustand'] = 'wach';

      final held = HeroSheet.fromJson(heldJson);
      final zustand = HeroState.fromJson(zustandJson);

      expect(held.toJson()['zukunftsfeld'], <String, dynamic>{
        'stufe': 2,
        'liste': <int>[1, 2],
      });
      expect(zustand.toJson()['zukunftszustand'], 'wach');
      expect(
        held.copyWith(name: 'Umbenannt').toJson()['zukunftsfeld'],
        isNotNull,
        reason: 'Änderungen am Helden tragen das Feld weiter',
      );
      expect(
        heroContentHash(HeroSheet.fromJson(held.toJson())),
        heroContentHash(held),
      );
    });

    test('jeder geschriebene Schlüssel gilt als bekannt', () {
      // Alle nur bedingt geschriebenen Felder belegt: fehlte einer im
      // bekannten Satz, kaeme er beim Zuruecksetzen als „unbekannt“ mit
      // altem Wert zurueck.
      final basis = ladeBestandsheld(Bestandsheld.steigerungshistorie).hero;
      final voll = basis.copyWith(
        showInapplicableSpecialAbilities: true,
        epicActivationPolicy: 'standard',
        appearance: basis.appearance.copyWith(
          avatarSnapshot: () => AvatarSnapshot(erstelltAm: '2026-09-27'),
        ),
      );
      final geschrieben = voll.toJson().keys.toSet();

      expect(geschrieben.difference(HeroSheet.jsonSchluessel), isEmpty);
      expect(
        ladeBestandsheld(Bestandsheld.kriegerNormal).state
            .toJson()
            .keys
            .toSet()
            .difference(HeroState.jsonSchluessel),
        isEmpty,
      );
      expect(voll.unbekannteFelder, isEmpty);
    });

    test('Transferversion 2 wird weiterhin angenommen', () {
      final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal)
        ..['transferSchemaVersion'] = 2;

      final bundle = const HeroTransferCodec().decode(jsonEncode(roh));

      expect(bundle.hero.id, 'bestand-f01');
    });
  });
}
