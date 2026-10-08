import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';
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

  // Eine echte geplante Steigerung muss alle Lese- und Abbruchwege überleben.
  Future<void> plan(WidgetTester tester, ProviderContainer container) async {
    await mode(tester, 'Entwicklung planen');
    final session = container.read(advancementSessionProvider('rondra'))!;
    container
        .read(advancementSessionProvider('rondra').notifier)
        .add(
          HeroAdvancementEntry(
            id: 'planned-mut',
            sessionId: session.sessionId,
            createdAt: DateTime.utc(2026, 10, 9),
            kind: AdvancementKind.attribute,
            targetId: 'mu',
            label: 'Mut',
            fromValue: 14,
            toValue: 15,
            apCost: 100,
          ),
        );
    await tester.pumpAndSettle();
    await mode(tester, 'Held verwalten');
  }

  for (final width in [390.0, 1440.0]) {
    testWidgets('Planung bleibt beim Ansehen und Abbrechen bei $width dp', (
      tester,
    ) async {
      final repository = FakeRepository(heroes: [testHero()]);
      final container = await pump(
        tester,
        width: width,
        repository: repository,
      );
      await plan(tester, container);
      final session = container.read(advancementSessionProvider('rondra'))!;
      expect(find.widgetWithText(Tab, 'Inventar'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-field-name')),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      final bearbeiten = width < 744
          ? find.byTooltip('Bearbeiten')
          : find.text('Bearbeiten');
      await tester.tap(bearbeiten.first);
      await tester.pumpAndSettle();
      expect(find.text('Planung verwerfen und bearbeiten'), findsOneWidget);
      await tester.tap(find.text('Abbrechen').last);
      await tester.pumpAndSettle();
      expect(
        container.read(advancementSessionProvider('rondra')),
        same(session),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-field-name')),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect((await repository.loadHeroById('rondra'))!.attributes.mu, 14);

      await tester.tap(bearbeiten.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planung verwerfen und bearbeiten'));
      await tester.pumpAndSettle();
      expect(container.read(advancementSessionProvider('rondra')), isNull);
      expect(find.byKey(const ValueKey('overview-field-name')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('overview-field-name')),
        'Bearbeitet',
      );
      await tester.tap(
        width < 744 ? find.byTooltip('Speichern') : find.text('Speichern'),
      );
      await tester.pumpAndSettle();
      final saved = (await repository.loadHeroById('rondra'))!;
      expect(saved.name, 'Bearbeitet');
      expect(saved.attributes.mu, 14);
      expect(saved.advancementHistory, isEmpty);
    });
  }

  testWidgets('Inventar fragt vor direktem Hinzufügen und erhält den Plan', (
    tester,
  ) async {
    final container = await pump(tester);
    await plan(tester, container);
    final session = container.read(advancementSessionProvider('rondra'))!;
    final inventar = find.widgetWithText(Tab, 'Inventar');
    await tester.ensureVisible(inventar);
    await tester.tap(inventar);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory-header-add')));
    await tester.pumpAndSettle();
    expect(find.text('Planung verwerfen und bearbeiten'), findsOneWidget);
    await tester.tap(find.text('Abbrechen').last);
    await tester.pumpAndSettle();
    expect(container.read(advancementSessionProvider('rondra')), same(session));
    await tester.tap(find.byKey(const ValueKey('inventory-header-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planung verwerfen und bearbeiten'));
    await tester.pumpAndSettle();
    expect(container.read(advancementSessionProvider('rondra')), isNull);
    expect(find.byKey(const ValueKey('inventory-editor-name')), findsOneWidget);
  });

  testWidgets('Geld bleibt nur lesbar und Münzschritt fragt vor der Änderung', (
    tester,
  ) async {
    final repository = FakeRepository(
      heroes: [testHero().copyWith(dukaten: '10')],
    );
    final container = await pump(tester, repository: repository);
    await plan(tester, container);
    final session = container.read(advancementSessionProvider('rondra'))!;
    final inventar = find.widgetWithText(Tab, 'Inventar');
    await tester.ensureVisible(inventar);
    await tester.tap(inventar);
    await tester.pumpAndSettle();
    final geldfeld = find.descendant(
      of: find.byKey(const ValueKey('inventory-dukaten-field')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(geldfeld).readOnly, isTrue);
    final plus = find.byKey(
      const ValueKey('inventory-dukaten-increment-dukaten'),
    );
    await tester.tap(plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(container.read(advancementSessionProvider('rondra')), same(session));
    expect((await repository.loadHeroById('rondra'))!.dukaten, '10');
    await tester.tap(plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planung verwerfen und bearbeiten'));
    await tester.pumpAndSettle();
    expect(container.read(advancementSessionProvider('rondra')), isNull);
    expect((await repository.loadHeroById('rondra'))!.dukaten, '11');
    expect(tester.widget<TextField>(geldfeld).readOnly, isFalse);
  });

  testWidgets('Inventardetails lassen sich ohne Verwerfen des Plans ansehen', (
    tester,
  ) async {
    final repository = FakeRepository(
      heroes: [
        testHero().copyWith(
          inventoryEntries: [
            const HeroInventoryEntry(
              gegenstand: 'Seil',
              beschreibung: 'Besonders lang',
            ),
          ],
        ),
      ],
    );
    final container = await pump(tester, repository: repository);
    await plan(tester, container);
    final session = container.read(advancementSessionProvider('rondra'))!;
    final inventar = find.widgetWithText(Tab, 'Inventar');
    await tester.ensureVisible(inventar);
    await tester.tap(inventar);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory-row-open-0')));
    await tester.pumpAndSettle();
    expect(container.read(advancementSessionProvider('rondra')), same(session));
    expect(find.text('Geplante Entwicklung verwerfen?'), findsNothing);
    expect(find.byKey(const ValueKey('inventory-editor-name')), findsOneWidget);
    final speichern = tester.widget<IconButton>(
      find.byKey(const ValueKey('inventory-editor-save')),
    );
    expect(speichern.onPressed, isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(container.read(advancementSessionProvider('rondra')), same(session));
    expect(
      (await repository.loadHeroById('rondra'))!
          .inventoryEntries
          .single
          .gegenstand,
      'Seil',
    );
  });

  testWidgets(
    'direktes + Chronik legt bei abgebrochener Warnung keinen Entwurf an',
    (tester) async {
      final container = await pump(tester, width: 1440);
      await plan(tester, container);
      final session = container.read(advancementSessionProvider('rondra'))!;
      final notizen = find.widgetWithText(
        Tab,
        'Chroniken, Kontakte & Abenteuer',
      );
      await tester.ensureVisible(notizen);
      await tester.tap(notizen);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notes-add-note')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen').last);
      await tester.pumpAndSettle();
      expect(
        container.read(advancementSessionProvider('rondra')),
        same(session),
      );
      expect(find.byTooltip('Speichern'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Speichern'), findsNothing);
      expect(find.text('Noch keine Chroniken vorhanden.'), findsOneWidget);
    },
  );

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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-field-name')),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
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

  testWidgets('Statuswerte stehen im Zustand ohne eigene Karte', (
    tester,
  ) async {
    await pump(tester, width: 1440);
    final zeile = find.byKey(const ValueKey('workspace-status-row-Ini'));
    await tester.ensureVisible(zeile);
    expect(zeile, findsOneWidget);
    expect(find.text('Statuswerte'), findsOneWidget);
    // Der Abschnitt "Zustand" ist schon die Flaeche; eine CodexSectionCard
    // darin waere eine Karte in der Karte.
    expect(
      find.ancestor(of: zeile, matching: find.byType(CodexSectionCard)),
      findsNothing,
    );
    expect(find.text('Schnellzugriff'), findsNothing);
  });

  for (final width in [320.0, 390.0, 744.0, 1024.0, 1440.0]) {
    testWidgets('echte Bestandsansichten bei $width dp', (tester) async {
      final container = await pump(tester, width: width);
      await mode(tester, 'Held verwalten');
      expect(find.widgetWithText(Tab, 'Inventar'), findsOneWidget);
      await mode(tester, 'Entwicklung planen');
      expect(container.read(advancementSessionProvider('rondra')), isNotNull);
      await mode(tester, 'Spielen');
      expect(
        find.byKey(const ValueKey('karto-ressource-lebensenergie')),
        findsOneWidget,
      );
      expect(find.text('Ressourcen'), findsOneWidget);
      expect(find.byKey(const ValueKey('advancement-history')), findsNothing);
      await mode(tester, 'Held verwalten');
      expect(find.widgetWithText(Tab, 'Inventar'), findsOneWidget);
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
