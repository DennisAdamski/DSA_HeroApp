import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import 'karto_test_support.dart';

/// Beobachtet echte Schreibwege, ohne den Sitzungscontroller zu ersetzen.
class AcceptanceRepository extends FakeRepository {
  /// Nutzt ausschließlich die expliziten Testhelden und Laufzeitzustände.
  AcceptanceRepository({required super.heroes, super.states});

  /// Erfolgreich gespeicherte Helden in ihrer Schreibreihenfolge.
  final List<HeroSheet> heroWrites = [];

  /// Erfolgreich gespeicherte Laufzeitzustände in ihrer Schreibreihenfolge.
  final List<HeroState> stateWrites = [];

  /// Protokolliert erst nach dem tatsächlichen Schreiben im Testrepository.
  @override
  Future<void> saveHero(HeroSheet hero) async {
    await super.saveHero(hero);
    heroWrites.add(hero);
  }

  /// Hält Proben und Heldenbogenänderungen getrennt beobachtbar.
  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    await super.saveHeroState(heroId, state);
    stateWrites.add(state);
  }
}

/// Baut den echten UI2-Workspace mit Bestandsbrücke und gemeinsamen Providern.
Future<ProviderContainer> pumpAcceptanceWorkspace(
  WidgetTester tester, {
  required AcceptanceRepository repository,
  String? selectedHeroId,
  Size size = const Size(1440, 1000),
  Brightness brightness = Brightness.light,
  double textScale = 1,
  GlobalKey? screenshotKey,
  HeroTransferFileGateway? transferGateway,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final settings = _AcceptanceSettings();
  addTearDown(settings.close);
  final container = ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      heroRepositoryProvider.overrideWithValue(repository),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      if (transferGateway != null)
        heroTransferFileGatewayProvider.overrideWithValue(transferGateway),
      if (transferGateway != null)
        catalogRuntimeDataProvider.overrideWith((ref) async {
          final source = CatalogSourceData(
            version: 'test',
            source: 'acceptance',
            metadata: const {},
            sections: {
              for (final section in editableCatalogSections) section: const [],
            },
            reisebericht: const [],
          );
          return CatalogRuntimeData.resolve(
            baseData: source,
            customSnapshot: const CustomCatalogSnapshot(),
          );
        }),
    ],
  );
  addTearDown(container.dispose);
  if (selectedHeroId != null) {
    await container
        .read(selectedHeroSelectionActionsProvider)
        .selectHero(selectedHeroId);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildKartoTheme(
          brightness: brightness,
          centerAppBarTitle: false,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(key: screenshotKey, child: child!),
        ),
        home: const KartoShell(bestand: KartoBestandsAdapterImpl()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

// Isoliert Geräteeinstellungen einschließlich ihrer reaktiven Schreibpfade.
class _AcceptanceSettings implements HiveSettingsRepository {
  AppSettings _value = const AppSettings(oberflaeche: Oberflaeche.kartograph);
  final _changes = StreamController<AppSettings>.broadcast();

  @override
  AppSettings load() => _value;

  @override
  Future<void> save(AppSettings settings) async {
    _value = settings;
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

/// Wechselt über das sichtbare Navigationsziel, einschließlich Leave-Guard.
Future<void> selectAcceptanceMode(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(label).first);
  await tester.pumpAndSettle();
}

/// Nutzt dieselbe benannte Editoraktion auf schmalen und breiten Ansichten.
Future<void> pressAcceptanceAction(WidgetTester tester, String label) async {
  final tooltip = find.byTooltip(label);
  final action = tooltip.evaluate().isEmpty ? find.text(label) : tooltip;
  await tester.tap(action.first);
  await tester.pumpAndSettle();
}
