import 'package:dsa_heldenverwaltung/domain/trefferzonen.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/trefferzonen_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('humanoidTrefferzonenTabelle', () {
    test('deckt den gesamten W20-Bereich 1–20 ab', () {
      for (var roll = 1; roll <= 20; roll++) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        );
        expect(ergebnis, isNotNull, reason: 'Roll $roll hat kein Ergebnis');
      }
    });

    test('Beine: 1–6', () {
      for (var roll = 1; roll <= 6; roll++) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        )!;
        expect(ergebnis.eintrag.label, 'Beine');
        expect(ergebnis.eintrag.gezielterSchlagMod, 2);
      }
    });

    test('Bauch: 7–8', () {
      for (var roll = 7; roll <= 8; roll++) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        )!;
        expect(ergebnis.label, 'Bauch');
        expect(ergebnis.zone, WundZone.bauch);
        expect(ergebnis.eintrag.gezielterSchlagMod, 4);
      }
    });

    test('Arme: 9–14', () {
      for (var roll = 9; roll <= 14; roll++) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        )!;
        expect(ergebnis.eintrag.label, 'Arme');
      }
    });

    test('Brust: 15–18', () {
      for (var roll = 15; roll <= 18; roll++) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        )!;
        expect(ergebnis.label, 'Brust');
        expect(ergebnis.zone, WundZone.brust);
        expect(ergebnis.eintrag.gezielterSchlagMod, 6);
      }
    });

    test('Kopf: 19–20', () {
      for (var roll = 19; roll <= 20; roll++) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        )!;
        expect(ergebnis.label, 'Kopf');
        expect(ergebnis.zone, WundZone.kopf);
        expect(ergebnis.eintrag.gezielterSchlagMod, 4);
      }
    });
  });

  group('Subzonen-Aufloesung', () {
    test('Arme: ungerade = Schildarm (linkerArm)', () {
      for (final roll in [9, 11, 13]) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        )!;
        expect(ergebnis.zone, WundZone.linkerArm);
        expect(ergebnis.label, 'Schildarm');
      }
    });

    test('Arme: gerade = Schwertarm (rechterArm)', () {
      for (final roll in [10, 12, 14]) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        )!;
        expect(ergebnis.zone, WundZone.rechterArm);
        expect(ergebnis.label, 'Schwertarm');
      }
    });

    test('Beine: ungerade = linkes Bein', () {
      for (final roll in [1, 3, 5]) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        )!;
        expect(ergebnis.zone, WundZone.linkesBein);
        expect(ergebnis.label, 'Linkes Bein');
      }
    });

    test('Beine: gerade = rechtes Bein', () {
      for (final roll in [2, 4, 6]) {
        final ergebnis = resolveTrefferzone(
          roll: roll,
          tabelle: humanoidTrefferzonenTabelle,
        )!;
        expect(ergebnis.zone, WundZone.rechtesBein);
        expect(ergebnis.label, 'Rechtes Bein');
      }
    });
  });

  group('rollModifier', () {
    test('positiver Modifier verschiebt Ergebnis nach oben', () {
      final tabelle = TrefferzonenTabelle(
        name: 'Test',
        eintraege: humanoidTrefferzonenTabelle.eintraege,
        rollModifier: 2,
      );
      // Roll 5 + Modifier 2 = 7 → Bauch
      final ergebnis = resolveTrefferzone(roll: 5, tabelle: tabelle)!;
      expect(ergebnis.label, 'Bauch');
      expect(ergebnis.roll, 5);
      expect(ergebnis.effektiverRoll, 7);
    });

    test('negativer Modifier verschiebt Ergebnis nach unten', () {
      final tabelle = TrefferzonenTabelle(
        name: 'Test',
        eintraege: humanoidTrefferzonenTabelle.eintraege,
        rollModifier: -10,
      );
      // Roll 15 + Modifier -10 = 5 → Beine
      final ergebnis = resolveTrefferzone(roll: 15, tabelle: tabelle)!;
      expect(ergebnis.eintrag.label, 'Beine');
      expect(ergebnis.effektiverRoll, 5);
    });

    test('Clamping nach oben auf 20', () {
      final tabelle = TrefferzonenTabelle(
        name: 'Test',
        eintraege: humanoidTrefferzonenTabelle.eintraege,
        rollModifier: 5,
      );
      // Roll 20 + Modifier 5 = 25, geclampt auf 20 → Kopf
      final ergebnis = resolveTrefferzone(roll: 20, tabelle: tabelle)!;
      expect(ergebnis.effektiverRoll, 20);
      expect(ergebnis.label, 'Kopf');
    });

    test('Clamping nach unten auf 1', () {
      final tabelle = TrefferzonenTabelle(
        name: 'Test',
        eintraege: humanoidTrefferzonenTabelle.eintraege,
        rollModifier: -5,
      );
      // Roll 1 + Modifier -5 = -4, geclampt auf 1 → Beine
      final ergebnis = resolveTrefferzone(roll: 1, tabelle: tabelle)!;
      expect(ergebnis.effektiverRoll, 1);
      expect(ergebnis.eintrag.label, 'Beine');
    });
  });

  group('Randwerte', () {
    test('Roll 1 → Beine', () {
      final ergebnis = resolveTrefferzone(
        roll: 1,
        tabelle: humanoidTrefferzonenTabelle,
      )!;
      expect(ergebnis.eintrag.label, 'Beine');
    });

    test('Roll 20 → Kopf', () {
      final ergebnis = resolveTrefferzone(
        roll: 20,
        tabelle: humanoidTrefferzonenTabelle,
      )!;
      expect(ergebnis.label, 'Kopf');
    });

    test('effektiverRoll entspricht roll ohne Modifier', () {
      final ergebnis = resolveTrefferzone(
        roll: 12,
        tabelle: humanoidTrefferzonenTabelle,
      )!;
      expect(ergebnis.roll, 12);
      expect(ergebnis.effektiverRoll, 12);
    });
  });
}
