import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_freigabe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_klingen_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

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

  // Review R7: der Knopf darf nicht „Klären“ ohne sichtbaren Grund zeigen.
  for (final id in ['man_klingenwand', 'man_klingensturm']) {
    test('$id: Klären nur mit Grund, Hinweise allein ergeben Bereit', () {
      const config = CombatConfig(
        weapons: [
          MainWeaponSlot(id: 'w1', name: 'Schwert', distanceClass: 'N'),
        ],
        specialRules: CombatSpecialRules(
          activeManeuvers: ['man_klingenwand', 'man_klingensturm'],
        ),
      );
      final snap = buildHeroComputedSnapshot(
        hero: testHero().copyWith(combatConfig: config),
        state: const HeroState.empty(),
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      final p = pruefeGefechtsKlingenbeginn(
        const Gefechtszustand(iniWurf: 6, dk: 'N'),
        snap,
        testCatalog,
        ManeuverDef(
          id: id,
          name: id,
          typ: id == 'man_klingenwand' ? 'Abwehraktion' : 'Angriffsaktion',
        ),
        kampfmittel: const GefechtsKampfmittelwahl(
          GefechtsKampfmittelArt.hauptwaffe,
          'w1',
        ),
      );
      if (p.status == Gefechtsfreigabe.pruefen) {
        expect(gefechtsHauptgrund(p), isNotNull);
      }
      expect(p.status, Gefechtsfreigabe.bereit);
      expect(p.hinweise, isNotEmpty);
    });
  }
}
