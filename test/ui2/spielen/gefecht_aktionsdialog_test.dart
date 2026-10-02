import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_aktionsdialog.dart';

import '../shell/karto_test_support.dart';

void main() {
  testWidgets(
    'Abwehrmanöver fragt aktuelle Angriffsdaten statt Angriffsabsicht',
    (tester) async {
      final m = ManeuverDef.fromJson({
        'id': 'man_binden',
        'name': 'Binden',
        'typ': 'Abwehraktion',
      });
      final snap = buildHeroComputedSnapshot(
        hero: testHero().copyWith(
          combatConfig: const CombatConfig(
            weapons: [MainWeaponSlot(name: 'Schwert', distanceClass: 'N')],
            specialRules: CombatSpecialRules(activeManeuvers: ['man_binden']),
          ),
        ),
        state: const HeroState.empty(),
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GefechtAktionsdialog(
              zustand: const Gefechtszustand(iniWurf: 6, dk: 'N'),
              werte: snap,
              katalog: testCatalog,
              aktion: Gefechtsaktion.angriff,
              titel: 'Binden',
              manoever: m,
            ),
          ),
        ),
      );
      expect(find.text('Angriff gegen mich'), findsOneWidget);
      expect(find.text('Gegnerische Finte (0 erlaubt)'), findsOneWidget);
      expect(find.text('Parade erlaubt?'), findsOneWidget);
      expect(find.text('Angriffsabsicht'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('gefecht-kontext-bestaetigen')),
      );
      await tester.tap(
        find.byKey(const ValueKey('gefecht-kontext-bestaetigen')),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('gefecht-auftrag-starten')),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
