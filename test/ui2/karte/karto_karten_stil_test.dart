import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_stil.dart';

// Die Zoomtafeln stammen aus dem Designkanon von Avesmaps; geprüft wird, wie
// die Karte sie liest.

void main() {
  test('Werte auf dem Band entsprechen der Tafel', () {
    expect(markerDurchmesser('metropole', 0), 6.65);
    expect(markerDurchmesser('stadt', 6), 31.92);
    expect(beschriftungsGroesse('metropole', 4), closeTo(17 * 4 / 3, 1e-9));
  });

  test('zwischen zwei Bändern wird linear gemittelt', () {
    expect(
      markerDurchmesser('metropole', 0.5),
      closeTo((6.65 + 9.4) / 2, 1e-9),
    );
  });

  test('vor dem ersten belegten Band bleibt eine Klasse unsichtbar', () {
    expect(markerDurchmesser('dorf', 1.9), isNull);
    expect(markerDurchmesser('dorf', 2), 1.33);
    expect(beschriftungsGroesse('dorf', 3.99), isNull);
    expect(beschriftungsGroesse('dorf', 4), isNotNull);
    expect(beschriftungsGroesse('gebaeude', 8), closeTo(9 * 4 / 3, 1e-9));
  });

  test('unbekannte Klassen zeichnen wie ein Dorf', () {
    expect(markerDurchmesser('ruine', 5), markerDurchmesser('dorf', 5));
  });

  test('Goldring ab Band 3, Raute für Bauwerke ab Band 4', () {
    expect(markenForm('metropole', 2.9, 18), KartenMarkenForm.kreis);
    expect(markenForm('metropole', 3, 18.81), KartenMarkenForm.hauptstadt);
    expect(markenForm('metropole', 3, 10), KartenMarkenForm.kreis);
    expect(markenForm('gebaeude', 3.5, 2), KartenMarkenForm.kreis);
    expect(markenForm('gebaeude', 4, 2.8), KartenMarkenForm.raute);
    expect(markenForm('stadt', 7, 30), KartenMarkenForm.kreis);
  });

  test('Vorrang: Metropole vor Dorf vor Gebäude', () {
    expect(kartenVorrang('metropole'), greaterThan(kartenVorrang('dorf')));
    expect(kartenVorrang('dorf'), greaterThan(kartenVorrang('gebaeude')));
    expect(kartenVorrang('unbekannt'), kartenVorrang('dorf'));
  });

  test('Kern, Kontur und Haarlinie füllen den Durchmesser', () {
    const aussen = 10.0;
    final kern = kernHalbmesser(aussen);
    expect(kern + kern * kKonturAnteil + kHaarlinie, closeTo(aussen, 1e-9));
  });
}
