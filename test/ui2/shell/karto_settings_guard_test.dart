import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_app_root.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_workspace.dart';

import 'karto_test_support.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    for (final decision in ['Verwerfen', 'Übernehmen']) {
      testWidgets('Oberflächenwechsel bei $width: Weiterplanen und $decision', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 950);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = _SettingsRepository();
        final heroes = _SaveRepository();
        final container = ProviderContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            heroRepositoryProvider.overrideWithValue(heroes),
            rulesCatalogProvider.overrideWith((ref) async => testCatalog),
          ],
        );
        addTearDown(settings.close);
        addTearDown(container.dispose);
        await container
            .read(selectedHeroSelectionActionsProvider)
            .selectHero('rondra');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AppRootSwitch()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Entwicklung planen').first);
        await tester.pumpAndSettle();
        final provider = advancementSessionProvider('rondra');
        final sessionId = container.read(provider)!.sessionId;
        if (decision == 'Übernehmen') {
          container
              .read(provider.notifier)
              .add(
                HeroAdvancementEntry(
                  id: 'mut',
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
        }
        await tester.tap(find.byTooltip('Workspace-Menü'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Einstellungen'));
        await tester.pumpAndSettle();
        expect(find.text('Entwicklung noch in Planung'), findsNothing);
        if (width < 1000) {
          await tester.tap(
            find.byKey(const ValueKey('settings-menu-appearance')),
          );
          await tester.pumpAndSettle();
        }
        final toggle = find.byKey(const ValueKey('settings-oberflaeche'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Entwicklung noch in Planung'), findsOneWidget);
        expect(settings.load().oberflaeche, Oberflaeche.kartograph);
        await tester.tap(find.text('Weiterplanen'));
        await tester.pumpAndSettle();
        expect(container.read(provider)!.sessionId, sessionId);
        expect(settings.load().oberflaeche, Oberflaeche.kartograph);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await tester.tap(find.text(decision).last);
        await tester.pumpAndSettle();
        if (decision == 'Übernehmen') {
          expect(find.textContaining('Speicherfehler'), findsOneWidget);
          expect(settings.load().oberflaeche, Oberflaeche.kartograph);
          expect(container.read(provider)!.sessionId, sessionId);
          expect((await heroes.loadHeroById('rondra'))!.attributes.mu, 14);
          heroes.fail = false;
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          await tester.tap(find.text(decision).last);
          await tester.pumpAndSettle();
          expect((await heroes.loadHeroById('rondra'))!.attributes.mu, 15);
        }
        expect(settings.load().oberflaeche, Oberflaeche.codex);
        expect(container.read(provider), isNull);
        // Der verdeckte Root wird erst beim Zurückkehren wieder aufgebaut.
        Navigator.of(tester.element(toggle)).popUntil((route) => route.isFirst);
        await tester.pumpAndSettle();
        expect(find.byType(KartoWorkspace, skipOffstage: false), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

// Lässt dieselbe Planung nach einem Schreibfehler erfolgreich erneut übernehmen.
class _SaveRepository extends FakeRepository {
  _SaveRepository() : super(heroes: [testHero()]);
  bool fail = true;

  @override
  Future<void> saveHero(HeroSheet hero) async {
    if (fail) throw StateError('Speicherfehler');
    await super.saveHero(hero);
  }
}

// Hält die echte Settings-Aktion reaktiv, ohne lokale Benutzerdaten zu ändern.
class _SettingsRepository implements HiveSettingsRepository {
  AppSettings _settings = const AppSettings(
    oberflaeche: Oberflaeche.kartograph,
  );
  final _changes = StreamController<AppSettings>.broadcast();

  @override
  AppSettings load() => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
    _changes.add(settings);
  }

  @override
  Stream<AppSettings> watch() => _changes.stream;

  @override
  Future<void> close() => _changes.close();

  @override
  Future<void> attachUser(String uid, {Object? remote, Object? cipher}) async {}

  @override
  Future<void> detachUser() async {}

  @override
  bool get isAttached => false;

  @override
  String? get attachedUid => null;
}
