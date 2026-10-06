import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_verkauf_rules.dart';

// Verkaufen (ARCH-03, Entscheidung vom 07.10.2026): Erlös vorbelegt mit dem
// vollen Wert, auf den Geldstand; Ausgerüstetes verlässt den Kampfbereich.

const _fackeln = HeroInventoryEntry(
  gegenstand: 'Fackel',
  anzahl: '5',
  menge: 5,
  wertSilber: 2,
  instanzId: 'f',
);

const _bogen = MainWeaponSlot(
  id: 'w2',
  name: 'Kurzbogen',
  combatType: WeaponCombatType.ranged,
  inventarInstanzId: 'i-bogen',
  rangedProfile: RangedWeaponProfile(
    projectiles: [
      RangedProjectile(
        id: 'p1',
        name: 'Pfeil',
        count: 12,
        inventarInstanzId: 'i-pfeil',
      ),
    ],
  ),
);

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
  dukaten: '10',
  combatConfig: CombatConfig(
    weapons: [
      MainWeaponSlot(id: 'w1', name: 'Schwert', inventarInstanzId: 'i-sw'),
      _bogen,
    ],
    armor: ArmorConfig(
      pieces: [ArmorPiece(id: 'a1', name: 'Helm', inventarInstanzId: 'i-h')],
    ),
  ),
  inventoryEntries: [
    _fackeln,
    HeroInventoryEntry(
      gegenstand: 'Schwert',
      source: InventoryItemSource.waffe,
      sourceRef: 'w:Schwert',
      slotRef: 'w#w1',
      instanzId: 'i-sw',
    ),
    HeroInventoryEntry(
      gegenstand: 'Kurzbogen',
      source: InventoryItemSource.waffe,
      sourceRef: 'w:Kurzbogen',
      slotRef: 'w#w2',
      instanzId: 'i-bogen',
      wertSilber: 80,
    ),
    HeroInventoryEntry(
      gegenstand: 'Pfeil',
      anzahl: '12',
      menge: 12,
      source: InventoryItemSource.geschoss,
      sourceRef: 'w:Kurzbogen|p:Pfeil',
      slotRef: 'w#w2|p#p1',
      instanzId: 'i-pfeil',
    ),
    HeroInventoryEntry(
      gegenstand: 'Helm',
      source: InventoryItemSource.ruestung,
      sourceRef: 'a:Helm',
      slotRef: 'a#a1',
      instanzId: 'i-h',
    ),
  ],
);

String _neueId() => 'neu';

HeroInventoryEntry? _eintrag(HeroSheet held, String id) =>
    held.inventoryEntries.where((e) => e.instanzId == id).firstOrNull;

HeroInventoryEntry _gespeichert(String id) => _eintrag(_held, id)!;

void main() {
  test('der Vorschlag ist der volle Wert pro Stück', () {
    expect(verkaufbareStueckzahl(_fackeln), 5);
    expect(verkaufsvorschlagKreuzer(_fackeln, 3), 600);
  });

  test('ein Teil des Stapels: Menge sinkt, Geld steigt', () {
    final held = mitVerkauftemGegenstand(
      _held,
      _fackeln,
      anzahl: 3,
      erloesKreuzer: 600,
      neueId: _neueId,
    );

    expect(_eintrag(held, 'f')!.menge, 2);
    expect(_eintrag(held, 'f')!.anzahl, '2');
    expect(held.dukaten, '10,6');
  });

  test('der ganze Stapel verschwindet', () {
    final held = mitVerkauftemGegenstand(
      _held,
      _fackeln,
      anzahl: 5,
      erloesKreuzer: 0,
      neueId: _neueId,
    );

    expect(_eintrag(held, 'f'), isNull);
    expect(held.dukaten, '10');
  });

  test('Pfeile am Bogen: der Bestand sinkt, bei 0 bleibt alles stehen', () {
    final held = mitVerkauftemGegenstand(
      _held,
      _gespeichert('i-pfeil'),
      anzahl: 12,
      erloesKreuzer: 100,
      neueId: _neueId,
    );

    final bogen = held.combatConfig.weaponSlots[1];
    expect(bogen.rangedProfile.projectiles.single.count, 0);
    expect(_eintrag(held, 'i-pfeil')!.menge, 0);
  });

  test('ein ausgerüsteter Bogen verlässt den Kampfbereich, Pfeile bleiben', () {
    final held = mitVerkauftemGegenstand(
      _held,
      _gespeichert('i-bogen'),
      anzahl: 1,
      erloesKreuzer: 8000,
      neueId: _neueId,
    );

    expect(held.combatConfig.weaponSlots.map((w) => w.name), ['Schwert']);
    expect(_eintrag(held, 'i-bogen'), isNull);
    final pfeile = _eintrag(held, 'i-pfeil')!;
    expect(pfeile.sourceRef, isNull);
    expect(pfeile.menge, 12);
    expect(pfeile.abgelegt!.geschoss, isNotNull);
    expect(held.dukaten, '18');
  });

  test('ein ausgerüsteter Helm verlässt die Rüstung', () {
    final held = mitVerkauftemGegenstand(
      _held,
      _gespeichert('i-h'),
      anzahl: 1,
      erloesKreuzer: 0,
      neueId: _neueId,
    );

    expect(held.combatConfig.armor.pieces, isEmpty);
    expect(_eintrag(held, 'i-h'), isNull);
  });

  group('abgewiesen', () {
    test('zu viele Stück', () {
      expect(
        () => mitVerkauftemGegenstand(
          _held,
          _fackeln,
          anzahl: 6,
          erloesKreuzer: 0,
          neueId: _neueId,
        ),
        throwsStateError,
      );
    });

    test('unlesbarer Geldstand', () {
      expect(
        () => mitVerkauftemGegenstand(
          _held.copyWith(dukaten: 'ein Beutel'),
          _fackeln,
          anzahl: 1,
          erloesKreuzer: 200,
          neueId: _neueId,
        ),
        throwsStateError,
      );
    });

    test('inzwischen geändert', () {
      final anders = _held.copyWith(
        inventoryEntries: [
          _fackeln.copyWith(woGetragen: 'Rucksack'),
          ..._held.inventoryEntries.skip(1),
        ],
      );
      expect(
        () => mitVerkauftemGegenstand(
          anders,
          _fackeln,
          anzahl: 1,
          erloesKreuzer: 0,
          neueId: _neueId,
        ),
        throwsStateError,
      );
    });
  });
}
