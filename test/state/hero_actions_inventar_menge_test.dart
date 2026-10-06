import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

// Strukturierte Menge beim Speichern (ARCH-03): `saveHero` überführt reine
// Zahlen in `menge`, verknüpfte Geschosse tragen die Menge ihres Slots.

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
);

void main() {
  late FakeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeRepository(heroes: [_held]);
    container = ProviderContainer(
      overrides: [heroRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('saveHero überführt reine Zahlen und lässt Offenes offen', () async {
    final gespeichert = await container
        .read(heroActionsProvider)
        .saveHero(
          _held.copyWith(
            inventoryEntries: const [
              HeroInventoryEntry(gegenstand: 'Heiltrank', anzahl: '3'),
              HeroInventoryEntry(gegenstand: 'Seil', anzahl: ''),
              HeroInventoryEntry(gegenstand: 'Nüsse', anzahl: 'ein paar'),
              HeroInventoryEntry(gegenstand: 'Fackel', anzahl: '4', menge: 6),
            ],
          ),
        );

    expect(gespeichert.inventoryEntries.map((e) => e.menge), [
      3,
      null,
      null,
      6,
    ]);
    expect(gespeichert.inventoryEntries[3].anzahl, '4');
  });

  test('ein verknüpftes Geschoss trägt die Menge seines Slots', () async {
    final gespeichert = await container
        .read(heroActionsProvider)
        .saveHero(
          _held.copyWith(
            combatConfig: const CombatConfig(
              weapons: [
                MainWeaponSlot(
                  name: 'Kurzbogen',
                  combatType: WeaponCombatType.ranged,
                  rangedProfile: RangedWeaponProfile(
                    projectiles: [RangedProjectile(name: 'Pfeil', count: 17)],
                  ),
                ),
              ],
            ),
          ),
        );

    final pfeile = gespeichert.inventoryEntries.singleWhere(
      (e) => e.source == InventoryItemSource.geschoss,
    );
    expect(pfeile.menge, 17);
    expect(pfeile.anzahl, '17');
  });
}
