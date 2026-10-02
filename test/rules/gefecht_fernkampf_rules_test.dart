import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_distance_band.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fernkampf_rules.dart';

void main() {
  const bands = [
    RangedDistanceBand(label: '5'),
    RangedDistanceBand(label: '10'),
    RangedDistanceBand(label: '20'),
    RangedDistanceBand(label: '40'),
    RangedDistanceBand(label: '80'),
  ];
  test(
    'Entfernungsgrenzen sind inklusive; ungültiges Profil bleibt unbekannt',
    () {
      expect(gefechtsEntfernungsband(bands, 5), 0);
      expect(gefechtsEntfernungsband(bands, 6), 1);
      expect(gefechtsEntfernungsband(bands, 80), 4);
      expect(gefechtsEntfernungsband(bands, 81), -1);
      expect(
        gefechtsEntfernungsband([
          const RangedDistanceBand(label: 'Distanz 1'),
        ], 2),
        isNull,
      );
    },
  );
  test('Hausregel Getümmel berücksichtigt Schützen-SF', () {
    expect(gefechtsGetuemmelZuschlag(), 3);
    expect(gefechtsGetuemmelZuschlag(scharfschuetze: true), 2);
    expect(gefechtsGetuemmelZuschlag(meisterschuetze: true), 1);
    expect(gefechtsGetuemmelZuschlag(waffenmeister: true), 0);
  });
}
