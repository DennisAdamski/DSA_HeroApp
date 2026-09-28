import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/inventar_verweise.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/veroeffentlichte_app.dart';

// Verknuepfter Waffeneintrag mit Kennung in der Beschreibung.
HeroInventoryEntry _waffe(
  String sourceRef, {
  String? slotRef,
  String beschreibung = '',
  InventoryItemSource source = InventoryItemSource.waffe,
}) {
  return HeroInventoryEntry(
    gegenstand: 'Dolch',
    source: source,
    sourceRef: sourceRef,
    slotRef: slotRef,
    beschreibung: beschreibung,
  );
}

// Laedt Helden-JSON so, wie Hive und Firestore es tun.
HeroSheet _lade(Map<String, dynamic> json) {
  return HeroSheet.fromJson(
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
  );
}

// Speichert wie `HeroActions.saveHero`: Inventar mit dem Kampf abgleichen.
HeroSheet _gespeichert(HeroSheet held) {
  return held.copyWith(
    inventoryEntries: reconcileInventoryWithCombat(
      held.inventoryEntries,
      held.combatConfig,
    ),
  );
}

// Name und Beschreibung jedes verknuepften Eintrags, in Listenreihenfolge.
List<String> _datenJeSlot(HeroSheet held) {
  return <String>[
    for (final entry in held.inventoryEntries)
      if (entry.sourceRef != null &&
          isCombatLinkedInventorySource(entry.source))
        '${entry.sourceRef} = ${entry.beschreibung}',
  ];
}

