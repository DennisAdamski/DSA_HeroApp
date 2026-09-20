import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';

/// Baut einen Protokolleintrag mit sprechendem Titel.
DiceLogEntry eintrag(String titel) => DiceLogEntry(
  timestamp: DateTime.utc(2026, 9, 20),
  type: ProbeType.attribute,
  title: titel,
  subtitle: 'MU',
  success: true,
  diceValues: const [5],
);

void main() {
  Future<void> zeige(
    WidgetTester tester, {
    required String heroId,
    required FakeRepository repository,
    TestBestand? bestand,
    double breite = 1440,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repository),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          home: Scaffold(
            body: KartoSpielansicht(
              heroId: heroId,
              bestand: bestand ?? TestBestand(),
              aktion: (auftrag) => auftrag(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('neuer Repository-Zustand erscheint im Verlauf', (tester) async {
    final repo = FakeRepository(heroes: [testHero()]);
    await zeige(tester, heroId: 'rondra', repository: repo);
    expect(find.text('Protokoll 0'), findsOneWidget);
    final vorher = await repo.loadHeroState('rondra');
    await repo.saveHeroState(
      'rondra',
      (vorher ?? const HeroState.empty()).withAppendedDiceLogEntries([
        eintrag('Eigenschaftsprobe: MU'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Protokoll 1'), findsOneWidget);
  });

  testWidgets('Heldenwechsel zeigt ausschließlich dessen Einträge', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [testHero(), testHero('liora', 'Liora')],
      states: {
        'rondra': const HeroState.empty().withAppendedDiceLogEntries([
          eintrag('Eigenschaftsprobe: MU'),
          eintrag('Eigenschaftsprobe: KL'),
        ]),
      },
    );
    await zeige(tester, heroId: 'rondra', repository: repo);
    expect(find.text('Protokoll 2'), findsOneWidget);
    await zeige(tester, heroId: 'liora', repository: repo);
    expect(find.text('Protokoll 0'), findsOneWidget);
  });

  testWidgets('Effekte verwalten läuft über den vorhandenen Weg', (
    tester,
  ) async {
    final bestand = TestBestand();
    await zeige(
      tester,
      heroId: 'rondra',
      repository: FakeRepository(heroes: [testHero()]),
      bestand: bestand,
    );
    await tester.tap(find.byKey(const ValueKey('karto-spiel-effekte')));
    await tester.pumpAndSettle();
    expect(bestand.aufrufe, ['effekte:rondra']);
  });

  testWidgets('kein erfundener Rundenzähler und kein Schadensknopf', (
    tester,
  ) async {
    await zeige(
      tester,
      heroId: 'rondra',
      repository: FakeRepository(heroes: [testHero()]),
    );
    expect(find.textContaining('Nächste Kampfrunde'), findsNothing);
    expect(find.textContaining('KR '), findsNothing);
    expect(find.textContaining('Schaden erhalten'), findsNothing);
    expect(find.textContaining('zurücknehmen'), findsNothing);
    expect(find.textContaining('Offline'), findsNothing);
  });

  group('echte Bestandsbausteine', () {
    Future<FakeRepository> zeigeEcht(
      WidgetTester tester, {
      HeroState? zustand,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 2000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeRepository(
        heroes: [testHero()],
        states: zustand == null ? null : {'rondra': zustand},
      );
      final container = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildKartoTheme(
              brightness: Brightness.light,
              centerAppBarTitle: false,
            ),
            home: const Scaffold(
              body: KartoSpielansicht(
                heroId: 'rondra',
                bestand: KartoBestandsAdapterImpl(),
                aktion: _direkt,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('leeres Protokoll ist ein erklärter Leerzustand', (
      tester,
    ) async {
      await zeigeEcht(tester);
      expect(find.text('Würfelprotokoll'), findsOneWidget);
      expect(find.textContaining('Noch keine'), findsOneWidget);
    });

    testWidgets('vorhandene Einträge und Filter bleiben erhalten', (
      tester,
    ) async {
      await zeigeEcht(
        tester,
        zustand: const HeroState.empty().withAppendedDiceLogEntries([
          eintrag('Eigenschaftsprobe: MU'),
        ]),
      );
      expect(find.text('Eigenschaftsprobe: MU'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dice-log-filter-attribute')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Effektanzeige nennt den Leerzustand ohne eigene Schaltfläche',
      (tester) async {
        await zeigeEcht(tester);
        expect(find.text('Aktive Effekte'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('workspace-active-spells-open')),
          findsNothing,
        );
        expect(find.text('Effekte verwalten'), findsOneWidget);
      },
    );
  });
}

/// Führt eine Laufzeitaktion ohne zusätzlichen Schutz aus.
Future<void> _direkt(Future<void> Function() auftrag) => auftrag();
