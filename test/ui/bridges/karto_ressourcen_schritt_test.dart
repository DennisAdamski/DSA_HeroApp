import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';

/// Die Knöpfe der breiten Ressourcenkachel schreiben über den gemeinsamen
/// Zustandsweg: frisch geladen, nur die eine Ressource, nie vom angezeigten
/// Wert aus.
void main() {
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
  );

  Future<FakeRepository> feuere(
    WidgetTester tester, {
    required HeroState start,
    required List<(KartoRessource, int)> schritte,
  }) async {
    final repo = FakeRepository(heroes: const [held], states: {'hexe': start});
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
                    // Ohne zwischenzeitliches Neuzeichnen: schnelle Klicks.
                    for (final (ressource, schritt) in schritte) {
                      const KartoBestandsAdapterImpl().ressourceSchritt(
                        context: context,
                        ref: ref,
                        heroId: 'hexe',
                        ressource: ressource,
                        schritt: schritt,
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
    return repo;
  }

  const start = HeroState(
    currentLep: 30,
    currentAsp: 10,
    currentKap: 7,
    currentAu: 17,
  );

  testWidgets('fünf schnelle Schritte zählen vom gespeicherten Wert', (
    tester,
  ) async {
    final repo = await feuere(
      tester,
      start: start,
      schritte: [for (var i = 0; i < 5; i++) (KartoRessource.lebensenergie, 1)],
    );
    expect((await repo.loadHeroState('hexe'))!.currentLep, 35);
  });

  testWidgets('nur die gewählte Ressource ändert sich', (tester) async {
    final repo = await feuere(
      tester,
      start: start,
      schritte: [(KartoRessource.astralenergie, -5)],
    );
    final danach = (await repo.loadHeroState('hexe'))!;
    expect(danach.currentAsp, 5);
    expect(danach.currentLep, 30);
    expect(danach.currentKap, 7);
    expect(danach.currentAu, 17);
  });

  testWidgets('jede Ressource schreibt in ihr eigenes Feld', (tester) async {
    final repo = await feuere(
      tester,
      start: start,
      schritte: [
        (KartoRessource.lebensenergie, 1),
        (KartoRessource.ausdauer, 5),
        (KartoRessource.astralenergie, -1),
        (KartoRessource.karma, -5),
      ],
    );
    final danach = (await repo.loadHeroState('hexe'))!;
    expect(danach.currentLep, 31);
    expect(danach.currentAu, 22);
    expect(danach.currentAsp, 9);
    expect(danach.currentKap, 2);
  });

  testWidgets('abwärts stoppt an der Untergrenze von -10', (tester) async {
    final repo = await feuere(
      tester,
      start: start.copyWith(currentLep: 2),
      schritte: [
        for (var i = 0; i < 4; i++) (KartoRessource.lebensenergie, -5),
      ],
    );
    expect((await repo.loadHeroState('hexe'))!.currentLep, -10);
  });

  testWidgets('ein Wert unter der Untergrenze wird nicht angehoben', (
    tester,
  ) async {
    final repo = await feuere(
      tester,
      start: start.copyWith(currentLep: -14),
      schritte: [(KartoRessource.lebensenergie, -1)],
    );
    expect((await repo.loadHeroState('hexe'))!.currentLep, -14);
  });

  testWidgets('aufwärts gibt es keine Obergrenze (Überheilung)', (
    tester,
  ) async {
    final repo = await feuere(
      tester,
      start: start,
      schritte: [for (var i = 0; i < 3; i++) (KartoRessource.lebensenergie, 5)],
    );
    expect((await repo.loadHeroState('hexe'))!.currentLep, 45);
  });
}
