import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
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
}
