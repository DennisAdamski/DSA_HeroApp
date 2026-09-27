import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';

import '../test_support/hero_fixtures.dart';

// Beschreibung je Eintrag, in Listenreihenfolge.
List<String> _beschreibungen(List<HeroInventoryEntry> eintraege) {
  return eintraege.map((entry) => entry.beschreibung).toList(growable: false);
}

// Nur die mit dem Kampf verknuepften Eintraege eines Namens.
List<HeroInventoryEntry> _verknuepft(
  List<HeroInventoryEntry> eintraege,
  String name,
) {
  return eintraege
      .where((entry) => entry.sourceRef != null && entry.gegenstand == name)
      .toList(growable: false);
}

void main() {
  late HeroSheet held;

  setUp(() {
    held = ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung).hero;
  });

  test('Abgleich ist idempotent und erhält die Reihenfolge', () {
    final einmal = reconcileInventoryWithCombat(
      held.inventoryEntries,
      held.combatConfig,
    );
    final zweimal = reconcileInventoryWithCombat(einmal, held.combatConfig);

    expect(
      einmal.map((entry) => entry.toJson()).toList(),
      held.inventoryEntries.map((entry) => entry.toJson()).toList(),
    );
    expect(
      zweimal.map((entry) => entry.toJson()).toList(),
      einmal.map((entry) => entry.toJson()).toList(),
    );
    // Manuelle Einträge zuerst, dann Waffen samt ihren Geschossen, dann
    // Rüstung — jeweils in Slot-Reihenfolge.
    expect(_beschreibungen(einmal), <String>[
      'Ersatzklinge im Rucksack',
      'Erbstück mit Runen',
      'Beutestück',
      'Elfenarbeit',
      'Köcher links',
      'Jagdbogen',
      'Köcher rechts',
      'Getragen',
      'Ersatz im Gepäck',
    ]);
    expect(_verknuepft(einmal, 'Dolch').first.isMagisch, isTrue);
    expect(_verknuepft(einmal, 'Dolch').last.isMagisch, isFalse);
  });

  test('gleichnamige Geschosse behalten ihre Menge je Waffe', () {
    final waffen = List<MainWeaponSlot>.of(held.combatConfig.weaponSlots);
    final zweiterBogen = waffen[3];
    waffen[3] = zweiterBogen.copyWith(
      rangedProfile: zweiterBogen.rangedProfile.copyWith(
        projectiles: <RangedProjectile>[
          zweiterBogen.rangedProfile.projectiles.single.copyWith(count: 5),
        ],
      ),
    );

    final ergebnis = reconcileInventoryWithCombat(
      held.inventoryEntries,
      held.combatConfig.copyWith(weapons: waffen),
    );

    final pfeile = _verknuepft(ergebnis, 'Jagdpfeil');
    expect(pfeile.map((entry) => entry.anzahl), <String>['20', '5']);
    expect(_beschreibungen(pfeile), <String>['Köcher links', 'Köcher rechts']);
  });

  test('Befund ARCH-07-B2: Entfernen der ersten von zwei gleichnamigen '
      'Waffen erhält die Inventardaten der zweiten', () {
    final ohneErstenDolch = List<MainWeaponSlot>.of(
      held.combatConfig.weaponSlots,
    )..removeAt(0);

    final ergebnis = reconcileInventoryWithCombat(
      held.inventoryEntries,
      held.combatConfig.copyWith(weapons: ohneErstenDolch),
    );

    final dolch = _verknuepft(ergebnis, 'Dolch').single;
    expect(dolch.beschreibung, 'Beutestück');
    expect(dolch.wert, '8');
    expect(dolch.gewichtGramm, 350);
  });

  test('Befund ARCH-07-B3: Umbenennen einer Waffe erhält ihre '
      'Inventardaten', () {
    final waffen = List<MainWeaponSlot>.of(held.combatConfig.weaponSlots);
    waffen[1] = waffen[1].copyWith(name: 'Parierdolch');

    final ergebnis = reconcileInventoryWithCombat(
      held.inventoryEntries,
      held.combatConfig.copyWith(weapons: waffen),
    );

    final umbenannt = _verknuepft(ergebnis, 'Parierdolch').single;
    expect(umbenannt.beschreibung, 'Beutestück');
    expect(umbenannt.wert, '8');
    expect(umbenannt.gewichtGramm, 350);
    expect(
      _beschreibungen(ergebnis),
      contains('Beutestück'),
      reason: 'Der umbenannte Slot behält den Inventareintrag.',
    );
  });
}
