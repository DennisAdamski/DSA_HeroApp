import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../../test_support/bogen_test_repository.dart';
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Die Begleiter im Gefechtsbild (Vertraute V3a): Die Würfelknöpfe laufen
// über die Gefechtsbrücke, schreiben aber nichts.

void main() {
  const kater = HeroCompanion(
    id: 'kater',
    name: 'Kater',
    typ: BegleiterTyp.vertrauter,
    vertrautenBindung: VertrautenBindung(artId: 'vart_katze'),
    angriffe: [
      HeroCompanionAttack(
        id: 'pranke',
        name: 'Prankenhieb',
        at: 10,
        pa: 5,
        tp: '1W6+1',
      ),
    ],
  );

  const zustand = HeroState(
    currentLep: 30,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 30,
  );

  Future<(ProviderContainer, BogenTestRepository)> zeige(
    WidgetTester tester,
    GefechtsTestBestand bestand,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final held = testHero().copyWith(
      combatConfig: const CombatConfig(
        weapons: [MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N')],
      ),
      companions: const [kater],
    );
    final repo = BogenTestRepository(
      heroes: [held],
      states: {'rondra': zustand},
    );
    final snapshot = buildHeroComputedSnapshot(
      hero: held,
      state: zustand,
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        heroComputedProvider('rondra')
            .overrideWith((ref) => AsyncData(snapshot)),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    container.read(gefechtProvider('rondra').notifier).beginnen(6, dk: 'N');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GefechtAnsicht(heroId: 'rondra', bestand: bestand),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('gefecht-begleiter-kater'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    return (container, repo);
  }

  Finder knopf(String art) =>
      find.byKey(ValueKey('gefecht-begleiter-kater-0-$art'));

  testWidgets('AT, PA und TP des Begleiters laufen über die Gefechtsbrücke', (
    tester,
  ) async {
    final bestand = GefechtsTestBestand();
    final (container, repo) = await zeige(tester, bestand);

    for (final art in ['at', 'pa', 'tp']) {
      await tester.ensureVisible(knopf(art));
      await tester.tap(knopf(art));
      await tester.pumpAndSettle();
    }

    expect(bestand.anfragen.map((r) => r.type), [
      ProbeType.combatAttack,
      ProbeType.combatParry,
      ProbeType.damage,
    ]);
    expect(bestand.anfragen.first.targets.single.value, 10);
    expect(bestand.anfragen.last.diceSpec.label, '1W6+1');
    // Nur Würfel: kein Schreibweg, keine Aktionsmarke, kein Auftrag.
    final gefecht = container.read(gefechtProvider('rondra'))!;
    expect(gefecht.angriffeVerbraucht, 0);
    expect(gefecht.angriffsergebnisse, isEmpty);
    expect(await repo.loadHeroState('rondra'), zustand);
  });

  testWidgets('ein abgebrochener Dialog lässt alles unberührt', (tester) async {
    final bestand = GefechtsTestBestand()..abbrechen = true;
    final (container, repo) = await zeige(tester, bestand);
    await tester.ensureVisible(knopf('at'));
    await tester.tap(knopf('at'));
    await tester.pumpAndSettle();
    expect(bestand.anfragen, hasLength(1));
    expect(container.read(gefechtProvider('rondra'))!.angriffeVerbraucht, 0);
    expect(await repo.loadHeroState('rondra'), zustand);
  });
}
