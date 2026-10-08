import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';

/// Die Brücke schreibt laufende Begleiterwerte über den gemeinsamen
/// Zustandsweg (V2), auch bei schnellen Klicks.
void main() {
  const mira = HeroCompanion(
    id: 'mira',
    name: 'Mira',
    typ: BegleiterTyp.vertrauter,
    maxLep: 24,
    startLep: 24,
  );
  const held = HeroSheet(
    id: 'hexe',
    name: 'Hexe',
    level: 1,
    attributes: Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    companions: <HeroCompanion>[mira],
  );

  testWidgets('begleiterWertAendern zählt fünf schnelle Klicks', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: const [held],
      states: {
        'hexe': const HeroState(
          currentLep: 30,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 30,
        ),
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // Wie in der Spielansicht beobachtet der Baum den Helden.
                ref.watch(heroByIdProvider('hexe'));
                return TextButton(
                  onPressed: () {
                    for (var i = 0; i < 5; i++) {
                      const KartoBestandsAdapterImpl().begleiterWertAendern(
                        context: context,
                        ref: ref,
                        heroId: 'hexe',
                        begleiterId: 'mira',
                        pool: BegleiterPool.lep,
                        aenderung: begleiterPoolSchritt(
                          BegleiterPool.lep,
                          24,
                          -1,
                        ),
                      );
                    }
                  },
                  child: const Text('los'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();

    expect(
      (await repo.loadHeroState('hexe'))!
          .begleiterZustaende['mira']!
          .currentLep,
      19,
    );
  });
}
