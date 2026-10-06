import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_instanz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_stapel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';

// Stapel teilen (ARCH-03, Entscheidung vom 06.10.2026): Teilen spaltet einen
// neuen, unverknüpften Stapel mit neuer Instanz-ID ab; bei Geschossen sinkt
// die Menge am eigenen Slot.

const _held = HeroSheet(
  id: 'held',
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

const _trank = HeroInventoryEntry(
  gegenstand: 'Heiltrank',
  anzahl: '5',
  menge: 5,
  woGetragen: 'Gürteltasche',
  itemType: InventoryItemType.verbrauchsgegenstand,
  isMagisch: true,
  magischDescription: 'Heilt 2W6 LeP',
  instanzId: 'trank',
  unbekannteFelder: {'zukunftsfeld': 1},
);
const _seil = HeroInventoryEntry(
  gegenstand: 'Seil',
  anzahl: '1',
  menge: 1,
  instanzId: 'seil',
);

MainWeaponSlot _bogen(String id, int pfeile) => MainWeaponSlot(
  id: id,
  name: 'Kurzbogen',
  combatType: WeaponCombatType.ranged,
  rangedProfile: RangedWeaponProfile(
    projectiles: [RangedProjectile(id: 'p', name: 'Pfeil', count: pfeile)],
  ),
);

// Zwei gleichnamige Bögen; gespeichert wie nach `saveHero`.
HeroSheet _schuetze() {
  final config = CombatConfig(weapons: [_bogen('a', 10), _bogen('b', 20)]);
  var nr = 0;
  return _held.copyWith(
    combatConfig: config,
    inventoryEntries: vergibInstanzIds(
      ueberfuehreInventarMengen(
        reconcileInventoryWithCombat(const [_seil], config),
      ),
      neueId: () => 'i${nr++}',
    ),
  );
}

HeroInventoryEntry _pfeileVonBogen(HeroSheet held, String bogenId) =>
    held.inventoryEntries.singleWhere((e) => e.slotRef == 'w#$bogenId|p#p');

int _zahlAmSlot(HeroSheet held, int bogen) =>
    held.combatConfig.weaponSlots[bogen].rangedProfile.projectiles.single.count;

void main() {
  group('stapelTeilbar', () {
    test('nur bei bekannter Menge ab 2', () {
      expect(stapelTeilbar(_trank), isTrue);
      expect(stapelTeilbar(_seil), isFalse);
      expect(stapelTeilbar(_trank.copyWith(anzahl: 'ein paar')), isFalse);
      // Eine Abweichung rechnet mit der Anzahl.
      expect(stapelTeilbar(_trank.copyWith(anzahl: '1')), isFalse);
    });

    test('verknüpfte Einzelstücke nie, verknüpfte Geschosse schon', () {
      final schuetze = _schuetze();
      final bogen = schuetze.inventoryEntries.firstWhere(
        (e) => e.source == InventoryItemSource.waffe,
      );
      expect(stapelTeilbar(bogen.copyWith(anzahl: '2', menge: 2)), isFalse);
      expect(stapelTeilbar(_pfeileVonBogen(schuetze, 'b')), isTrue);
    });
  });

  group('mitGeteiltemStapel', () {
    test('spaltet einen manuellen Stapel mit neuer ID ab', () {
      final held = _held.copyWith(inventoryEntries: const [_trank, _seil]);

      final ergebnis = mitGeteiltemStapel(
        held,
        _trank,
        abspalten: 2,
        woGetragen: ' Rucksack ',
        neueId: 'neu',
      );

      final [rest, abgespalten, seil] = ergebnis.inventoryEntries;
      expect(rest.instanzId, 'trank');
      expect(wirksameInventarMenge(rest), 3);
      expect(rest.anzahl, '3');
      expect(rest.woGetragen, 'Gürteltasche');
      expect(abgespalten.instanzId, 'neu');
      expect(abgespalten.menge, 2);
      expect(abgespalten.anzahl, '2');
      expect(abgespalten.woGetragen, 'Rucksack');
      expect(abgespalten.gegenstand, 'Heiltrank');
      expect(abgespalten.isMagisch, isTrue);
      expect(abgespalten.magischDescription, 'Heilt 2W6 LeP');
      expect(abgespalten.unbekannteFelder, {'zukunftsfeld': 1});
      expect(seil, _seil);
    });

    test('Pfeile des zweiten gleichnamigen Bogens', () {
      final held = _schuetze();
      final angezeigt = _pfeileVonBogen(held, 'b');

      final ergebnis = mitGeteiltemStapel(
        held,
        angezeigt,
        abspalten: 8,
        woGetragen: 'Rucksack',
        neueId: 'neu',
      );

      expect(_zahlAmSlot(ergebnis, 0), 10);
      expect(_zahlAmSlot(ergebnis, 1), 12);
      final rest = _pfeileVonBogen(ergebnis, 'b');
      expect(rest.instanzId, angezeigt.instanzId);
      expect(rest.menge, 12);
      final abgespalten = ergebnis.inventoryEntries.singleWhere(
        (e) => e.instanzId == 'neu',
      );
      expect(abgespalten.source, InventoryItemSource.manuell);
      expect(abgespalten.sourceRef, isNull);
      expect(abgespalten.slotRef, isNull);
      expect(abgespalten.istAusgeruestet, isFalse);
      expect(abgespalten.menge, 8);

      // Das Speichern gleicht ab: beide Stapel bleiben getrennt.
      final abgeglichen = ueberfuehreInventarMengen(
        reconcileInventoryWithCombat(
          ergebnis.inventoryEntries,
          ergebnis.combatConfig,
        ),
      );
      expect(
        abgeglichen.where((e) => e.gegenstand == 'Pfeil').map((e) => e.menge),
        unorderedEquals([10, 12, 8]),
      );
      expect(
        abgeglichen.singleWhere((e) => e.instanzId == 'neu').woGetragen,
        'Rucksack',
      );
    });

    test('außerhalb 1 bis Menge − 1 wird abgewiesen', () {
      final held = _held.copyWith(inventoryEntries: const [_trank]);
      for (final n in [0, 5, 6, -1]) {
        expect(
          () => mitGeteiltemStapel(
            held,
            _trank,
            abspalten: n,
            woGetragen: '',
            neueId: 'neu',
          ),
          throwsStateError,
          reason: 'abspalten: $n',
        );
      }
    });

    test('ein inzwischen geänderter Stapel wird abgewiesen', () {
      final held = _held.copyWith(
        inventoryEntries: [mitInventarMenge(_trank, 4)],
      );
      expect(
        () => mitGeteiltemStapel(
          held,
          _trank,
          abspalten: 2,
          woGetragen: '',
          neueId: 'neu',
        ),
        throwsStateError,
      );
    });
  });

  group('findeInventarEintragZurAenderung', () {
    test('trifft über die Instanz-ID, nicht über die Position', () {
      final zweiter = _trank.copyWith(instanzId: 'trank-2');
      final eintraege = [_seil, zweiter, _trank];
      expect(findeInventarEintragZurAenderung(eintraege, _trank), 2);
      expect(findeInventarEintragZurAenderung(eintraege, zweiter), 1);
    });

    test('mit gleicher ID, aber anderem Inhalt: -1', () {
      final eintraege = [mitInventarMenge(_trank, 4)];
      expect(findeInventarEintragZurAenderung(eintraege, _trank), -1);
    });

    test('ohne ID über den Inhalt', () {
      const ohneId = HeroInventoryEntry(gegenstand: 'Fackel', anzahl: '3');
      final eintraege = [_seil, ohneId.copyWith(instanzId: 'f', menge: 3)];
      expect(findeInventarEintragZurAenderung(eintraege, ohneId), 1);
    });
  });
}
