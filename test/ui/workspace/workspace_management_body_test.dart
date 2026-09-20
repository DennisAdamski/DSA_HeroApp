import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_body.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';

void main() {
  const catalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: <TalentDef>[],
    spells: <SpellDef>[],
    weapons: <WeaponDef>[],
  );

  HeroSheet hero() => const HeroSheet(
    id: 'demo',
    name: 'Rondra',
    level: 1,
    attributes: Attributes(
      mu: 14,
      kl: 12,
      inn: 13,
      ch: 11,
      ff: 10,
      ge: 12,
      ko: 14,
      kk: 13,
    ),
    apTotal: 1000,
    apSpent: 500,
    apAvailable: 500,
  );

  Future<KartoVerlassenPruefung> pumpBody(
    WidgetTester tester,
    FakeRepository repository, {
    String heroId = 'demo',
    bool korrekturenGesperrt = false,
  }) async {
    KartoVerlassenPruefung? leaveGuard;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repository),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WorkspaceManagementBody(
              heroId: heroId,
              korrekturenGesperrt: korrekturenGesperrt,
              onVerlassenRegistriert: (guard) => leaveGuard = guard,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(leaveGuard, isNotNull);
    return leaveGuard!;
  }

  Future<void> beginDirtyOverview(WidgetTester tester) async {
    final editText = find.text('Bearbeiten');
    if (editText.evaluate().isNotEmpty) {
      await tester.tap(editText.first);
    } else {
      await tester.tap(find.byTooltip('Bearbeiten').first);
    }
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('overview-field-name')),
      'Rondra geändert',
    );
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final saveText = find.text('Speichern');
    if (saveText.evaluate().isNotEmpty) {
      await tester.tap(saveText.first);
    } else {
      await tester.tap(find.byTooltip('Speichern').first);
    }
  }

  Future<Future<bool>> requestLeave(
    WidgetTester tester,
    KartoVerlassenPruefung guard,
  ) async {
    final result = guard();
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows every visible canonical section but hides magic', (
    tester,
  ) async {
    await pumpBody(tester, FakeRepository(heroes: <HeroSheet>[hero()]));

    for (final label in <String>[
      'Übersicht',
      'Talente',
      'Kampf',
      'Inventar',
      'Chroniken, Kontakte & Abenteuer',
      'Reisebericht',
      'Begleiter',
      'Gruppe',
    ]) {
      expect(find.widgetWithText(Tab, label), findsOneWidget);
    }
    expect(find.widgetWithText(Tab, 'Magie'), findsNothing);
  });

  testWidgets('shows an explained empty state for an unknown hero', (
    tester,
  ) async {
    await pumpBody(tester, FakeRepository.empty(), heroId: 'missing');

    expect(find.text('Held nicht gefunden.'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('shows a distinct error when the hero index fails', (
    tester,
  ) async {
    await pumpBody(tester, _FailingIndexRepository());

    expect(
      find.text('Heldenverwaltung konnte nicht geladen werden.'),
      findsOneWidget,
    );
    expect(find.text('Held nicht gefunden.'), findsNothing);
  });

  testWidgets('shows loading while the hero index has no value', (
    tester,
  ) async {
    KartoVerlassenPruefung? guard;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(_LoadingIndexRepository()),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WorkspaceManagementBody(
              heroId: 'demo',
              korrekturenGesperrt: false,
              onVerlassenRegistriert: (value) => guard = value,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(guard, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Held nicht gefunden.'), findsNothing);
  });

  testWidgets('keeps its header usable at 320 dp and text scale two', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpBody(tester, FakeRepository(heroes: <HeroSheet>[hero()]));

    expect(tester.takeException(), isNull);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byTooltip('Bearbeiten'), findsOneWidget);
  });

  testWidgets('blocks the complete management surface during planning', (
    tester,
  ) async {
    await pumpBody(
      tester,
      FakeRepository(heroes: <HeroSheet>[hero()]),
      korrekturenGesperrt: true,
    );

    expect(find.textContaining('Entwicklung'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Bearbeiten'), findsNothing);
  });

  testWidgets('cancel keeps the draft and refuses leaving', (tester) async {
    final guard = await pumpBody(
      tester,
      FakeRepository(heroes: <HeroSheet>[hero()]),
    );
    await beginDirtyOverview(tester);

    final result = await requestLeave(tester, guard);
    await tester.tap(find.widgetWithText(TextButton, 'Nein'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('overview-field-name')),
    );
    expect(field.controller?.text, 'Rondra geändert');
  });

  testWidgets('leaving a clean editor closes its local snapshot', (
    tester,
  ) async {
    final guard = await pumpBody(
      tester,
      FakeRepository(heroes: <HeroSheet>[hero()]),
    );
    final editText = find.text('Bearbeiten');
    await tester.tap(
      editText.evaluate().isNotEmpty
          ? editText.first
          : find.byTooltip('Bearbeiten').first,
    );
    await tester.pumpAndSettle();

    expect(await guard(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Bearbeiten'), findsOneWidget);
    expect(find.text('Speichern'), findsNothing);
  });

  testWidgets('discard clears the draft and allows leaving', (tester) async {
    final repository = FakeRepository(heroes: <HeroSheet>[hero()]);
    final guard = await pumpBody(tester, repository);
    await beginDirtyOverview(tester);

    final result = await requestLeave(tester, guard);
    await tester.tap(find.text('Ja'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    expect((await repository.loadHeroById('demo'))?.name, 'Rondra');
  });

  testWidgets(
    'save waits, blocks a duplicate leave and checks real dirty state',
    (tester) async {
      final repository = _ControlledSaveRepository(hero());
      final guard = await pumpBody(tester, repository);
      await beginDirtyOverview(tester);

      final firstResult = await requestLeave(tester, guard);
      await tester.tap(find.text('Änderungen speichern'));
      await tester.pump();

      expect(repository.saveStarted, isTrue);
      expect(await guard(), isFalse);
      expect(find.byType(TabBar), findsOneWidget);

      repository.completeSave();
      await tester.pumpAndSettle();
      expect(await firstResult, isTrue);
      expect((await repository.loadHeroById('demo'))?.name, 'Rondra geändert');
    },
  );

  testWidgets('direct slow save blocks leaving until the write completes', (
    tester,
  ) async {
    final repository = _ControlledSaveRepository(hero());
    final guard = await pumpBody(tester, repository);
    await beginDirtyOverview(tester);

    await tapSave(tester);
    await tester.pump();

    expect(repository.saveStarted, isTrue);
    expect(await guard(), isFalse);
    expect(find.textContaining('Ungespeicherte'), findsNothing);

    repository.completeSave();
    await tester.pumpAndSettle();
    expect((await repository.loadHeroById('demo'))?.name, 'Rondra geändert');
  });

  testWidgets('direct save failure is visible and keeps the editor', (
    tester,
  ) async {
    final repository = _FailingSaveRepository(hero());
    await pumpBody(tester, repository);
    await beginDirtyOverview(tester);

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Speichern fehlgeschlagen'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('overview-field-name')),
      findsOneWidget,
    );
  });

  testWidgets('save failure keeps the draft visible and refuses leaving', (
    tester,
  ) async {
    final repository = _FailingSaveRepository(hero());
    final guard = await pumpBody(tester, repository);
    await beginDirtyOverview(tester);

    final result = await requestLeave(tester, guard);
    await tester.tap(find.text('Änderungen speichern'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
    expect(find.textContaining('Speichern fehlgeschlagen'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('overview-field-name')),
    );
    expect(field.controller?.text, 'Rondra geändert');
  });
}

class _ControlledSaveRepository extends FakeRepository {
  _ControlledSaveRepository(HeroSheet hero) : super(heroes: <HeroSheet>[hero]);

  final Completer<void> _saveCompleter = Completer<void>();
  bool saveStarted = false;

  @override
  /// Verzögert das Speichern, bis der Test den Schreibvorgang freigibt.
  Future<void> saveHero(HeroSheet hero) async {
    saveStarted = true;
    await _saveCompleter.future;
    await super.saveHero(hero);
  }

  /// Gibt den im Test kontrollierten Schreibvorgang frei.
  void completeSave() => _saveCompleter.complete();
}

class _FailingSaveRepository extends FakeRepository {
  _FailingSaveRepository(HeroSheet hero) : super(heroes: <HeroSheet>[hero]);

  @override
  /// Simuliert einen sichtbaren Persistenzfehler.
  Future<void> saveHero(HeroSheet hero) async {
    throw StateError('Testfehler');
  }
}

class _FailingIndexRepository extends FakeRepository {
  _FailingIndexRepository() : super();

  @override
  /// Liefert einen fehlerhaften Heldenindex.
  Stream<Map<String, HeroSheet>> watchHeroIndex() {
    return Stream<Map<String, HeroSheet>>.error(StateError('Indexfehler'));
  }
}

class _LoadingIndexRepository extends FakeRepository {
  _LoadingIndexRepository() : super();

  @override
  /// Hält den Heldenindex dauerhaft im Ladezustand.
  Stream<Map<String, HeroSheet>> watchHeroIndex() {
    return const Stream<Map<String, HeroSheet>>.empty();
  }
}
