import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_wirkdialog.dart';

import '../shell/karto_test_support.dart';

void main() {
  for (final breite in [390.0, 820.0, 1200.0, 1440.0]) {
    for (final hell in Brightness.values) {
      for (final karma in [false, true]) {
        testWidgets('Wirkdialog $breite $hell Karma=$karma mit Tastatur', (
          tester,
        ) async {
          tester.view.physicalSize = Size(breite, 1000);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final zauber = SpellDef.fromJson({
            'id': 's',
            'name': 'Blitz',
            'attributes': ['MU', 'KL', 'IN'],
            'castingTime': '5 Aktionen',
            'aspCost': '7 AsP',
          });
          final talent = TalentDef.fromJson({
            'id': 'lk',
            'name': 'Liturgiekenntnis (Boron)',
            'attributes': ['MU', 'IN', 'CH'],
          });
          final snapshot = buildHeroComputedSnapshot(
            hero: testHero().copyWith(
              spells: {
                's': const HeroSpellEntry(
                  spellValue: 9,
                  learnedRepresentation: 'Mag',
                ),
              },
              talents: {'lk': const HeroTalentEntry(talentValue: 8)},
            ),
            state: const HeroState(
              currentLep: 30,
              currentAsp: 20,
              currentKap: 15,
              currentAu: 30,
            ),
            catalog: testCatalog,
            epicAdvantagesActive: false,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: hell),
              home: Scaffold(
                body: GefechtWirkdialog(
                  snapshot: snapshot,
                  zustand: const Gefechtszustand(iniWurf: 6),
                  zauber: karma ? null : zauber,
                  talent: karma ? talent : null,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final start = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Wirken beginnen'),
          );
          expect(start.onPressed, isNull);
          final textfelder = find.byType(TextField);
          await tester.ensureVisible(textfelder.last);
          await tester.enterText(textfelder.last, '-1');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
