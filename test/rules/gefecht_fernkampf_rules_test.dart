import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fernkampf_rules.dart';

void main() {
  test('Fehlende stabile Waffen-/Geschoss-ID erklärt die Schusssperre', () {
    final p = pruefeGefechtsFernkampf(
      const Gefechtszustand(iniWurf: 6),
      const MainWeaponSlot(
        combatType: WeaponCombatType.ranged,
        rangedProfile: RangedWeaponProfile(
          selectedProjectileIndex: 0,
          projectiles: [RangedProjectile(name: 'Bolzen', count: 2)],
        ),
      ),
    );
    expect(p.fehlend.join(' '), contains('Waffen-ID'));
    expect(p.fehlend.join(' '), contains('Geschoss-ID'));
  });
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
