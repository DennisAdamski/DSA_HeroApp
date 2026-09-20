import 'dart:async';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_workspace.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import 'karto_test_support.dart';

void main() {
  Future<ProviderContainer> pumpShell(
    WidgetTester tester, {
    FakeRepository? repository,
    String? selected,
    TestBestand? bestand,
    double width = 390,
    double scale = 1,
    Future<RulesCatalog> Function()? catalogLoader,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 950);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          repository ?? FakeRepository(heroes: [testHero()]),
        ),
        rulesCatalogProvider.overrideWith(
          (ref) async =>
              catalogLoader == null ? testCatalog : await catalogLoader(),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (selected != null) {
      await container
          .read(selectedHeroSelectionActionsProvider)
          .selectHero(selected);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: KartoShell(bestand: bestand ?? TestBestand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> modus(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip(name).first);
    await tester.pumpAndSettle();
  }

  testWidgets('leerer Speicher bietet Anlegen und Rückweg', (tester) async {
    await pumpShell(tester, repository: FakeRepository.empty());
    expect(find.text('Noch keine Helden vorhanden.'), findsOneWidget);
    expect(find.byKey(const ValueKey('karto-shell-zurueck')), findsOneWidget);
    await tester.tap(find.text('Helden verwalten'));
    await tester.pumpAndSettle();
    expect(find.text('Bestandshelden'), findsOneWidget);
  });

  testWidgets('Auswahl öffnet vorhandenen Helden und merkt ID', (tester) async {
    final container = await pumpShell(tester);
    await tester.tap(find.text('Rondra'));
    await tester.pumpAndSettle();
    expect(container.read(selectedHeroIdProvider), 'rondra');
    expect(find.text('Spielwerte rondra'), findsOneWidget);
  });

  testWidgets('gültige gespeicherte Auswahl öffnet direkt', (tester) async {
    await pumpShell(tester, selected: 'rondra');
    expect(find.byType(KartoWorkspace), findsOneWidget);
    expect(find.text('Spielwerte rondra'), findsOneWidget);
  });

  testWidgets('fehlende gespeicherte Auswahl zeigt keinen fremden Helden', (
    tester,
  ) async {
    await pumpShell(tester, selected: 'geloescht');
    expect(find.byType(KartoWorkspace), findsNothing);
    expect(find.textContaining('nicht mehr verfügbar'), findsOneWidget);
    expect(find.text('Rondra'), findsOneWidget);
  });

  testWidgets('gelöschter offener Held führt erklärend zur Auswahl', (
    tester,
  ) async {
    final repo = FakeRepository(heroes: [testHero()]);
    await pumpShell(tester, repository: repo, selected: 'rondra');
    await repo.deleteHero('rondra');
    await tester.pumpAndSettle();
    expect(find.byType(KartoWorkspace), findsNothing);
    expect(find.textContaining('nicht mehr verfügbar'), findsOneWidget);
  });

  testWidgets('Ladefehler bietet Wiederholen und Rückweg', (tester) async {
    await pumpShell(tester, repository: _ErrorRepository());
    expect(
      find.textContaining('Helden konnten nicht geladen werden'),
      findsOneWidget,
    );
    expect(find.text('Wiederholen'), findsOneWidget);
    expect(find.byKey(const ValueKey('karto-shell-zurueck')), findsOneWidget);
  });

  testWidgets(
    'abgelehntes Verlassen erhält Verwaltung und verhindert Planstart',
    (tester) async {
      final bestand = TestBestand()..pruefung = () async => false;
      final container = await pumpShell(
        tester,
        selected: 'rondra',
        bestand: bestand,
      );
      await modus(tester, 'Held verwalten');
      await modus(tester, 'Entwicklung planen');
      expect(find.text('Verwaltungsinhalt'), findsOneWidget);
      expect(container.read(advancementSessionProvider('rondra')), isNull);
      await tester.tap(find.byTooltip('Heldenauswahl'));
      await tester.pumpAndSettle();
      expect(container.read(selectedHeroIdProvider), 'rondra');
      await tester.tap(find.byTooltip('Workspace-Menü'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();
      expect(find.text('Bestandseinstellungen'), findsNothing);
    },
  );

  testWidgets('Doppelklick wartet auf laufenden Guard', (tester) async {
    final completer = Completer<bool>();
    var guards = 0;
    final bestand = TestBestand()
      ..pruefung = () {
        guards++;
        return completer.future;
      };
    final container = await pumpShell(
      tester,
      selected: 'rondra',
      bestand: bestand,
    );
    await modus(tester, 'Held verwalten');
    await tester.tap(find.byTooltip('Entwicklung planen').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Spielen').first);
    await tester.pump();
    expect(guards, 1);
    expect(container.read(advancementSessionProvider('rondra')), isNull);
    completer.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Plankatalog rondra'), findsOneWidget);
  });

  testWidgets('Plan bleibt beim Moduswechsel erhalten und sperrt Korrekturen', (
    tester,
  ) async {
    final container = await pumpShell(tester, selected: 'rondra');
    await modus(tester, 'Entwicklung planen');
    final session = container.read(advancementSessionProvider('rondra'))!;
    await modus(tester, 'Spielen');
    expect(find.text('Spielwerte rondra'), findsOneWidget);
    await modus(tester, 'Held verwalten');
    expect(find.text('Verwaltung gesperrt'), findsOneWidget);
    await modus(tester, 'Entwicklung planen');
    expect(
      container.read(advancementSessionProvider('rondra'))!.sessionId,
      session.sessionId,
    );
  });

  testWidgets('Einstellungen öffnen sich bei offenem Plan ohne Planabfrage', (
    tester,
  ) async {
    final container = await pumpShell(tester, selected: 'rondra');
    await modus(tester, 'Entwicklung planen');
    final session = container.read(advancementSessionProvider('rondra'))!;
    await tester.tap(find.byTooltip('Workspace-Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();
    expect(find.text('Bestandseinstellungen'), findsOneWidget);
    expect(find.text('Entwicklung noch in Planung'), findsNothing);
    expect(
      container.read(advancementSessionProvider('rondra'))!.sessionId,
      session.sessionId,
    );
  });

  testWidgets('Refresh der Heldenliste erhält lokale Eingaben', (tester) async {
    final container = await pumpShell(tester, selected: 'rondra');
    await modus(tester, 'Held verwalten');
    await tester.enterText(
      find.byKey(const ValueKey('test-entwurf')),
      'Lokaler Entwurf',
    );
    container.invalidate(heroListProvider);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Lokaler Entwurf'), findsOneWidget);
  });

  testWidgets(
    'Repositorywechsel übernimmt keinen Editor einer gleichnamigen ID',
    (tester) async {
      final container = await pumpShell(tester, selected: 'rondra');
      await modus(tester, 'Held verwalten');
      await tester.enterText(
        find.byKey(const ValueKey('test-entwurf')),
        'Altes Konto',
      );
      container.updateOverrides([
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(heroes: [testHero('rondra', 'Neues Konto')]),
        ),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Neues Konto'), findsOneWidget);
      await modus(tester, 'Held verwalten');
      expect(find.text('Altes Konto'), findsNothing);
    },
  );

  testWidgets(
    'Katalogfehler startet keinen Plan und Wiederholen bleibt möglich',
    (tester) async {
      var failed = true;
      final container = await pumpShell(
        tester,
        selected: 'rondra',
        catalogLoader: () async {
          if (failed) throw StateError('Katalogfehler');
          return testCatalog;
        },
      );
      await modus(tester, 'Entwicklung planen');
      expect(
        find.textContaining('Regelkatalog konnte nicht geladen werden'),
        findsOneWidget,
      );
      expect(container.read(advancementSessionProvider('rondra')), isNull);
      failed = false;
      await tester.tap(find.text('Wiederholen'));
      await tester.pumpAndSettle();
      expect(find.text('Plankatalog rondra'), findsOneWidget);
      expect(container.read(advancementSessionProvider('rondra')), isNotNull);
    },
  );

  testWidgets('System-Zurück prüft einen leeren offenen Plan', (tester) async {
    final container = await pumpShell(tester, selected: 'rondra');
    await modus(tester, 'Entwicklung planen');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Weiterplanen'), findsOneWidget);
    await tester.tap(find.text('Weiterplanen'));
    await tester.pumpAndSettle();
    expect(container.read(selectedHeroIdProvider), 'rondra');
    expect(container.read(advancementSessionProvider('rondra')), isNotNull);
    await tester.tap(find.byTooltip('Heldenauswahl'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Verwerfen').last);
    await tester.pumpAndSettle();
    expect(container.read(selectedHeroIdProvider), isNull);
    expect(container.read(advancementSessionProvider('rondra')), isNull);
    expect(find.byType(KartoWorkspace), findsNothing);
  });

  testWidgets(
    'fehlgeschlagene Übernahme erhält Plan; erfolgreicher Save schließt ihn',
    (tester) async {
      final repo = _SaveRepository();
      final container = await pumpShell(
        tester,
        selected: 'rondra',
        repository: repo,
      );
      await modus(tester, 'Entwicklung planen');
      final provider = advancementSessionProvider('rondra');
      final sessionId = container.read(provider)!.sessionId;
      container
          .read(provider.notifier)
          .add(
            HeroAdvancementEntry(
              id: 'entry',
              sessionId: sessionId,
              createdAt: DateTime.utc(2026, 9, 20),
              kind: AdvancementKind.attribute,
              targetId: 'mu',
              label: 'Mut',
              fromValue: 14,
              toValue: 15,
              apCost: 100,
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Speicherfehler'), findsOneWidget);
      expect(find.text('Plankatalog rondra'), findsOneWidget);
      expect(container.read(provider)!.entries, hasLength(1));
      expect((await repo.loadHeroById('rondra'))!.attributes.mu, 14);
      repo.fail = false;
      await tester.tap(find.byTooltip('Heldenauswahl'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen').last);
      await tester.pumpAndSettle();
      expect(container.read(provider), isNull);
      expect(container.read(selectedHeroIdProvider), isNull);
      expect(
        (await repo.loadHeroById('rondra'))!.advancementHistory,
        hasLength(1),
      );
    },
  );

  for (final width in [320.0, 390.0, 744.0, 1024.0, 1440.0]) {
    testWidgets('drei Bereiche bei $width dp und Textskalierung 2', (
      tester,
    ) async {
      await pumpShell(tester, selected: 'rondra', width: width, scale: 2);
      await modus(tester, 'Held verwalten');
      await modus(tester, 'Entwicklung planen');
      await modus(tester, 'Spielen');
      expect(tester.takeException(), isNull);
    });
  }
}

class _ErrorRepository extends FakeRepository {
  @override
  Stream<Map<String, HeroSheet>> watchHeroIndex() =>
      Stream.error(StateError('Lesefehler'));
}

class _SaveRepository extends FakeRepository {
  _SaveRepository() : super(heroes: [testHero()]);
  bool fail = true;
  @override
  Future<void> saveHero(HeroSheet hero) async {
    if (fail) throw StateError('Speicherfehler');
    await super.saveHero(hero);
  }
}
