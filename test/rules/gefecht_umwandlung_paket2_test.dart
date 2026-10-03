import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

void main() {
  test(
    'Aktiver Klingentänzer wahrt Kampfgespür und seine eigene BE-Grenze',
    () {
      for (final be in [0, 3]) {
        final snap = buildHeroComputedSnapshot(
          hero: testHero().copyWith(
            combatConfig: CombatConfig(
              weapons: const [
                MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N'),
              ],
              armor: ArmorConfig(pieces: [ArmorPiece(be: be, isActive: true)]),
              specialRules: const CombatSpecialRules(
                klingentaenzer: true,
                kampfgespuer: true,
              ),
            ),
          ),
          state: const HeroState.empty(),
          catalog: testCatalog,
          epicAdvantagesActive: false,
        );
        final w = gefechtswerteFuer(snap);
        expect(w.klingentaenzerAktiv, be <= 2);
        expect(
          gefechtUmwandlungMoeglich(
            const Gefechtszustand(iniWurf: 6, angriffeVerbraucht: 1),
            Gefechtsumwandlung.zweiteAttacke,
            werte: w,
          ),
          isTrue,
        );
      }
      final inkonsistent = buildHeroComputedSnapshot(
        hero: testHero().copyWith(
          combatConfig: const CombatConfig(
            specialRules: CombatSpecialRules(klingentaenzer: true),
          ),
        ),
        state: const HeroState.empty(),
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      expect(
        gefechtUmwandlungMoeglich(
          const Gefechtszustand(iniWurf: 6, angriffeVerbraucht: 1),
          Gefechtsumwandlung.zweiteParade,
          werte: gefechtswerteFuer(inkonsistent),
        ),
        isFalse,
      );
    },
  );
  for (final quelle in [true, false]) {
    test(
      'Spontan umwandeln erhält verbrauchte ${quelle ? 'AT' : 'PA'} ohne Budgetgewinn',
      () {
        const w = Gefechtswerte(
          iniBasis: 14,
          at: 16,
          pa: 14,
          ausweichen: 10,
          kampfgespuer: true,
        );
        final s = Gefechtszustand(
          iniWurf: 6,
          angriffeVerbraucht: quelle ? 1 : 0,
          paradenVerbraucht: quelle ? 0 : 1,
        );
        for (final u in [
          Gefechtsumwandlung.zweiteAttacke,
          Gefechtsumwandlung.zweiteParade,
        ]) {
          final neu = wandleGefechtUm(s, u, werte: w);
          expect(gefechtsAngriffe(neu) + gefechtsRegulaereParaden(neu), 1);
          expect(neu.angriffeVerbraucht + neu.paradenVerbraucht, 1);
          expect(gefechtsAngriffe(neu), greaterThanOrEqualTo(0));
        }
      },
    );
  }
  test(
    'Aufmerksamkeit erlaubt keine späte Umwandlung nach eigener Attacke',
    () {
      const w = Gefechtswerte(
        iniBasis: 14,
        at: 16,
        pa: 14,
        ausweichen: 10,
        aufmerksamkeit: true,
      );
      expect(
        gefechtUmwandlungMoeglich(
          const Gefechtszustand(iniWurf: 6, angriffeVerbraucht: 1),
          Gefechtsumwandlung.zweiteAttacke,
          werte: w,
        ),
        isFalse,
      );
    },
  );
}
