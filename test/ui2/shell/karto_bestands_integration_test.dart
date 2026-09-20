import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import 'karto_test_support.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    FakeRepository? repository,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          repository ?? FakeRepository(heroes: [testHero()]),
        ),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(selectedHeroSelectionActionsProvider)
        .selectHero('rondra');
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
          home: const KartoShell(bestand: KartoBestandsAdapterImpl()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> mode(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip(label).first);
    await tester.pumpAndSettle();
  }

  Future<void> editName(WidgetTester tester) async {
    await mode(tester, 'Held verwalten');
    final tooltip = find.byTooltip('Bearbeiten');
    await tester.tap(
      tooltip.evaluate().isNotEmpty
          ? tooltip.first
          : find.text('Bearbeiten').first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('overview-field-name')),
      'Ungespeichert',
    );
  }

  testWidgets('echter Editor schützt Moduswechsel vor fehlgeschlagenem Save', (
    tester,
  ) async {
    final repository = _FailedSave();
    final container = await pump(tester, repository: repository);
    await editName(tester);
    await mode(tester, 'Entwicklung planen');
    await tester.tap(find.text('Änderungen speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Ungespeichert'), findsOneWidget);
    expect(container.read(advancementSessionProvider('rondra')), isNull);
    expect(find.textContaining('Schreibfehler'), findsOneWidget);
    await mode(tester, 'Spielen');
    await tester.tap(find.text('Nein'));
    await tester.pumpAndSettle();
    expect(find.text('Ungespeichert'), findsOneWidget);
    await mode(tester, 'Spielen');
    await tester.tap(find.text('Ja'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-field-name')), findsNothing);
    expect((await repository.loadHeroById('rondra'))!.name, 'Rondra');
  });

  testWidgets('echter Editor schützt System-Zurück und Oberflächenwechsel', (
    tester,
  ) async {
    final container = await pump(tester);
    await editName(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('Ungespeicherte Änderungen'), findsOneWidget);
    await tester.tap(find.text('Nein'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Workspace-Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zur bestehenden Oberfläche'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ungespeicherte Änderungen'), findsOneWidget);
    await tester.tap(find.text('Nein'));
    await tester.pumpAndSettle();
    expect(container.read(selectedHeroIdProvider), 'rondra');
    expect(find.text('Ungespeichert'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 744.0, 1024.0, 1440.0]) {
    testWidgets('echte Bestandsansichten bei $width dp', (tester) async {
      final container = await pump(tester, width: width);
      await mode(tester, 'Held verwalten');
      expect(find.widgetWithText(Tab, 'Inventar'), findsOneWidget);
      await mode(tester, 'Entwicklung planen');
      expect(container.read(advancementSessionProvider('rondra')), isNotNull);
      await mode(tester, 'Spielen');
      expect(find.byKey(const ValueKey('inspector-tab-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('advancement-history')), findsNothing);
      await mode(tester, 'Held verwalten');
      expect(find.widgetWithText(Tab, 'Inventar'), findsNothing);
      expect(find.text('Zur Planung'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _FailedSave extends FakeRepository {
  _FailedSave() : super(heroes: [testHero()]);
  @override
  Future<void> saveHero(HeroSheet hero) async =>
      throw StateError('Schreibfehler');
}
