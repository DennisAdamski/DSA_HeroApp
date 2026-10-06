import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';

// Strukturierte Menge (ARCH-03, Entscheidung vom 06.10.2026): eine reine Zahl
// wird zur Menge, Leeres und Freitext bleiben offen, und weicht `anzahl` von
// `menge` ab, hat eine ältere Version geändert: `anzahl` gilt.

HeroInventoryEntry _e(String anzahl, {int? menge}) =>
    HeroInventoryEntry(gegenstand: 'Pfeil', anzahl: anzahl, menge: menge);

void main() {
  group('inventarMengenstand', () {
    final faelle = <(String, int?, int?, int?)>[
      // anzahl, menge -> wirksam, ueberholteMenge
      ('20', null, 20, null),
      (' 7 ', null, 7, null),
      ('020', 20, 20, null),
      ('', null, null, null),
      ('ein paar', null, null, null),
      ('-3', null, null, null),
      ('+3', null, null, null),
      ('2x', null, null, null),
      ('5', 5, 5, null),
      // Eine ältere Version hat die Anzahl geändert.
      ('3', 5, 3, 5),
      ('vier kleine', 4, null, 4),
      ('', 4, null, 4),
    ];
    for (final (anzahl, menge, wirksam, ueberholt) in faelle) {
      test('anzahl "$anzahl", menge $menge', () {
        final stand = inventarMengenstand(_e(anzahl, menge: menge));
        expect(stand.wirksam, wirksam);
        expect(stand.ueberholteMenge, ueberholt);
        expect(stand.offen, wirksam == null);
        expect(stand.abweichend, ueberholt != null);
        expect(wirksameInventarMenge(_e(anzahl, menge: menge)), wirksam);
      });
    }
  });

  test('mitInventarMenge schreibt Menge und Text gemeinsam', () {
    final neu = mitInventarMenge(_e('ein paar'), 12);
    expect(neu.menge, 12);
    expect(neu.anzahl, '12');
    expect(neu.toJson()['menge'], 12);
  });

  group('mitInventarMengeAusText', () {
    test('eine Zahl wird zur Menge', () {
      final neu = mitInventarMengeAusText(_e(''), ' 9 ');
      expect(neu.menge, 9);
      expect(neu.anzahl, '9');
    });

    test('Freitext bleibt offen und verwirft die Menge', () {
      final neu = mitInventarMengeAusText(_e('4', menge: 4), 'ein paar');
      expect(neu.menge, isNull);
      expect(neu.anzahl, 'ein paar');
      expect(neu.toJson().containsKey('menge'), isFalse);
    });

    test('unverändert kommt derselbe Eintrag zurück', () {
      final altdaten = _e('20');
      expect(
        identical(mitInventarMengeAusText(altdaten, '20'), altdaten),
        isTrue,
      );
      final passend = _e('5', menge: 5);
      expect(identical(mitInventarMengeAusText(passend, '5'), passend), isTrue);
    });

    test('Speichern einer Abweichung übernimmt die Anzahl', () {
      final neu = mitInventarMengeAusText(_e('3', menge: 5), '3');
      expect(neu.menge, 3);
      expect(neu.anzahl, '3');
      expect(inventarMengenstand(neu).abweichend, isFalse);
    });
  });

  group('ueberfuehreInventarMengen', () {
    test('nur reine Zahlen ohne Menge werden überführt', () {
      final eintraege = [
        _e('20'),
        _e(''),
        _e('ein paar'),
        _e('5', menge: 5),
        _e('3', menge: 5),
      ];
      final ergebnis = ueberfuehreInventarMengen(eintraege);
      expect(ergebnis.map((e) => e.menge), [20, null, null, 5, 5]);
      // Der Text bleibt, wie er war; nur `menge` kommt dazu.
      expect(ergebnis.map((e) => e.anzahl), ['20', '', 'ein paar', '5', '3']);
      // Die Abweichung wird nicht still aufgelöst.
      expect(inventarMengenstand(ergebnis[4]).abweichend, isTrue);
    });

    test('ist ein Fixpunkt und liefert ohne Änderung dieselbe Liste', () {
      final einmal = ueberfuehreInventarMengen([_e('20'), _e('')]);
      expect(identical(ueberfuehreInventarMengen(einmal), einmal), isTrue);
      final ohne = [_e(''), _e('x')];
      expect(identical(ueberfuehreInventarMengen(ohne), ohne), isTrue);
    });
  });
}
