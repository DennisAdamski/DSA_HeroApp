import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack_admin.dart';
import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rule_pack_admin_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/house_rule_pack_management_screen.dart';

void main() {
  testWidgets('shows imported and built-in packs with management actions', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Hausregelverwaltung'), findsOneWidget);
    expect(find.text('Importierte Pakete'), findsOneWidget);
    expect(find.text('+ Hausregelpaket'), findsOneWidget);
    expect(find.text('Importieren'), findsOneWidget);
    expect(find.text('Importiertes Paket'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Eingebaute Pakete'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Eingebaute Pakete'), findsOneWidget);
    expect(find.text('Eingebautes Paket'), findsOneWidget);
    expect(find.text('Als Vorlage klonen'), findsOneWidget);
  });

  testWidgets('tapping imported pack opens the editor screen', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importiertes Paket'));
    await tester.pumpAndSettle();

    expect(find.text('Hausregelpaket bearbeiten'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('house-rule-pack-id')),
      findsOneWidget,
    );
  });

  testWidgets('built-in packs can be cloned into a new editor draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          houseRulePackAdminSnapshotProvider.overrideWith(
            (ref) async => _buildSnapshot(),
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
          catalogRuntimeDataProvider.overrideWith((ref) async {
            throw UnimplementedError('Not used in clone test.');
          }),
          houseRulePackAdminActionsProvider.overrideWith(
            (ref) => _FakeHouseRulePackAdminActions(ref),
          ),
        ],
        child: const MaterialApp(home: HouseRulePackManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Als Vorlage klonen'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Als Vorlage klonen'));
    await tester.pumpAndSettle();

    final idField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('house-rule-pack-id')),
    );
    expect(idField.controller!.text, 'built_in_pack_copy');
    expect(find.text('Hausregelpaket aus Vorlage klonen'), findsOneWidget);
  });
}

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      houseRulePackAdminSnapshotProvider.overrideWith(
        (ref) async => _buildSnapshot(),
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
    child: const MaterialApp(home: HouseRulePackManagementScreen()),
  );
}

HouseRulePackAdminSnapshot _buildSnapshot() {
  return const HouseRulePackAdminSnapshot(
    catalogVersion: 'house_rules_v1',
    builtInPacks: <HouseRulePackAdminEntry>[
      HouseRulePackAdminEntry(
        manifest: HouseRulePackManifest(
          id: 'built_in_pack',
          title: 'Eingebautes Paket',
          description: 'Read-only package',
          patches: <HouseRulePatch>[],
          isBuiltIn: true,
        ),
        isBuiltIn: true,
        isActive: true,
        issues: <HouseRulePackIssue>[],
      ),
    ],
    importedPacks: <HouseRulePackAdminEntry>[
      HouseRulePackAdminEntry(
        manifest: HouseRulePackManifest(
          id: 'imported_pack',
          title: 'Importiertes Paket',
          description: 'Editable package',
          patches: <HouseRulePatch>[],
        ),
        isBuiltIn: false,
        isActive: false,
        issues: <HouseRulePackIssue>[],
      ),
    ],
    issues: <HouseRulePackIssue>[
      HouseRulePackIssue(
        packId: 'imported_pack',
        packTitle: 'Importiertes Paket',
        message: 'Beispielwarnung',
      ),
    ],
  );
}

class _FakeHouseRulePackAdminActions extends HouseRulePackAdminActions {
  _FakeHouseRulePackAdminActions(super.ref);

  @override
  Future<String> suggestCopyPackId(String basePackId) async {
    return '${basePackId}_copy';
  }
}
