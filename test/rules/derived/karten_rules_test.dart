import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';

void main() {
  test('kartenRoutenPunkte: nur Stationen mit Position, Nummer der Etappe', () {
    final etappen = reiseEtappen(const <HeroReiseStation>[
      HeroReiseStation(id: 'a', ort: 'Gareth', kartenX: 551, kartenY: 533),
      HeroReiseStation(id: 'b', ort: 'Irgendwo'),
      HeroReiseStation(id: 'c', ort: 'Punin', kartenX: 470, kartenY: 380),
    ]);
    final punkte = kartenRoutenPunkte(etappen);
    expect(punkte.map((p) => p.station.id), <String>['a', 'c']);
    expect(punkte.map((p) => p.nummer), <int>[1, 3]);
    expect(punkte.last.x, 470);
    expect(punkte.last.y, 380);
  });

  group('kartenAusschnitt', () {
    test('ohne Punkte der Ersatz', () {
      const ersatz = KartenRechteck(10, 20, 30, 40);
      expect(kartenAusschnitt(const [], ohnePunkte: ersatz), ersatz);
      expect(kartenAusschnitt(const []), kKartenWelt);
    });

    test('ein Punkt bekommt die Mindestgröße', () {
      final r = kartenAusschnitt(const [(500, 500)]);
      expect(r.mitteX, 500);
      expect(r.mitteY, 500);
      expect(r.breite, kKartenAusschnittMindestKante);
      expect(r.hoehe, kKartenAusschnittMindestKante);
    });

    test('weit verteilte Punkte bekommen den Rand dazu', () {
      final r = kartenAusschnitt(const [(100, 200), (500, 300)], rand: 10);
      expect(r.minX, 90);
      expect(r.maxX, 510);
      // Die Höhe (100 + Rand) liegt unter der Mindestkante.
      expect(r.hoehe, kKartenAusschnittMindestKante + 40);
    });
  });

  test('kartenBegrenzung umschließt alle Orte, ohne Orte die ganze Karte', () {
    expect(kartenBegrenzung(const []), kKartenWelt);
    final r = kartenBegrenzung(const <AvesmapsOrt>[
      AvesmapsOrt(id: '1', name: 'A', x: 16.5, y: 12.75),
      AvesmapsOrt(id: '2', name: 'B', x: 875, y: 1022.25),
    ]);
    expect(r, const KartenRechteck(16.5, 12.75, 875, 1022.25));
  });
}
