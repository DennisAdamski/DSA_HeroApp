import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';

import '../../test_support/bogen_test_repository.dart';

// Stapel teilen im Inventar (ARCH-03): Der Editor spaltet frisch vom
// gespeicherten Stapel ab, wählt den neuen Stapel aus, und ein Geschoss gibt
// die Restmenge nur an seinen eigenen Bogen.

const _trank = HeroInventoryEntry(
  gegenstand: 'Heiltrank',
  anzahl: '5',
  woGetragen: 'Gürteltasche',
  itemType: InventoryItemType.verbrauchsgegenstand,
);

HeroSheet _held() => const HeroSheet(
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
  inventoryEntries: [_trank],
);

MainWeaponSlot _bogen(String id, int pfeile) => MainWeaponSlot(
  id: id,
  name: 'Kurzbogen',
  combatType: WeaponCombatType.ranged,
  rangedProfile: RangedWeaponProfile(
    projectiles: [RangedProjectile(id: 'p', name: 'Pfeil', count: pfeile)],
  ),
);

HeroInventoryEntry _pfeile(String bogenId, int anzahl) => HeroInventoryEntry(
  gegenstand: 'Pfeil',
  anzahl: '$anzahl',
  itemType: InventoryItemType.verbrauchsgegenstand,
  source: InventoryItemSource.geschoss,
  sourceRef: 'w:Kurzbogen|p:Pfeil',
  slotRef: 'w#$bogenId|p#p',
);

HeroInventoryEntry _bogenEintrag(String bogenId) => HeroInventoryEntry(
  gegenstand: 'Kurzbogen',
  itemType: InventoryItemType.ausruestung,
  source: InventoryItemSource.waffe,
  sourceRef: 'w:Kurzbogen',
  slotRef: 'w#$bogenId',
  istAusgeruestet: true,
);

// Zwei gleichnamige Bögen; der Namensverweis träfe beide Male den ersten.
HeroSheet _schuetze() => _held().copyWith(
  combatConfig: CombatConfig(weapons: [_bogen('a', 10), _bogen('b', 20)]),
  inventoryEntries: [
    _bogenEintrag('a'),
    _pfeile('a', 10),
    _bogenEintrag('b'),
    _pfeile('b', 20),
  ],
);

int _pfeileVon(HeroSheet held, int bogen) =>
    held.combatConfig.weaponSlots[bogen].rangedProfile.projectiles.single.count;

void main() {
  late BogenTestRepository repo;

  Future<void> zeige(
    WidgetTester tester,
    HeroSheet held, {
    bool breit = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = breit
        ? const Size(1600, 900)
        : const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(heroes: [held]);
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

  Future<void> oeffneZeile(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(ValueKey<String>('inventory-row-open-$index')));
    await tester.pumpAndSettle();
  }

  // Öffnet den Dialog, setzt die Stückzahl über −/+ und den Ort.
  Future<void> teile(WidgetTester tester, {int plus = 0, String? ort}) async {
    final knopf = find.byKey(const ValueKey<String>('inventory-editor-split'));
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
    for (var i = 0; i < plus; i++) {
      await tester.tap(
        find.byKey(const ValueKey<String>('stapel-teilen-plus')),
      );
      await tester.pump();
    }
    if (ort != null) {
      await tester.enterText(
        find.byKey(const ValueKey<String>('stapel-teilen-ort')),
        ort,
      );
    }
    await tester.tap(find.byKey(const ValueKey<String>('stapel-teilen-ok')));
    await tester.pumpAndSettle();
  }

  testWidgets('teilt einen Stapel und wählt den neuen aus', (tester) async {
    await zeige(tester, _held(), breit: true);
    await oeffneZeile(tester, 0);

    // Vorbelegt ist die Hälfte (2 von 5); ein Plus ergibt 3.
    await teile(tester, plus: 1, ort: 'Rucksack');

    final gespeichert = await repo.gespeichert('hero-1');
    final [rest, neu] = gespeichert.inventoryEntries;
    expect(rest.menge, 2);
    expect(rest.woGetragen, 'Gürteltasche');
    expect(neu.menge, 3);
    expect(neu.woGetragen, 'Rucksack');
    expect(neu.gegenstand, 'Heiltrank');
    expect(rest.instanzId, isNotNull);
    expect(neu.instanzId, isNotNull);
    expect(neu.instanzId, isNot(rest.instanzId));
    // Der Editor zeigt jetzt den neuen Stapel.
    final anzahl = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('inventory-editor-quantity')),
    );
    expect(anzahl.controller!.text, '3');
  });

  testWidgets('ein inzwischen geänderter Stapel wird nicht geteilt', (
    tester,
  ) async {
    await zeige(tester, _held(), breit: true);
    await oeffneZeile(tester, 0);
    repo.fremdeAenderung = (held) =>
        held.copyWith(inventoryEntries: [_trank.copyWith(anzahl: '4')]);

    await teile(tester);

    expect(find.textContaining('Teilen fehlgeschlagen'), findsOneWidget);
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('Pfeile des zweiten Bogens gehen in den Rucksack', (
    tester,
  ) async {
    await zeige(tester, _schuetze());
    // Ein anderer Weg hat dem ersten Bogen inzwischen Pfeile gegeben.
    repo.fremdeAenderung = (held) => held.copyWith(
      name: 'Thalion der Kühne',
      combatConfig: CombatConfig(weapons: [_bogen('a', 14), _bogen('b', 20)]),
    );

    await oeffneZeile(tester, 3);
    await teile(tester, ort: 'Rucksack');

    final gespeichert = await repo.gespeichert('hero-1');
    expect(gespeichert.name, 'Thalion der Kühne');
    expect(_pfeileVon(gespeichert, 0), 14);
    expect(_pfeileVon(gespeichert, 1), 10);
    final pfeile = gespeichert.inventoryEntries.where(
      (e) => e.gegenstand == 'Pfeil',
    );
    expect(
      pfeile.map((e) => (e.source, e.menge, e.woGetragen)),
      unorderedEquals([
        (InventoryItemSource.manuell, 10, 'Rucksack'),
        (InventoryItemSource.geschoss, 14, ''),
        (InventoryItemSource.geschoss, 10, ''),
      ]),
    );
    // Die Editorseite hat sich geschlossen.
    expect(
      find.byKey(const ValueKey<String>('inventory-editor-split')),
      findsNothing,
    );
  });
}
