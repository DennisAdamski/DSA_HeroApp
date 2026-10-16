import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_stapel_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/sync_geraete.dart';

// S7 Inventar (ARCH-03): Teilen und Bearbeiten gleichnamiger Stapel auf zwei
// Geräten. Geschrieben wird über `HeroActions.updateHero` wie in der App;
// f06 trägt zwei gleichnamige Kurzbögen mit je einem Jagdpfeil-Vorrat.

const String _id = 'bestand-f06';

// Ändert den Helden über den Schreibweg der App auf [geraet].
Future<void> _aendere(
  SyncTestGeraet geraet,
  HeroSheet Function(HeroSheet held) aenderung,
) async {
  final container = ProviderContainer(
    overrides: [heroRepositoryProvider.overrideWithValue(geraet.repo)],
  );
  addTearDown(container.dispose);
  await container.read(heroActionsProvider).updateHero(_id, aenderung);
}

// Verknüpfter Pfeilvorrat, dessen Beschreibung mit [beschreibung] beginnt.
HeroInventoryEntry _vorrat(HeroSheet held, String beschreibung) =>
    held.inventoryEntries.singleWhere(
      (e) =>
          e.source == InventoryItemSource.geschoss &&
          e.beschreibung.startsWith(beschreibung),
    );

// Pfeile an beiden Bögen in Slot-Reihenfolge.
List<int> _pfeileAnBoegen(HeroSheet held) => [
  for (final slot in held.combatConfig.weaponSlots)
    if (slot.fuehrtGeschosse) slot.rangedProfile.projectiles.single.count,
];

// Teilt 5 Pfeile vom rechten Köcher in den Rucksack ab.
HeroSheet _teileRechts(HeroSheet held) => mitGeteiltemStapel(
  held,
  _vorrat(held, 'Köcher rechts'),
  abspalten: 5,
  woGetragen: 'Rucksack',
  neueId: 'rucksack-pfeile',
);

// Beschreibt den linken, gleichnamigen Köcher neu.
HeroSheet _beschreibeLinks(HeroSheet held) {
  final links = _vorrat(held, 'Köcher links');
  return mitGeaendertemInventarEintrag(
    held,
    links,
    links.copyWith(beschreibung: 'Köcher links, geflickt'),
  );
}

Future<HeroSheet> _held(SyncTestGeraet geraet) async =>
    (await geraet.lokal.loadHeroById(_id))!;

