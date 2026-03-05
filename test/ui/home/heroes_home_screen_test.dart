import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

void main() {
  final hero = HeroSheet(
    id: 'demo',
    name: 'Rondra',
    level: 1,
    attributes: const Attributes(
      mu: 14,
      kl: 12,
      inn: 13,
      ch: 11,
      ff: 10,
      ge: 12,
      ko: 14,
      kk: 13,
    ),
  );

  testWidgets('shows hero picker with create action', (tester) async {
    final repo = FakeRepository(
      heroes: [hero],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HeroesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DSA Helden'), findsOneWidget);
    expect(find.text('Rondra'), findsOneWidget);
    expect(find.text('Neuer Held'), findsOneWidget);
  });

  testWidgets(
    'opens hero workspace with tabs and read-only core attributes header',
    (tester) async {
      final repo = FakeRepository(
        heroes: [hero],
        states: {
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
          ),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [heroRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: HeroesHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rondra'));
      await tester.pumpAndSettle();

      final tabLabels = tester
          .widgetList<Tab>(find.byType(Tab))
          .map((tab) => (tab.text ?? '').trim())
          .toList(growable: false);
      expect(tabLabels, [
        'Übersicht',
        'Talente',
        'Kampf',
        'Magie',
        'Inventar',
        'Notizen',
      ]);
      expect(find.text('MU: 14'), findsOneWidget);
      expect(find.text('KO: 14'), findsOneWidget);
      expect(find.text('LEP: 10/22'), findsOneWidget);
      expect(find.text('AU: 10/22'), findsOneWidget);
      expect(find.text('ASP: 10/21'), findsOneWidget);
      expect(find.text('KAP: 0/0'), findsOneWidget);
    },
  );

}
