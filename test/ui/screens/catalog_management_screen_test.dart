import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_management_screen.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

void main() {
  testWidgets('shows catalog overview with section counts and issues', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Katalogverwaltung'), findsOneWidget);
    expect(find.text('Custom-Kataloge im Heldenspeicher'), findsOneWidget);
    expect(find.text('Probleme in Custom-Katalogen'), findsOneWidget);
    expect(find.text('Talente'), findsOneWidget);
    expect(find.textContaining('Basis: 1'), findsOneWidget);
  });

  testWidgets('navigates to section and shows custom detail actions', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Talente'));
    await tester.pumpAndSettle();

    expect(find.text('+ Talent'), findsOneWidget);
    expect(find.text('Hauswissen'), findsOneWidget);

    await tester.tap(find.text('Hauswissen'));
    await tester.pumpAndSettle();

    expect(find.text('Bearbeiten'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
  });
}

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      catalogAdminSnapshotProvider.overrideWith(
        (ref) async => _buildAdminSnapshot(),
      ),
      heroStorageLocationProvider.overrideWith(
        (ref) async => const HeroStorageLocation(
          defaultPath: '/default',
          effectivePath: '/heroes',
          configuredPath: '/heroes',
          customPathSupported: true,
          usesCustomPath: true,
        ),
      ),
    ],
    child: const MaterialApp(home: CatalogManagementScreen()),
  );
}

CatalogAdminSnapshot _buildAdminSnapshot() {
  final baseData = CatalogSourceData(
    version: 'house_rules_v1',
    source: 'tests',
    metadata: const <String, dynamic>{},
    sections: <CatalogSectionId, List<Map<String, dynamic>>>{
      for (final section in editableCatalogSections)
        section: section == CatalogSectionId.talents
            ? const <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'tal_basis',
                  'name': 'Klettern',
                  'group': 'Körperlich',
                  'steigerung': 'B',
                  'attributes': <String>['MU', 'GE', 'KK'],
                  'active': true,
                },
              ]
            : const <Map<String, dynamic>>[],
    },
    reisebericht: const <Map<String, dynamic>>[],
  );
  final runtimeData = CatalogRuntimeData.resolve(
    baseData: baseData,
    customSnapshot: const CustomCatalogSnapshot(
      entries: <CustomCatalogEntryRecord>[
        CustomCatalogEntryRecord(
          section: CatalogSectionId.talents,
          id: 'tal_custom',
          filePath: '/heroes/custom_catalogs/house_rules_v1/talente/tal_custom.json',
          data: <String, dynamic>{
            'id': 'tal_custom',
            'name': 'Hauswissen',
            'group': 'Wissen',
            'steigerung': 'B',
            'attributes': <String>['KL', 'KL', 'IN'],
            'active': true,
          },
        ),
      ],
      issues: <CatalogIssue>[
        CatalogIssue(
          section: CatalogSectionId.talents,
          filePath: '/heroes/custom_catalogs/house_rules_v1/talente/kaputt.json',
          message: 'Datei konnte nicht gelesen werden.',
        ),
      ],
    ),
  );
  return CatalogAdminSnapshot.fromRuntimeData(runtimeData);
}