void main() {
  late GeteilteCloud cloud;
  late SyncTestGeraet a;
  late SyncTestGeraet b;

  // Gemeinsamer Stand nach dem ersten Speichern: IDs und Mengen vergeben.
  Future<void> gemeinsamerStart() async {
    cloud = GeteilteCloud();
    a = SyncTestGeraet(cloud);
    b = SyncTestGeraet(cloud);
    final bundle = ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung);
    await a.repo.saveHero(bundle.hero);
    await a.repo.saveHeroState(_id, bundle.state);
    await _aendere(a, (held) => held.copyWith(dukaten: '12'));
    await a.repo.syncNow();
    await b.repo.syncNow();
  }

  test('ein geteilter Stapel kommt mit IDs und Mengen an', () async {
    await gemeinsamerStart();
    expect(
      (await _held(b)).inventoryEntries.every((e) => e.instanzId != null),
      isTrue,
    );

    await _aendere(a, _teileRechts);
    await a.repo.syncNow();
    await b.repo.syncNow();

    final beiA = await _held(a);
    final beiB = await _held(b);
    expect(a.konflikte, isEmpty);
    expect(b.konflikte, isEmpty);
    expect(
      beiB.inventoryEntries.map((e) => e.toJson()).toList(),
      beiA.inventoryEntries.map((e) => e.toJson()).toList(),
    );
    expect(_pfeileAnBoegen(beiB), [20, 7]);
    final rucksack = beiB.inventoryEntries.singleWhere(
      (e) => e.instanzId == 'rucksack-pfeile',
    );
    expect((rucksack.menge, rucksack.woGetragen), (5, 'Rucksack'));
    expect(_vorrat(beiB, 'Köcher rechts').menge, 7);
    expect(_vorrat(beiB, 'Köcher links').menge, 20);

    final vorher = cloud.schreibvorgaenge;
    await a.repo.syncNow();
    await b.repo.syncNow();
    expect(cloud.schreibvorgaenge, vorher, reason: 'danach Ruhe');
  });

  group('gleichzeitig geändert', () {
    // A teilt den rechten Köcher, B beschreibt den linken; A ist zuerst
    // wieder online. [aBeschreibt] lässt A zusätzlich denselben linken
    // Köcher anders beschreiben — erst das ist ein echter Konflikt.
    Future<void> konkurrierend({bool aBeschreibt = false}) async {
      await gemeinsamerStart();
      a.remote.offline = true;
      b.remote.offline = true;
      await _aendere(a, _teileRechts);
      if (aBeschreibt) {
        await _aendere(a, (held) {
          final links = _vorrat(held, 'Köcher links');
          return mitGeaendertemInventarEintrag(
            held,
            links,
            links.copyWith(beschreibung: 'Köcher links, neu'),
          );
        });
      }
      await _aendere(b, _beschreibeLinks);
      a.remote.offline = false;
      b.remote.offline = false;
      await a.repo.syncNow();
      await b.repo.syncNow();
    }

    test('verschiedene Änderungen werden ohne Konflikt zusammengeführt '
        '(ARCH-06)', () async {
      await konkurrierend();
      await a.repo.syncNow();

      expect(a.konflikte, isEmpty);
      expect(b.konflikte, isEmpty);
      expect(await a.heldHash(_id), await b.heldHash(_id));
      final held = await _held(a);
      expect(_pfeileAnBoegen(held), [20, 7]);
      expect(
        held.inventoryEntries.any((e) => e.instanzId == 'rucksack-pfeile'),
        isTrue,
      );
      expect(
        _vorrat(held, 'Köcher links').beschreibung,
        'Köcher links, geflickt',
      );
    });

    test('ein widersprüchlich geänderter Wert ergibt einen sichtbaren '
        'Konflikt, der nur ihn nennt', () async {
      await konkurrierend(aBeschreibt: true);

      expect(a.konflikte, isEmpty);
      expect(b.konflikte.map((k) => k.id), ['hero-$_id']);
      final vorschau = (await b.repo.konfliktVorschau('hero-$_id'))!;
      expect(vorschau.felder, hasLength(1));
      expect(vorschau.felder.single.lokal, 'Köcher links, geflickt');
      expect(vorschau.felder.single.online, 'Köcher links, neu');
      expect(vorschau.vonOnline, greaterThan(0));
      // Bis zur Entscheidung behält B seine Fassung.
      final beiB = await _held(b);
      expect(
        _vorrat(beiB, 'Köcher links').beschreibung,
        'Köcher links, geflickt',
      );
      expect(_pfeileAnBoegen(beiB), [20, 12]);
    });

    test('Automatisch übernimmt die Teilung und fragt nur nach der '
        'Beschreibung', () async {
      await konkurrierend(aBeschreibt: true);
      final feld = (await b.repo.konfliktVorschau('hero-$_id'))!.felder.single;

      await expectLater(
        b.repo.resolveConflictAutomatisch('hero-$_id', const {}),
        throwsA(isA<StateError>()),
      );
      await b.repo.resolveConflictAutomatisch('hero-$_id', {
        feld.schluessel: SyncSeite.lokal,
      });
      await a.repo.syncNow();
      await b.repo.syncNow();

      expect(a.konflikte, isEmpty);
      expect(b.konflikte, isEmpty);
      expect(await a.heldHash(_id), await b.heldHash(_id));
      final held = await _held(a);
      expect(_pfeileAnBoegen(held), [20, 7]);
      expect(
        _vorrat(held, 'Köcher links').beschreibung,
        'Köcher links, geflickt',
      );
    });

    for (final wahl in SyncResolutionChoice.values) {
      test('${wahl.name}: nichts geht still verloren', () async {
        await konkurrierend(aBeschreibt: true);

        await b.repo.resolveConflict(b.konflikte.single.id, wahl);
        await a.repo.syncNow();
        await b.repo.syncNow();

        expect(a.konflikte, isEmpty);
        expect(b.konflikte, isEmpty);
        expect(await a.heldHash(_id), await b.heldHash(_id));
        final held = await _held(b);
        final online = wahl != SyncResolutionChoice.keepLocal;
        expect(_pfeileAnBoegen(held), online ? [20, 7] : [20, 12]);
        expect(
          held.inventoryEntries.any((e) => e.instanzId == 'rucksack-pfeile'),
          online,
        );
        expect(
          _vorrat(held, 'Köcher links').beschreibung,
          online ? 'Köcher links, neu' : 'Köcher links, geflickt',
        );
        if (wahl == SyncResolutionChoice.keepBoth) {
          // Die lokale Kopie trägt Bs Fassung samt Instanz-IDs.
          final kopie = (await b.lokal.listHeroes()).singleWhere(
            (h) => h.name.endsWith('(lokale Kopie)'),
          );
          expect(
            _vorrat(kopie, 'Köcher links').beschreibung,
            'Köcher links, geflickt',
          );
          expect(
            kopie.inventoryEntries.map((e) => e.instanzId),
            (await _held(b)).inventoryEntries
                .where((e) => e.instanzId != 'rucksack-pfeile')
                .map((e) => e.instanzId),
          );
        }
      });
    }
  });
}