void main() {
  late CombatConfig kampf;

  setUp(() {
    // f06: w1/w2 Dolch, w3/w4 Kurzbogen mit je Geschoss p1, a1/a2 Lederzeug.
    kampf = ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung)
        .hero
        .combatConfig;
  });

  group('Lademigration der Verweise', () {
    test('L1: ein Eintrag mit slotRef bleibt unverändert', () {
      final eintraege = <HeroInventoryEntry>[
        _waffe('w:Dolch', slotRef: 'w#w2'),
      ];

      expect(migriereInventarVerweise(eintraege, kampf), same(eintraege));
    });

    test('L2: die Vorabfassung wird zu Namens- und ID-Verweis', () {
      final migriert = migriereInventarVerweise(<HeroInventoryEntry>[
        _waffe('w#w2'),
      ], kampf);

      expect(migriert.single.sourceRef, 'w:Dolch');
      expect(migriert.single.slotRef, 'w#w2');
    });

    test('L3: eine verwaiste Vorabfassung behält ihren Verweis', () {
      final migriert = migriereInventarVerweise(<HeroInventoryEntry>[
        _waffe('w#weg'),
      ], kampf);

      expect(migriert.single.sourceRef, 'w#weg');
      expect(migriert.single.slotRef, 'w#weg');
      final abgeglichen = reconcileInventoryWithCombat(migriert, kampf);
      expect(
        abgeglichen.where((entry) => entry.slotRef == 'w#weg'),
        isEmpty,
        reason: 'Der Abgleich verwirft die Waise.',
      );
    });

    test(
      'L4: Namensverweise gehen an den ersten freien gleichnamigen Slot',
      () {
        final migriert = migriereInventarVerweise(<HeroInventoryEntry>[
          _waffe('w:Dolch', beschreibung: 'erster freier'),
          _waffe('w:Dolch', slotRef: 'w#w1', beschreibung: 'belegt'),
        ], kampf);

        expect(migriert[0].slotRef, 'w#w2');
        expect(migriert[0].sourceRef, 'w:Dolch');
        expect(migriert[1].slotRef, 'w#w1');
      },
    );

    test('L5: ohne freien Slot bleibt der Namensverweis allein', () {
      final migriert = migriereInventarVerweise(<HeroInventoryEntry>[
        _waffe('w:Speer'),
        _waffe('w:Dolch'),
        _waffe('w:Dolch'),
        _waffe('w:Dolch'),
      ], kampf);

      expect(migriert[0].slotRef, isNull);
      expect(migriert.map((entry) => entry.slotRef).skip(1), <String?>[
        'w#w1',
        'w#w2',
        null,
      ]);
    });

    test('L6: manuelle und Beute-Einträge bleiben unberührt', () {
      final eintraege = <HeroInventoryEntry>[
        _waffe('w:Dolch', source: InventoryItemSource.manuell),
        _waffe('w#w1', source: InventoryItemSource.abenteuer),
      ];

      expect(migriereInventarVerweise(eintraege, kampf), same(eintraege));
    });

    test('die Migration ist deterministisch und ein Fixpunkt', () {
      final eintraege = <HeroInventoryEntry>[
        _waffe('w:Dolch'),
        _waffe('w#w1'),
        _waffe('w:Dolch'),
      ];

      final einmal = migriereInventarVerweise(eintraege, kampf);
      final nochmal = migriereInventarVerweise(eintraege, kampf);
      final zweimal = migriereInventarVerweise(einmal, kampf);

      List<Object?> json(List<HeroInventoryEntry> liste) =>
          liste.map((entry) => entry.toJson()).toList();
      expect(json(nochmal), json(einmal));
      expect(zweimal, same(einmal));
      expect(einmal.map((entry) => entry.slotRef), <String?>[
        'w#w2',
        'w#w1',
        null,
      ]);
    });

    test('die Vorabfassung von f06 lädt zum selben Stand wie f06', () {
      final held = ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung).hero;
      final vorab = held.toJson();
      for (final eintrag in (vorab['inventoryEntries'] as List).cast<Map>()) {
        final slotRef = eintrag.remove('slotRef');
        if (slotRef != null) eintrag['sourceRef'] = slotRef;
      }

      expect(heroContentHash(_lade(vorab)), heroContentHash(held));
    });
  });

  group('Mischbetrieb mit der veröffentlichten App', () {
    for (final fixture in Bestandsheld.values) {
      test('${fixture.datei}: sie findet jeden Eintrag über den Namen', () {
        final held = _gespeichert(ladeBestandsheld(fixture).hero);
        final alt = wieVeroeffentlichteApp(held.toJson());

        final zuordnung = zuordnungWieVeroeffentlichteApp(alt);

        expect(zuordnung, isNot(contains(null)));
        expect(zuordnung.length, _datenJeSlot(held).length);
        final sortiert = List<int?>.of(zuordnung)..sort();
        expect(zuordnung, sortiert, reason: 'Reihenfolge wie im Inventar');
      });
    }

    test('nach Entfernen, Umbenennen und Hinzufügen behält jeder Slot seine '
        'Daten, auch über die veröffentlichte App hinweg', () {
      final held = ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung).hero;
      final waffen = List<MainWeaponSlot>.of(held.combatConfig.weaponSlots)
        ..removeAt(0);
      waffen[0] = waffen[0].copyWith(name: 'Parierdolch');
      waffen.add(const MainWeaponSlot(id: 'uuid-speer', name: 'Speer'));
      // Wie nach dem Speichern: [w2 Parierdolch, w3, w4, uuid-speer].
      final neu = _gespeichert(
        held.copyWith(
          combatConfig: held.combatConfig.copyWith(
            weapons: waffen,
            selectedWeaponIndex: 0,
          ),
        ),
      );
      final alt = wieVeroeffentlichteApp(neu.toJson());

      expect(zuordnungWieVeroeffentlichteApp(alt), isNot(contains(null)));
      final zurueck = _lade(alt);

      // IDs werden neu vergeben ([w1 .. w4]), die Daten bleiben beim Slot.
      expect(zurueck.combatConfig.weaponSlots.map((slot) => slot.id), <String>[
        'w1',
        'w2',
        'w3',
        'w4',
      ]);
      expect(_datenJeSlot(zurueck), _datenJeSlot(neu));
      final parierdolch = zurueck.inventoryEntries.singleWhere(
        (entry) => entry.gegenstand == 'Parierdolch',
      );
      expect(parierdolch.slotRef, 'w#w1');
      expect(parierdolch.beschreibung, 'Beutestück');
    });

    test('eine Änderung der veröffentlichten App am zweiten Dolch landet '
        'beim zweiten Dolch', () {
      final held = _gespeichert(
        ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung).hero,
      );
      final alt = wieVeroeffentlichteApp(held.toJson());
      // Zweiter erwarteter Slot ist der zweite Dolch.
      final index = zuordnungWieVeroeffentlichteApp(alt)[1]!;
      ((alt['inventoryEntries'] as List)[index] as Map)['wert'] = '99';

      final zurueck = _lade(alt);

      final zweiterDolch = zurueck.inventoryEntries.singleWhere(
        (entry) => entry.slotRef == 'w#w2',
      );
      expect(zweiterDolch.wert, '99');
      expect(
        heroContentHash(_lade(zurueck.toJson())),
        heroContentHash(zurueck),
      );
    });

    test('f06 durch die veröffentlichte App und zurück bleibt gleich', () {
      final held = ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung).hero;

      final zurueck = _lade(wieVeroeffentlichteApp(held.toJson()));

      expect(heroContentHash(zurueck), heroContentHash(held));
    });
  });
}
