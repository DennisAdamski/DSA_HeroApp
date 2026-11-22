import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_probe_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';

import '../../test_support/fake_repository.dart';
import '../../ui2/shell/karto_test_support.dart';

/// Die Brücke würfelt die Reittierprobe über den Probendialog, ohne etwas zu
/// buchen; kann sie nicht aufbauen, nennt eine Meldung den Grund.
void main() {
  const rosse = HeroCompanion(
    id: 'rosse',
    name: 'Rosse',
    typ: BegleiterTyp.reittier,
    loyalitaet: 13,
  );
  final held = testHero('hexe', 'Hexe').copyWith(companions: [rosse]);
  const zustand = HeroState(
    currentLep: 30,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 30,
  );

  Future<FakeRepository> zeige(
    WidgetTester tester,
    ReittierProbeArt art,
  ) async {
    final repo = FakeRepository(heroes: [held], states: {'hexe': zustand});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // Wie in der Spielansicht beobachtet der Baum den Helden.
                ref.watch(heroByIdProvider('hexe'));
                ref.watch(heroComputedProvider('hexe'));
                ref.watch(heroRulesCatalogProvider('hexe'));
                return TextButton(
                  onPressed: () =>
                      const KartoBestandsAdapterImpl().reittierProbe(
                        context: context,
                        ref: ref,
                        heroId: 'hexe',
                        begleiterId: 'rosse',
                        art: art,
                      ),
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
    return repo;
  }

  testWidgets('LO öffnet den Probendialog mit der wirksamen Loyalität', (
    tester,
  ) async {
    final repo = await zeige(tester, ReittierProbeArt.loyalitaet);
    expect(find.textContaining('LO (Loyalität, Rosse)'), findsWidgets);
    // Eine Würfelhilfe: der Zustand bleibt unberührt.
    expect(await repo.loadHeroState('hexe'), zustand);
  });

  testWidgets('Reiten ohne Talent im Katalog nennt den Grund', (tester) async {
    await zeige(tester, ReittierProbeArt.reiten);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Reiten steht nicht im Katalog.'), findsOneWidget);
  });
}
