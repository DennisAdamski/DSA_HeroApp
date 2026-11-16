import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_beschriftung.dart';

BeschriftungsWunsch _w(String id, double x, double y, {double breite = 40}) =>
    BeschriftungsWunsch(
      schluessel: id,
      anker: Offset(x, y),
      abstand: 4,
      groesse: Size(breite, 12),
    );

void main() {
  test('Namen stehen rechts der Marke', () {
    final gesetzt = setzeBeschriftungen(<BeschriftungsWunsch>[
      _w('a', 100, 100),
    ]);
    expect(gesetzt.single.flaeche, const Rect.fromLTWH(104, 94, 40, 12));
  });

  test('ist rechts belegt, weicht der Name nach links aus', () {
    final gesetzt = setzeBeschriftungen(<BeschriftungsWunsch>[
      _w('gross', 100, 100),
      _w('klein', 98, 100),
    ]);
    expect(gesetzt, hasLength(2));
    expect(gesetzt[1].flaeche.right, lessThanOrEqualTo(98));
  });

  test('ohne Platz entfällt der unbedeutendere Name', () {
    final gesetzt = setzeBeschriftungen(<BeschriftungsWunsch>[
      _w('gross', 100, 100, breite: 200),
      _w('mitte', 140, 101, breite: 200),
      _w('klein', 110, 102),
    ]);
    final ids = gesetzt.map((g) => g.wunsch.schluessel).toList();
    expect(ids.first, 'gross');
    expect(ids, isNot(contains('klein')));
    for (var i = 0; i < gesetzt.length; i++) {
      for (var j = i + 1; j < gesetzt.length; j++) {
        expect(gesetzt[i].flaeche.overlaps(gesetzt[j].flaeche), isFalse);
      }
    }
  });

  test('freizuhaltende Flächen bleiben frei', () {
    final gesetzt = setzeBeschriftungen(
      <BeschriftungsWunsch>[_w('a', 100, 100)],
      frei: <Rect>[const Rect.fromLTWH(100, 90, 60, 20)],
    );
    expect(gesetzt.single.flaeche.right, lessThanOrEqualTo(100));
  });

  test('mit Bildgrenze nur Namen, die ganz hineinpassen', () {
    final gesetzt = setzeBeschriftungen(<BeschriftungsWunsch>[
      _w('rand', 395, 100),
    ], bild: const Rect.fromLTWH(0, 0, 400, 300));
    expect(gesetzt.single.flaeche.left, lessThan(395));
  });
}
