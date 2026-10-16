import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/abgelegter_kampfgegenstand.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_stapel_rules.dart';

// Stapel zusammenführen (ARCH-03, Entscheidung vom 07.10.2026): gleicher
// Name, gleicher Typ, gleiche Markierungen und Modifikatoren; die Mengen
// werden addiert, der Rest kommt vom Ziel.

HeroInventoryEntry _pfeile(
  String id,
  int menge, {
  String ort = '',
  String name = 'Pfeil',
}) {
  return HeroInventoryEntry(
    gegenstand: name,
    anzahl: '$menge',
    menge: menge,
    itemType: InventoryItemType.verbrauchsgegenstand,
    woGetragen: ort,
    instanzId: id,
  );
}

HeroSheet _held(List<HeroInventoryEntry> eintraege, [CombatConfig? kampf]) {
  return HeroSheet(
    id: 'demo',
    name: 'Rondra',
    level: 1,
    attributes: const Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    combatConfig: kampf ?? const CombatConfig(),
    inventoryEntries: eintraege,
  );
}

void main() {
  test('die Mengen werden addiert, Ort und Rest kommen vom Ziel', () {
    final rucksack = _pfeile('r', 8, ort: 'Rucksack');
    final koecher = _pfeile(
      'k',
      12,
      ort: 'Köcher',
    ).copyWith(beschreibung: 'Gefiedert');

    final held = mitZusammengefuehrtemStapel(
      _held([rucksack, koecher]),
      rucksack,
      koecher,
    );

    final ergebnis = held.inventoryEntries.single;
    expect(ergebnis.instanzId, 'k');
    expect(ergebnis.menge, 20);
    expect(ergebnis.anzahl, '20');
    expect(ergebnis.woGetragen, 'Köcher');
    expect(ergebnis.beschreibung, 'Gefiedert');
  });

  group('gesperrt', () {
    final pfeile = _pfeile('a', 5);

    final faelle = <String, HeroInventoryEntry>{
      'mit sich selbst': pfeile,
      'anderer Name': _pfeile('b', 5, name: 'Bolzen'),
      'anderer Typ': _pfeile(
        'b',
        5,
      ).copyWith(itemType: InventoryItemType.sonstiges),
      'magisch': _pfeile('b', 5).copyWith(isMagisch: true),
      'geweiht': _pfeile('b', 5).copyWith(isGeweiht: true),
      'Modifikatoren': _pfeile('b', 5).copyWith(
        modifiers: const [
          InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'at',
            wert: 1,
          ),
        ],
      ),
      'offene Menge': _pfeile('b', 5).copyWith(anzahl: 'ein paar', menge: null),
      'ausgerüstete Waffe': const HeroInventoryEntry(
        gegenstand: 'Pfeil',
        anzahl: '1',
        menge: 1,
        itemType: InventoryItemType.verbrauchsgegenstand,
        source: InventoryItemSource.waffe,
        sourceRef: 'w:Pfeil',
        instanzId: 'b',
      ),
      'Abenteuerbeute': _pfeile('b', 5).copyWith(
        source: InventoryItemSource.abenteuer,
        sourceRef: 'adv:a|loot:l',
      ),
    };
    for (final MapEntry(key: fall, value: ziel) in faelle.entries) {
      test(fall, () {
        expect(zusammenfuehrenGesperrt(pfeile, ziel), isNotNull);
      });
    }

    test('eine ausgerüstete Quelle muss zuerst abgelegt werden', () {
      final amBogen = _pfeile('b', 5).copyWith(
        source: InventoryItemSource.geschoss,
        sourceRef: 'w:Bogen|p:Pfeil',
        slotRef: 'w#w|p#p',
      );
      expect(zusammenfuehrenGesperrt(amBogen, pfeile), isNotNull);
    });

    test('Groß- und Kleinschreibung zählt nicht', () {
      expect(
        zusammenfuehrenGesperrt(pfeile, _pfeile('b', 2, name: ' pfeil ')),
        isNull,
      );
    });
  });

  test('in Pfeile am Bogen: der Bestand am richtigen Bogen steigt', () {
    MainWeaponSlot bogen(String id, int pfeile) => MainWeaponSlot(
      id: id,
      name: 'Kurzbogen',
      combatType: WeaponCombatType.ranged,
      rangedProfile: RangedWeaponProfile(
        projectiles: [RangedProjectile(id: 'p', name: 'Pfeil', count: pfeile)],
      ),
    );
    final amZweiten = _pfeile('z', 4).copyWith(
      source: InventoryItemSource.geschoss,
      sourceRef: 'w:Kurzbogen|p:Pfeil',
      slotRef: 'w#b|p#p',
    );
    final rucksack = _pfeile('r', 6);
    final held = _held([
      rucksack,
      amZweiten,
    ], CombatConfig(weapons: [bogen('a', 9), bogen('b', 4)]));

    final ergebnis = mitZusammengefuehrtemStapel(held, rucksack, amZweiten);

    final bestaende = ergebnis.combatConfig.weaponSlots
        .map((w) => w.rangedProfile.projectiles.single.count)
        .toList();
    expect(bestaende, [9, 10]);
    expect(ergebnis.inventoryEntries.single.menge, 10);
    expect(ergebnis.inventoryEntries.single.abgelegt, isNull);
  });

  test('gemerkte Kampfwerte eines abgelegten Stapels bleiben', () {
    final abgelegt = _pfeile('a', 3).copyWith(
      abgelegt: const AbgelegterKampfgegenstand(
        geschoss: RangedProjectile(name: 'Pfeil', tpMod: 1),
      ),
    );
    final lose = _pfeile('b', 2);

    final held = mitZusammengefuehrtemStapel(
      _held([abgelegt, lose]),
      abgelegt,
      lose,
    );

    expect(held.inventoryEntries.single.abgelegt!.geschoss!.tpMod, 1);
  });

  test('ein inzwischen geänderter Stapel wird nicht zusammengeführt', () {
    final a = _pfeile('a', 3);
    final b = _pfeile('b', 2);
    final held = _held([a, b.copyWith(woGetragen: 'anderswo')]);

    expect(() => mitZusammengefuehrtemStapel(held, a, b), throwsStateError);
  });

  test('zusammenfuehrbareZiele listet nur passende Stapel', () {
    final a = _pfeile('a', 3);
    final eintraege = [a, _pfeile('b', 2), _pfeile('c', 1, name: 'Bolzen')];

    expect(zusammenfuehrbareZiele(eintraege, a).map((e) => e.instanzId), ['b']);
  });
}
