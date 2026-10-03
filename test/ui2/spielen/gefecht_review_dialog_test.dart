import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_aktionsdialog.dart';

import '../../rules/gefecht_laden_rules_test.dart' as fixture;
import '../shell/karto_test_support.dart';

void main() {
  for (final eingabe in ['', 'ungültig']) {
    testWidgets('M1 FK-Eingabe "$eingabe" bleibt nach Waffenwechsel fehlend', (
      t,
    ) async {
      t.view.physicalSize = const Size(1200, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final basis = fixture.ladeSnapshot();
      final rechts = basis.hero.combatConfig.selectedWeapon.copyWith(
        name: 'Rechte Armbrust',
      );
      final links = rechts.copyWith(id: 'b', name: 'Linke Armbrust');
      final snap = buildHeroComputedSnapshot(
        hero: basis.hero.copyWith(
          combatConfig: basis.hero.combatConfig.copyWith(
            weapons: [rechts, links],
            offhandAssignment: const OffhandAssignment(weaponIndex: 1),
          ),
        ),
        state: const HeroState.empty(),
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      var s = const Gefechtszustand(
        iniWurf: 6,
        kontext: Gefechtskontext(kontakt: 'Ork', entfernung: 5),
      );
      s = bestaetigeGefechtsLadung(
        bestaetigeGefechtsLadung(s, rechts, true),
        links,
        true,
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GefechtAktionsdialog(
              zustand: s,
              werte: snap,
              katalog: testCatalog,
              aktion: Gefechtsaktion.angriff,
              titel: 'Schuss',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final situation = find.byType(TextFormField).at(1);
      expect(t.widget<TextFormField>(situation).initialValue, '0');
      await t.ensureVisible(situation);
      await t.enterText(situation, eingabe);
      await t.pumpAndSettle();
      final wahl = find.byKey(const ValueKey('gefecht-kampfmittel'));
      await t.ensureVisible(wahl);
      await t.tap(wahl);
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Linke Armbrust').last);
      await t.pumpAndSettle();
      expect(
        t.widget<TextFormField>(find.byType(TextFormField).at(1)).initialValue,
        '',
      );
      expect(
        t
            .widget<FilledButton>(
              find.byKey(const ValueKey('gefecht-auftrag-starten')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.textContaining(
          'Zielgröße, Bewegung, Sicht und Deckung bestätigen',
        ),
        findsWidgets,
      );
    });
  }
  testWidgets(
    'RootVisual M2 FK-Hinweis und kurzes Situationslabel passen zum Schuss',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GefechtAktionsdialog(
              zustand: const Gefechtszustand(iniWurf: 6),
              werte: fixture.ladeSnapshot(),
              katalog: testCatalog,
              aktion: Gefechtsaktion.angriff,
              titel: 'Schuss',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('Ohne erlernte Finte/Wuchtschlag'),
        findsNothing,
      );
      expect(find.text('Situationszuschlag'), findsOneWidget);
      expect(
        find.text('Zielgröße, Bewegung, Sicht und Deckung; 0 ist möglich.'),
        findsOneWidget,
      );
    },
  );
}
