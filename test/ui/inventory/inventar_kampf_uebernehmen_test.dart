import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/abgelegter_kampfgegenstand.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';

import '../../test_support/bogen_test_repository.dart';

// „In Kampfbereich übernehmen“ (ARCH-03): Ein abgelegter Gegenstand kommt
// mit seinen gemerkten Kampfwerten als dasselbe Exemplar zurück; ein
// Geschoss fragt nach seiner Fernkampfwaffe.

const _bogen = MainWeaponSlot(
  id: 'w1',
  name: 'Kurzbogen',
  combatType: WeaponCombatType.ranged,
  inventarInstanzId: 'i-bogen',
);

const _schwert = HeroInventoryEntry(
  gegenstand: 'Schwert',
  itemType: InventoryItemType.ausruestung,
  instanzId: 'i-schwert',
  beschreibung: 'Erbstück',
  abgelegt: AbgelegterKampfgegenstand(
    waffe: MainWeaponSlot(id: 'w9', name: 'Schwert', tpFlat: 4),
  ),
);

const _pfeile = HeroInventoryEntry(
  gegenstand: 'Pfeil',
  anzahl: '7',
  menge: 7,
  itemType: InventoryItemType.verbrauchsgegenstand,
  instanzId: 'i-pfeil',
  abgelegt: AbgelegterKampfgegenstand(
    geschoss: RangedProjectile(id: 'p9', name: 'Pfeil', tpMod: 1),
  ),
);

const _held = HeroSheet(
  id: 'hero-1',
  name: 'Thalion',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 11,
    inn: 10,
    ch: 10,
    ff: 11,
    ge: 12,
    ko: 11,
    kk: 12,
  ),
  combatConfig: CombatConfig(weapons: [_bogen]),
  inventoryEntries: [
    _schwert,
    _pfeile,
    HeroInventoryEntry(
      gegenstand: 'Kurzbogen',
      itemType: InventoryItemType.ausruestung,
      source: InventoryItemSource.waffe,
      sourceRef: 'w:Kurzbogen',
      slotRef: 'w#w1',
      istAusgeruestet: true,
      instanzId: 'i-bogen',
    ),
  ],
);

void main() {
  late BogenTestRepository repo;

  Future<void> zeige(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(heroes: [_held]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: HeroInventoryTab(
              heroId: 'hero-1',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> uebernimm(WidgetTester tester, int zeile) async {
    await tester.tap(find.byKey(ValueKey<String>('inventory-row-open-$zeile')));
    await tester.pumpAndSettle();
    final knopf = find.byKey(
      const ValueKey<String>('inventory-editor-kampf-uebernehmen'),
    );
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
  }

  testWidgets('die Waffe kommt mit ihren Werten zurück', (tester) async {
    await zeige(tester);

    await uebernimm(tester, 0);

    final gespeichert = await repo.gespeichert('hero-1');
    final schwert = gespeichert.combatConfig.weaponSlots.last;
    expect(schwert.name, 'Schwert');
    expect(schwert.tpFlat, 4);
    expect(schwert.inventarInstanzId, 'i-schwert');
    final eintrag = gespeichert.inventoryEntries.singleWhere(
      (e) => e.instanzId == 'i-schwert',
    );
    expect(eintrag.source, InventoryItemSource.waffe);
    expect(eintrag.abgelegt, isNull);
    expect(eintrag.beschreibung, 'Erbstück');
  });

  testWidgets('ein Geschoss fragt nach der Waffe und bringt seine Menge', (
    tester,
  ) async {
    await zeige(tester);

    await uebernimm(tester, 1);
    await tester.tap(
      find.byKey(const ValueKey<String>('inventory-zielwaffe-w1')),
    );
    await tester.pumpAndSettle();

    final gespeichert = await repo.gespeichert('hero-1');
    final pfeil = gespeichert
        .combatConfig
        .weaponSlots
        .single
        .rangedProfile
        .projectiles
        .single;
    expect(pfeil.count, 7);
    expect(pfeil.tpMod, 1);
    expect(pfeil.inventarInstanzId, 'i-pfeil');
  });
}
