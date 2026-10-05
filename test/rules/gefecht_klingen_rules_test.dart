import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_klingen_rules.dart';

void main() {
  test(
    'Klingenwerte halbieren aufgerundet und verbessern je Teilprobe um zwei',
    () {
      expect(gefechtsKlingenwerte(15), [10, 10]);
      expect(gefechtsKlingenwerte(13), [9, 9]);
    },
  );
  test('Kampfgespür verteilt Pool plus vier, mindestens sechs pro Gegner', () {
    expect(gefechtsKlingenwerte(18, kampfgespuer: true, verteilung: [13, 9]), [
      13,
      9,
    ]);
    expect(
      () => gefechtsKlingenwerte(18, kampfgespuer: true, verteilung: [20, 2]),
      throwsArgumentError,
    );
    expect(
      () => gefechtsKlingenwerte(18, kampfgespuer: true, verteilung: [13, 10]),
      throwsArgumentError,
    );
  });
  test('Drei Teilproben benötigen aktiven Klingentänzer', () {
    expect(
      gefechtsKlingenwerte(
        20,
        kampfgespuer: true,
        klingentaenzer: true,
        verteilung: [8, 8, 8],
      ),
      [8, 8, 8],
    );
    expect(
      () => gefechtsKlingenwerte(20, kampfgespuer: true, verteilung: [8, 8, 8]),
      throwsArgumentError,
    );
  });
}
