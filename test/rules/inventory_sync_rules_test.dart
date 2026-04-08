import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';

// ---------------------------------------------------------------------------
// Hilfsfunktionen fuer Tests
// ---------------------------------------------------------------------------

CombatConfig _configWithWeapon(String name) {
  return CombatConfig(weapons: [MainWeaponSlot(name: name)]);
}

CombatConfig _configWithRangedWeapon(
  String weaponName,
  List<RangedProjectile> projectiles,
) {
  return CombatConfig(
    weapons: [
      MainWeaponSlot(
        name: weaponName,
        combatType: WeaponCombatType.ranged,
        rangedProfile: RangedWeaponProfile(projectiles: projectiles),
      ),
    ],
  );
}

void main() {
  // -------------------------------------------------------------------------
  // buildExpectedLinkedEntries
  // -------------------------------------------------------------------------
  group('buildExpectedLinkedEntries', () {
    test('Waffe erzeugt Ausruestungs-Eintrag', () {
      final config = CombatConfig(
        weapons: const [
          MainWeaponSlot(
            name: 'Langschwert',
            isArtifact: true,
            artifactDescription: 'Flammende Klinge',
            isGeweiht: true,
            geweihtDescription: 'Praiosweihe',
          ),
        ],
      );
      final entries = buildExpectedLinkedEntries(config);

      expect(entries.length, 1);
      expect(entries[0].gegenstand, 'Langschwert');
      expect(entries[0].source, InventoryItemSource.waffe);
      expect(entries[0].sourceRef, 'w:Langschwert');
      expect(entries[0].itemType, InventoryItemType.ausruestung);
      expect(entries[0].istAusgeruestet, isTrue);
      expect(entries[0].isMagisch, isTrue);
      expect(entries[0].magischDescription, 'Flammende Klinge');
      expect(entries[0].isGeweiht, isTrue);
      expect(entries[0].geweihtDescription, 'Praiosweihe');
    });

    test('Fernkampfwaffe erzeugt Waffen- und Geschoss-Eintraege', () {
      final config = _configWithRangedWeapon('Bogen', [
        const RangedProjectile(name: 'Pfeil', count: 20),
        const RangedProjectile(name: 'Brandpfeil', count: 5),
      ]);
      final entries = buildExpectedLinkedEntries(config);

      expect(entries.length, 3);
      expect(entries[0].gegenstand, 'Bogen');
      expect(entries[0].source, InventoryItemSource.waffe);

      expect(entries[1].gegenstand, 'Pfeil');
      expect(entries[1].source, InventoryItemSource.geschoss);
      expect(entries[1].sourceRef, 'w:Bogen|p:Pfeil');
      expect(entries[1].itemType, InventoryItemType.verbrauchsgegenstand);
      expect(entries[1].anzahl, '20');

      expect(entries[2].gegenstand, 'Brandpfeil');
      expect(entries[2].anzahl, '5');
    });

    test('Waffe mit leerem Namen wird uebersprungen', () {
      final config = CombatConfig(
        weapons: [
          const MainWeaponSlot(name: ''),
          const MainWeaponSlot(name: 'Dolch'),
        ],
      );
      final entries = buildExpectedLinkedEntries(config);
      expect(entries.length, 1);
      expect(entries[0].gegenstand, 'Dolch');
    });

    test('Geschoss mit leerem Namen wird uebersprungen', () {
      final config = _configWithRangedWeapon('Armbrust', [
        const RangedProjectile(name: ''),
        const RangedProjectile(name: 'Bolzen', count: 30),
      ]);
      final entries = buildExpectedLinkedEntries(config);
      expect(entries.length, 2); // Armbrust + Bolzen
      expect(entries[1].gegenstand, 'Bolzen');
    });

    test('Ruestungsstueck erzeugt Ruestungs-Eintrag mit isActive', () {
      final config = CombatConfig(
        armor: const ArmorConfig(
          pieces: [
            ArmorPiece(name: 'Kettenhemd', isActive: true),
            ArmorPiece(name: 'Helm', isActive: false),
          ],
        ),
      );
      final entries = buildExpectedLinkedEntries(config);

      expect(entries.length, 2);
      expect(entries[0].source, InventoryItemSource.ruestung);
      expect(entries[0].sourceRef, 'a:Kettenhemd');
      expect(entries[0].istAusgeruestet, isTrue);
      expect(entries[1].istAusgeruestet, isFalse);
    });

    test('Nebenhand-Eintrag wird korrekt erzeugt', () {
      final config = CombatConfig(
        offhandEquipment: [const OffhandEquipmentEntry(name: 'Rundschild')],
      );
      final entries = buildExpectedLinkedEntries(config);

      expect(entries.length, 1);
      expect(entries[0].source, InventoryItemSource.nebenhand);
      expect(entries[0].sourceRef, 'oh:Rundschild');
    });

    test('leere CombatConfig liefert leere Liste', () {
      // mainWeapon hat leeren Namen → wird uebersprungen
      const config = CombatConfig();
      final entries = buildExpectedLinkedEntries(config);
      expect(entries, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // reconcileInventoryWithCombat
  // -------------------------------------------------------------------------
  group('reconcileInventoryWithCombat', () {
    test('manuelle Eintraege bleiben unveraendert erhalten', () {
      const manualEntry = HeroInventoryEntry(
        gegenstand: 'Heiltrank',
        itemType: InventoryItemType.verbrauchsgegenstand,
        source: InventoryItemSource.manuell,
      );
      final config = _configWithWeapon('Schwert');
      final result = reconcileInventoryWithCombat([manualEntry], config);

      expect(result.first.gegenstand, 'Heiltrank');
      expect(result.first.source, InventoryItemSource.manuell);
    });

    test('abenteuer-eintraege bleiben neben Combat-Sync erhalten', () {
      const adventureEntry = HeroInventoryEntry(
        gegenstand: 'Silberdolch',
        itemType: InventoryItemType.wertvolles,
        source: InventoryItemSource.abenteuer,
        sourceRef: 'adv:adv_1|loot:loot_1',
      );
      final config = _configWithWeapon('Schwert');
      final result = reconcileInventoryWithCombat([adventureEntry], config);

      expect(result.first.gegenstand, 'Silberdolch');
      expect(result.first.source, InventoryItemSource.abenteuer);
      expect(result[1].source, InventoryItemSource.waffe);
    });

    test('neuer Waffen-Eintrag wird hinzugefuegt', () {
      final config = _configWithWeapon('Axt');
      final result = reconcileInventoryWithCombat([], config);

      expect(result.length, 1);
      expect(result[0].gegenstand, 'Axt');
      expect(result[0].source, InventoryItemSource.waffe);
    });

    test(
      'editierbare Felder eines bestehenden Eintrags werden beibehalten',
      () {
        const existingLinked = HeroInventoryEntry(
          gegenstand: 'Dolch',
          source: InventoryItemSource.waffe,
          sourceRef: 'w:Dolch',
          itemType: InventoryItemType.ausruestung,
          beschreibung: 'Erbstueck meines Vaters',
          gewichtGramm: 450,
          wertSilber: 12,
          herkunft: 'Familie',
          modifiers: [
            InventoryItemModifier(
              kind: InventoryModifierKind.stat,
              targetId: 'at',
              wert: 1,
            ),
          ],
        );
        final config = _configWithWeapon('Dolch');
        final result = reconcileInventoryWithCombat([existingLinked], config);

        expect(result.length, 1);
        expect(result[0].beschreibung, 'Erbstueck meines Vaters');
        expect(result[0].gewichtGramm, 450);
        expect(result[0].wertSilber, 12);
        expect(result[0].herkunft, 'Familie');
        expect(result[0].modifiers.length, 1);
      },
    );

    test('entfernter Kampf-Eintrag verschwindet aus Inventar', () {
      const linkedEntry = HeroInventoryEntry(
        gegenstand: 'Altes Schwert',
        source: InventoryItemSource.waffe,
        sourceRef: 'w:Altes Schwert',
      );
      const config = CombatConfig(); // kein Waffenname → leere Liste
      final result = reconcileInventoryWithCombat([linkedEntry], config);
      expect(result, isEmpty);
    });

    test('Geschoss-Anzahl kommt immer aus CombatConfig', () {
      const existingProj = HeroInventoryEntry(
        gegenstand: 'Pfeil',
        source: InventoryItemSource.geschoss,
        sourceRef: 'w:Bogen|p:Pfeil',
        itemType: InventoryItemType.verbrauchsgegenstand,
        anzahl: '5', // veraltet
      );
      final config = _configWithRangedWeapon('Bogen', [
        const RangedProjectile(name: 'Pfeil', count: 20),
      ]);
      final result = reconcileInventoryWithCombat([existingProj], config);

      final projEntry = result.firstWhere(
        (e) => e.source == InventoryItemSource.geschoss,
      );
      expect(projEntry.anzahl, '20');
    });

    test(
      'zwei gleichnamige Waffen erzeugen zwei separate Inventar-Eintraege',
      () {
        final config = CombatConfig(
          weapons: [
            const MainWeaponSlot(name: 'Schwert'),
            const MainWeaponSlot(name: 'Schwert'),
          ],
        );
        final result = reconcileInventoryWithCombat([], config);
        expect(result.length, 2);
      },
    );

    test('Reihenfolge: manuell zuerst, dann verlinkt', () {
      const manual = HeroInventoryEntry(
        gegenstand: 'Heiltrank',
        source: InventoryItemSource.manuell,
        itemType: InventoryItemType.verbrauchsgegenstand,
      );
      final config = _configWithWeapon('Langschwert');
      final result = reconcileInventoryWithCombat([manual], config);

      expect(result[0].source, InventoryItemSource.manuell);
      expect(result[1].source, InventoryItemSource.waffe);
    });
  });

  // -------------------------------------------------------------------------
  // applyAmmoCountChangeToConfig
  // -------------------------------------------------------------------------
  group('applyAmmoCountChangeToConfig', () {
    test('aktualisiert Geschossanzahl korrekt', () {
      final config = _configWithRangedWeapon('Bogen', [
        const RangedProjectile(name: 'Pfeil', count: 10),
      ]);
      final updated = applyAmmoCountChangeToConfig(
        config,
        'w:Bogen|p:Pfeil',
        25,
      );

      final updatedSlot = updated.weaponSlots[0];
      expect(updatedSlot.rangedProfile.projectiles[0].count, 25);
    });

    test('gibt config unveraendert zurueck bei unbekanntem Ref', () {
      final config = _configWithWeapon('Schwert');
      final result = applyAmmoCountChangeToConfig(config, 'w:Bogen|p:Pfeil', 5);
      expect(result.weaponSlots[0].name, 'Schwert');
    });

    test('gibt config unveraendert zurueck bei ungueltigem Ref-Format', () {
      final config = _configWithRangedWeapon('Bogen', [
        const RangedProjectile(name: 'Pfeil', count: 10),
      ]);
      final result = applyAmmoCountChangeToConfig(config, 'ungueltig', 5);
      expect(result.weaponSlots[0].rangedProfile.projectiles[0].count, 10);
    });

    test('negative Anzahl wird auf 0 geclampst', () {
      final config = _configWithRangedWeapon('Bogen', [
        const RangedProjectile(name: 'Pfeil', count: 5),
      ]);
      final updated = applyAmmoCountChangeToConfig(
        config,
        'w:Bogen|p:Pfeil',
        -3,
      );
      expect(updated.weaponSlots[0].rangedProfile.projectiles[0].count, 0);
    });

    test('mainWeapon-Fallback wird korrekt aktualisiert', () {
      // weapons ist leer → mainWeapon wird verwendet
      final config = CombatConfig(
        mainWeapon: const MainWeaponSlot(
          name: 'Armbrust',
          combatType: WeaponCombatType.ranged,
          rangedProfile: RangedWeaponProfile(
            projectiles: [RangedProjectile(name: 'Bolzen', count: 15)],
          ),
        ),
      );
      final updated = applyAmmoCountChangeToConfig(
        config,
        'w:Armbrust|p:Bolzen',
        8,
      );
      expect(updated.mainWeapon.rangedProfile.projectiles[0].count, 8);
    });
  });

  group('applyLinkedInventoryDetailsToConfig', () {
    test('uebernimmt magisch/geweiht fuer Waffe, Ruestung und Nebenhand', () {
      final config = CombatConfig(
        weapons: const [MainWeaponSlot(name: 'Bannschwert')],
        armor: const ArmorConfig(pieces: [ArmorPiece(name: 'Kettenhemd')]),
        offhandEquipment: const [OffhandEquipmentEntry(name: 'Rundschild')],
      );
      final entries = const <HeroInventoryEntry>[
        HeroInventoryEntry(
          gegenstand: 'Bannschwert',
          source: InventoryItemSource.waffe,
          sourceRef: 'w:Bannschwert',
          isMagisch: true,
          magischDescription: 'Arkan versiegelt',
          isGeweiht: true,
          geweihtDescription: 'Boron',
        ),
        HeroInventoryEntry(
          gegenstand: 'Kettenhemd',
          source: InventoryItemSource.ruestung,
          sourceRef: 'a:Kettenhemd',
          isMagisch: true,
          magischDescription: 'Kaltglanz',
        ),
        HeroInventoryEntry(
          gegenstand: 'Rundschild',
          source: InventoryItemSource.nebenhand,
          sourceRef: 'oh:Rundschild',
          isGeweiht: true,
          geweihtDescription: 'Tempelweihung',
        ),
      ];

      final updated = applyLinkedInventoryDetailsToConfig(config, entries);

      expect(updated.weaponSlots.single.isArtifact, isTrue);
      expect(
        updated.weaponSlots.single.artifactDescription,
        'Arkan versiegelt',
      );
      expect(updated.weaponSlots.single.isGeweiht, isTrue);
      expect(updated.weaponSlots.single.geweihtDescription, 'Boron');
      expect(updated.armor.pieces.single.isArtifact, isTrue);
      expect(updated.armor.pieces.single.artifactDescription, 'Kaltglanz');
      expect(updated.offhandEquipment.single.isGeweiht, isTrue);
      expect(
        updated.offhandEquipment.single.geweihtDescription,
        'Tempelweihung',
      );
    });

    test('gleiche Namen werden stabil in Reihenfolge gematcht', () {
      final config = CombatConfig(
        weapons: const [
          MainWeaponSlot(name: 'Schwert'),
          MainWeaponSlot(name: 'Schwert'),
        ],
      );
      final entries = const <HeroInventoryEntry>[
        HeroInventoryEntry(
          gegenstand: 'Schwert',
          source: InventoryItemSource.waffe,
          sourceRef: 'w:Schwert',
          isMagisch: true,
          magischDescription: 'Erstes',
        ),
        HeroInventoryEntry(
          gegenstand: 'Schwert',
          source: InventoryItemSource.waffe,
          sourceRef: 'w:Schwert',
          isGeweiht: true,
          geweihtDescription: 'Zweites',
        ),
      ];

      final updated = applyLinkedInventoryDetailsToConfig(config, entries);

      expect(updated.weaponSlots[0].isArtifact, isTrue);
      expect(updated.weaponSlots[0].artifactDescription, 'Erstes');
      expect(updated.weaponSlots[1].isGeweiht, isTrue);
      expect(updated.weaponSlots[1].geweihtDescription, 'Zweites');
    });
  });
}
