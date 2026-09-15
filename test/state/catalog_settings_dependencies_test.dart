import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

void main() {
  test('table widths do not refresh the catalog pipeline', () async {
    final settingsUpdates = StreamController<AppSettings>();
    addTearDown(settingsUpdates.close);
    final settingsStream = Stream<AppSettings>.value(const AppSettings())
        .asyncExpand((_) => settingsUpdates.stream);
    const sourceData = CatalogSourceData(
      version: 'test',
      source: 'test',
      metadata: <String, dynamic>{},
      sections: <CatalogSectionId, List<Map<String, dynamic>>>{},
      reisebericht: <Map<String, dynamic>>[],
    );
    final container = ProviderContainer(
      overrides: [
        appSettingsProvider.overrideWith((ref) => settingsStream),
        baseCatalogSourceDataProvider.overrideWith((ref) async => sourceData),
        houseRulePackCatalogProvider.overrideWith(
          (ref) async => const HouseRulePackCatalog(),
        ),
        customCatalogRepositoryProvider.overrideWithValue(
          const CustomCatalogRepository(heroStoragePath: ''),
        ),
      ],
    );
    addTearDown(container.dispose);

    var decryptedUpdates = 0;
    var runtimeUpdates = 0;
    final decryptedSubscription = container.listen(
      decryptedCatalogSourceDataProvider,
      (previous, next) => decryptedUpdates++,
    );
    final runtimeSubscription = container.listen(
      catalogRuntimeDataProvider,
      (previous, next) => runtimeUpdates++,
    );
    addTearDown(decryptedSubscription.close);
    addTearDown(runtimeSubscription.close);
    await container.read(decryptedCatalogSourceDataProvider.future);
    await container.read(catalogRuntimeDataProvider.future);
    decryptedUpdates = 0;
    runtimeUpdates = 0;

    settingsUpdates.add(
      AppSettings(
        disabledHouseRulePackIds: Set<String>.unmodifiable(<String>{}),
        tableColumnWidths: const <String, Map<String, double>>{
          'magic.activeSpells': <String, double>{'name': 360},
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(decryptedUpdates, 0);
    expect(runtimeUpdates, 0);
  });

  testWidgets('rebuilding the app scope keeps the resolved catalog', (
    tester,
  ) async {
    const sourceData = CatalogSourceData(
      version: 'test',
      source: 'test',
      metadata: <String, dynamic>{},
      sections: <CatalogSectionId, List<Map<String, dynamic>>>{},
      reisebericht: <Map<String, dynamic>>[],
    );
    var packCatalogBuilds = 0;
    final observed = <AsyncValue<CatalogRuntimeData>>[];
    late StateSetter rebuildScope;
    // Nicht-konstante Variable: Die Repository-Instanzen sollen bei jedem
    // Rebuild neu entstehen, so wie im echten `AppStartupGate`.
    final heroStoragePath = '';

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuildScope = setState;
          // Wie `AppStartupGate._buildScope`: Bei jedem Rebuild entstehen
          // frische Repository-Instanzen fuer die Overrides.
          return ProviderScope(
            overrides: [
              appSettingsProvider.overrideWith(
                (ref) => Stream<AppSettings>.value(const AppSettings()),
              ),
              baseCatalogSourceDataProvider.overrideWith(
                (ref) async => sourceData,
              ),
              houseRulePackCatalogProvider.overrideWith((ref) async {
                ref.watch(houseRulePackRepositoryProvider);
                packCatalogBuilds++;
                return const HouseRulePackCatalog();
              }),
              customCatalogRepositoryProvider.overrideWithValue(
                CustomCatalogRepository(heroStoragePath: heroStoragePath),
              ),
              houseRulePackRepositoryProvider.overrideWithValue(
                HouseRulePackRepository(heroStoragePath: heroStoragePath),
              ),
            ],
            child: Consumer(
              builder: (context, ref, child) {
                observed.add(ref.watch(catalogRuntimeDataProvider));
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(packCatalogBuilds, 1);
    final resolved = observed.last.valueOrNull;
    expect(resolved, isNotNull);

    observed.clear();
    rebuildScope(() {});
    await tester.pumpAndSettle();

    expect(packCatalogBuilds, 1);
    expect(
      observed.every((state) => identical(state.valueOrNull, resolved)),
      isTrue,
      reason: 'Der Katalog darf beim Scope-Rebuild nicht neu laden.',
    );
  });
}
