import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_orientieren_rules.dart';

void main() {
  test('Kriegskunst erleichtert nur mit vollständigen positiven Paaren', () {
    for (final entry in {-2: 0, 0: 0, 1: 0, 2: 1, 5: 2}.entries) {
      final plan = orientierungsplan(
        intuition: 13,
        kriegskunst: entry.key,
        aufmerksamkeit: false,
      );
      expect(plan.dauer, 2);
      expect(plan.probe!.targets.single.value, 13 + entry.value);
    }
    final aufmerksam = orientierungsplan(
      intuition: 13,
      kriegskunst: 5,
      aufmerksamkeit: true,
    );
    expect(aufmerksam.dauer, 1);
    expect(aufmerksam.probe, isNull);
  });
  test('Orientieren erhält geschützte Verluste und fixierten Rundenbonus', () {
    const s = Gefechtszustand(
      iniWurf: 1,
      iniVerlust: 4,
      geschuetzterIniVerlust: 3,
      ungeklaerterIniVerlust: 2,
      fixierterIniBonus: 1,
    );
    final nach = uebernimmOrientierung(s, maximum: 12, erfolg: true);
    expect(nach.iniWurf, 12);
    expect(nach.iniVerlust, 0);
    expect(nach.geschuetzterIniVerlust, 3);
    expect(nach.ungeklaerterIniVerlust, 2);
    expect(nach.fixierterIniBonus, 1);
    expect(uebernimmOrientierung(s, maximum: 6, erfolg: false), same(s));
  });
  test('Position beendet Desorientierung auch bei gescheiterter IN-Probe', () {
    const s = Gefechtszustand(iniWurf: 1, iniVerlust: 4, desorientiert: true);
    final nach = uebernimmOrientierung(
      s,
      maximum: 6,
      erfolg: false,
      position: true,
    );
    expect(nach.desorientiert, false);
    expect(nach.iniVerlust, 4);
    expect(nach.iniWurf, 1);
  });
}
