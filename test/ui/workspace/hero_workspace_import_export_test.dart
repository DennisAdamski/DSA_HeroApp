import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

class _FakeTransferGateway implements HeroTransferFileGateway {
  _FakeTransferGateway({this.importPayload});

  String? importPayload;
  HeroTransferExportOutcome exportOutcome = const HeroTransferExportOutcome(
    result: HeroTransferExportResult.savedToFile,
  );
  int exportCalls = 0;
  int importCalls = 0;

  @override
  Future<HeroTransferExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  }) async {
    exportCalls++;
    return exportOutcome;
  }

  @override
  Future<String?> pickImportJson() async {
    importCalls++;
    return importPayload;
  }
}

void main() {
  final baseHero = HeroSheet(
    id: 'demo',
    name: 'Rondra',
    level: 1,
    attributes: const Attributes(
      mu: 14,
      kl: 12,
      inn: 13,
      ch: 11,
      ff: 10,
      ge: 12,
      ko: 14,
      kk: 13,
    ),
  );

  testWidgets(
    'home appbar shows export/import actions and export triggers gateway',
    (tester) async {
      final repo = FakeRepository(
        heroes: [baseHero],
        states: {
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
          ),
        },
      );
      final fakeGateway = _FakeTransferGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heroRepositoryProvider.overrideWithValue(repo),
            heroTransferFileGatewayProvider.overrideWithValue(fakeGateway),
            catalogRuntimeDataProvider.overrideWith(
              (ref) async => _buildRuntimeData(),
            ),
          ],
          child: const MaterialApp(home: HeroesHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.upload_file), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);

      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pumpAndSettle();

      expect(fakeGateway.exportCalls, 1);
    },
  );

  testWidgets('import conflict dialog shows overwrite and create new options', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [baseHero],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    final codec = const HeroTransferCodec();
    final conflictBundle = HeroTransferBundle(
      exportedAt: DateTime.utc(2026, 2, 22),
      hero: baseHero.copyWith(name: 'Rondra Import'),
      state: const HeroState(
        currentLep: 22,
        currentAsp: 10,
        currentKap: 0,
        currentAu: 12,
      ),
    );
    final fakeGateway = _FakeTransferGateway(
      importPayload: codec.encode(conflictBundle),
    );

    await tester.pumpWidget(
      ProviderScope(
          overrides: [
            heroRepositoryProvider.overrideWithValue(repo),
            heroTransferFileGatewayProvider.overrideWithValue(fakeGateway),
            catalogRuntimeDataProvider.overrideWith(
              (ref) async => _buildRuntimeData(),
            ),
          ],
          child: const MaterialApp(home: HeroesHomeScreen()),
        ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(find.text('Held bereits vorhanden'), findsOneWidget);
    expect(find.text('Überschreiben'), findsOneWidget);
    expect(find.text('Als neu erstellen'), findsOneWidget);
  });

  testWidgets('successful import opens imported hero workspace', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [baseHero],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    final codec = const HeroTransferCodec();
    final importedBundle = HeroTransferBundle(
      exportedAt: DateTime.utc(2026, 2, 22),
      hero: const HeroSheet(
        id: 'new-hero-id',
        name: 'Import Held',
        level: 2,
        attributes: Attributes(
          mu: 12,
          kl: 10,
          inn: 11,
          ch: 10,
          ff: 9,
          ge: 11,
          ko: 12,
          kk: 12,
        ),
      ),
      state: const HeroState(
        currentLep: 25,
        currentAsp: 7,
        currentKap: 0,
        currentAu: 24,
      ),
    );
    final fakeGateway = _FakeTransferGateway(
      importPayload: codec.encode(importedBundle),
    );

    await tester.pumpWidget(
      ProviderScope(
          overrides: [
            heroRepositoryProvider.overrideWithValue(repo),
            heroTransferFileGatewayProvider.overrideWithValue(fakeGateway),
            catalogRuntimeDataProvider.overrideWith(
              (ref) async => _buildRuntimeData(),
            ),
          ],
          child: const MaterialApp(home: HeroesHomeScreen()),
        ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(find.text('Import Held'), findsWidgets);
  });
}

CatalogRuntimeData _buildRuntimeData() {
  final baseData = CatalogSourceData(
    version: 'house_rules_v1',
    source: 'tests',
    metadata: const <String, dynamic>{},
    sections: <CatalogSectionId, List<Map<String, dynamic>>>{
      for (final section in editableCatalogSections)
        section: const <Map<String, dynamic>>[],
    },
    reisebericht: const <Map<String, dynamic>>[],
  );
  return CatalogRuntimeData.resolve(
    baseData: baseData,
    customSnapshot: const CustomCatalogSnapshot(),
  );
}
