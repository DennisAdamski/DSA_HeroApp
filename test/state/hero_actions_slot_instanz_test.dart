import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

// Verweis Slot → Instanz beim Speichern (ARCH-03): `saveHero` setzt
// `inventarInstanzId` an jedem verknüpften Slot; Umbenennen, Umsortieren und
// ein verlorener `slotRef` ändern die Zuordnung nicht.

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
  combatConfig: CombatConfig(
    weapons: [
      MainWeaponSlot(name: 'Dolch'),
      MainWeaponSlot(name: 'Dolch'),
      MainWeaponSlot(
        name: 'Kurzbogen',
        combatType: WeaponCombatType.ranged,
        rangedProfile: RangedWeaponProfile(
          projectiles: [RangedProjectile(name: 'Pfeil', count: 12)],
        ),
      ),
    ],
    armor: ArmorConfig(pieces: [ArmorPiece(name: 'Helm', isActive: true)]),
    offhandEquipment: [OffhandEquipmentEntry(name: 'Schild')],
  ),
);

// Der verknüpfte Eintrag des Slots mit ID-Verweis [slotRef].
HeroInventoryEntry _eintrag(HeroSheet held, String slotRef) {
  return held.inventoryEntries.singleWhere((e) => e.slotRef == slotRef);
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(heroes: [_held]),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<HeroSheet> speichere(HeroSheet held) {
    return container.read(heroActionsProvider).saveHero(held);
  }

  // Erstes Speichern; die Dolche bekommen Kennungen in der Beschreibung.
  Future<HeroSheet> gespeicherterHeld() async {
    final erst = await speichere(_held);
    final dolche = erst.combatConfig.weapons.take(2).toList();
    final eintraege = [
      for (final e in erst.inventoryEntries)
        e.slotRef == 'w#${dolche[0].id}'
            ? e.copyWith(beschreibung: 'erster')
            : e.slotRef == 'w#${dolche[1].id}'
            ? e.copyWith(beschreibung: 'zweiter')
            : e,
    ];
    return speichere(erst.copyWith(inventoryEntries: eintraege));
  }

  test('jeder verknüpfte Slot verweist auf seine Instanz', () async {
    final held = await gespeicherterHeld();
    final kampf = held.combatConfig;

    for (final slot in kampf.weapons) {
      expect(slot.inventarInstanzId, _eintrag(held, 'w#${slot.id}').instanzId);
    }
    final bogen = kampf.weapons[2];
    final pfeil = bogen.rangedProfile.projectiles.single;
    expect(
      pfeil.inventarInstanzId,
      _eintrag(held, 'w#${bogen.id}|p#${pfeil.id}').instanzId,
    );
    final helm = kampf.armor.pieces.single;
    expect(helm.inventarInstanzId, _eintrag(held, 'a#${helm.id}').instanzId);
    final schild = kampf.offhandEquipment.single;
    expect(
      schild.inventarInstanzId,
      _eintrag(held, 'oh#${schild.id}').instanzId,
    );
    final ids = held.inventoryEntries.map((e) => e.instanzId).toSet();
    expect(ids, hasLength(held.inventoryEntries.length));
  });

  test('erneutes Speichern ändert keinen Verweis', () async {
    final held = await gespeicherterHeld();

    final nochmal = await speichere(held);

    expect(nochmal.combatConfig.toJson(), held.combatConfig.toJson());
    expect(
      nochmal.inventoryEntries.map((e) => e.toJson()).toList(),
      held.inventoryEntries.map((e) => e.toJson()).toList(),
    );
  });

  test('Umbenennen und Umsortieren behalten Exemplar und Angaben', () async {
    final held = await gespeicherterHeld();
    final [erster, zweiter, bogen] = held.combatConfig.weapons;

    final umgebaut = await speichere(
      held.copyWith(
        combatConfig: held.combatConfig.copyWith(
          weapons: [
            bogen,
            zweiter.copyWith(name: 'Linkhand'),
            erster,
          ],
        ),
      ),
    );

    final waffen = umgebaut.combatConfig.weapons;
    expect(waffen[1].inventarInstanzId, zweiter.inventarInstanzId);
    expect(waffen[2].inventarInstanzId, erster.inventarInstanzId);
    final linkhand = _eintrag(umgebaut, 'w#${zweiter.id}');
    expect(linkhand.gegenstand, 'Linkhand');
    expect(linkhand.beschreibung, 'zweiter');
    expect(linkhand.instanzId, zweiter.inventarInstanzId);
    expect(_eintrag(umgebaut, 'w#${erster.id}').beschreibung, 'erster');
  });

  test('ein Eintrag ohne slotRef findet über die Instanz zurück', () async {
    final held = await gespeicherterHeld();
    final zweiter = held.combatConfig.weapons[1];
    // Etwa nach einer Bearbeitung, die den ID-Verweis verloren hat; der
    // zweite Dolch steht vorn, per Name ginge er an den ersten Slot.
    final ohneSlotRef = [
      for (final e in held.inventoryEntries)
        if (e.source == InventoryItemSource.waffe && e.gegenstand == 'Dolch')
          e.copyWith(slotRef: null),
    ].reversed;
    final rest = held.inventoryEntries.where(
      (e) => e.source != InventoryItemSource.waffe || e.gegenstand != 'Dolch',
    );

    final repariert = await speichere(
      held.copyWith(inventoryEntries: [...ohneSlotRef, ...rest]),
    );

    final eintrag = _eintrag(repariert, 'w#${zweiter.id}');
    expect(eintrag.beschreibung, 'zweiter');
    expect(eintrag.instanzId, zweiter.inventarInstanzId);
  });

  test('ein entfernter Slot hinterlässt keinen Verweis', () async {
    final held = await gespeicherterHeld();
    final [erster, _, bogen] = held.combatConfig.weapons;

    final ohneZweiten = await speichere(
      held.copyWith(
        combatConfig: held.combatConfig.copyWith(weapons: [erster, bogen]),
      ),
    );

    final instanzen = ohneZweiten.inventoryEntries
        .map((e) => e.instanzId)
        .toSet();
    for (final slot in ohneZweiten.combatConfig.weapons) {
      expect(instanzen, contains(slot.inventarInstanzId));
    }
    expect(
      ohneZweiten.inventoryEntries.where((e) => e.beschreibung == 'zweiter'),
      isEmpty,
    );
  });
}
