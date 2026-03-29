import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

void main() {
  ProviderContainer buildContainer(
    FakeRepository repo, {
    CatalogRuntimeData? runtimeData,
    CustomCatalogRepository? customCatalogRepository,
  }) {
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        catalogRuntimeDataProvider.overrideWith(
          (ref) async => runtimeData ?? _buildRuntimeData(),
        ),
        customCatalogRepositoryProvider.overrideWithValue(
          customCatalogRepository ??
              const CustomCatalogRepository(heroStoragePath: ''),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('buildExportJson includes required envelope fields', () async {
    final repo = FakeRepository(
      heroes: [
        const HeroSheet(
          id: 'h1',
          name: 'Test',
          level: 1,
          attributes: Attributes(
            mu: 8,
            kl: 8,
            inn: 8,
            ch: 8,
            ff: 8,
            ge: 8,
            ko: 8,
            kk: 8,
          ),
        ),
      ],
      states: {
        'h1': const HeroState(
          currentLep: 20,
          currentAsp: 5,
          currentKap: 0,
          currentAu: 30,
        ),
      },
    );
    final container = buildContainer(repo);
    final actions = container.read(heroActionsProvider);

    final raw = await actions.buildExportJson('h1');
    final map = jsonDecode(raw) as Map<String, dynamic>;

    expect(map['kind'], HeroTransferBundle.kind);
    expect(
      map['transferSchemaVersion'],
      HeroTransferBundle.transferSchemaVersion,
    );
    expect(map['exportedAt'], isA<String>());
    expect(map['hero'], isA<Map>());
    expect(map['state'], isA<Map>());
  });

  test('buildExportJson embeds referenced custom catalog entries', () async {
    final repo = FakeRepository(
      heroes: [
        const HeroSheet(
          id: 'h1',
          name: 'Test',
          level: 1,
          attributes: Attributes(
            mu: 8,
            kl: 8,
            inn: 8,
            ch: 8,
            ff: 8,
            ge: 8,
            ko: 8,
            kk: 8,
          ),
          talents: <String, HeroTalentEntry>{
            'tal_custom': HeroTalentEntry(),
          },
          spells: <String, HeroSpellEntry>{
            'spell_custom': HeroSpellEntry(),
          },
          sprachen: <String, HeroLanguageEntry>{
            'spr_custom': HeroLanguageEntry(),
          },
          muttersprache: 'spr_custom',
        ),
      ],
      states: {
        'h1': const HeroState(
          currentLep: 20,
          currentAsp: 5,
          currentKap: 0,
          currentAu: 30,
        ),
      },
    );
    final runtimeData = _buildRuntimeData(
      customEntries: <CustomCatalogEntryRecord>[
        CustomCatalogEntryRecord(
          section: CatalogSectionId.talents,
          id: 'tal_custom',
          filePath: '/tmp/tal_custom.json',
          data: const <String, dynamic>{
            'id': 'tal_custom',
            'name': 'Hauswissen',
            'group': 'Wissen',
            'steigerung': 'B',
            'attributes': <String>['KL', 'KL', 'IN'],
            'active': true,
          },
        ),
        CustomCatalogEntryRecord(
          section: CatalogSectionId.spells,
          id: 'spell_custom',
          filePath: '/tmp/spell_custom.json',
          data: const <String, dynamic>{
            'id': 'spell_custom',
            'name': 'Hauszauber',
            'tradition': 'Gildenmagie',
            'steigerung': 'C',
            'attributes': <String>['KL', 'IN', 'CH'],
            'active': true,
          },
        ),
        CustomCatalogEntryRecord(
          section: CatalogSectionId.sprachen,
          id: 'spr_custom',
          filePath: '/tmp/spr_custom.json',
          data: const <String, dynamic>{
            'id': 'spr_custom',
            'name': 'Geheimsprache',
            'familie': 'Test',
            'maxWert': 18,
            'steigerung': 'A',
            'schriftIds': <String>['sch_custom'],
            'schriftlos': false,
          },
        ),
        CustomCatalogEntryRecord(
          section: CatalogSectionId.schriften,
          id: 'sch_custom',
          filePath: '/tmp/sch_custom.json',
          data: const <String, dynamic>{
            'id': 'sch_custom',
            'name': 'Geheimschrift',
            'maxWert': 10,
            'steigerung': 'A',
          },
        ),
      ],
    );
    final container = buildContainer(repo, runtimeData: runtimeData);
    final actions = container.read(heroActionsProvider);

    final raw = await actions.buildExportJson('h1');
    final bundle = HeroTransferBundle.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );

    final ids = bundle.catalogEntries!.map((entry) => entry.id).toSet();
    expect(ids, containsAll(<String>[
      'tal_custom',
      'spell_custom',
      'spr_custom',
      'sch_custom',
    ]));
  });

  test('createHero stores raw and effective start attributes', () async {
    final repo = FakeRepository.empty();
    final container = buildContainer(repo);
    final actions = container.read(heroActionsProvider);

    final heroId = await actions.createHero(
      name: 'Startheld',
      rawStartAttributes: const Attributes(
        mu: 12,
        kl: 13,
        inn: 11,
        ch: 10,
        ff: 9,
        ge: 8,
        ko: 7,
        kk: 6,
      ),
    );

    final hero = await repo.loadHeroById(heroId);
    expect(hero, isNotNull);
    expect(hero!.name, 'Startheld');
    expect(hero.rawStartAttributes.kl, 13);
    expect(hero.startAttributes.kl, 13);
    expect(hero.attributes.kl, 13);
    expect(hero.talents.keys, contains('tal_klettern'));
    expect(hero.metaTalents.single.id, 'meta_kraeutersuchen');
  });

  test('importHeroBundle stores embedded custom catalog entries', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'hero_actions_import_export_test',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final repo = FakeRepository.empty();
    final runtimeData = _buildRuntimeData();
    final customRepository = CustomCatalogRepository(
      heroStoragePath: tempDir.path,
    );
    final container = buildContainer(
      repo,
      runtimeData: runtimeData,
      customCatalogRepository: customRepository,
    );
    final actions = container.read(heroActionsProvider);

    final bundle = HeroTransferBundle(
      exportedAt: DateTime.utc(2026, 2, 22),
      hero: const HeroSheet(
        id: 'new-id',
        name: 'Importiert',
        level: 1,
        attributes: Attributes(
          mu: 8,
          kl: 8,
          inn: 8,
          ch: 8,
          ff: 8,
          ge: 8,
          ko: 8,
          kk: 8,
        ),
      ),
      state: const HeroState(
        currentLep: 12,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 18,
        tempAttributeMods: AttributeModifiers(mu: 3),
      ),
      catalogEntries: const <HeroTransferCatalogEntry>[
        HeroTransferCatalogEntry(
          section: CatalogSectionId.talents,
          id: 'tal_custom',
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
    );

    await actions.importHeroBundle(
      bundle,
      resolution: ImportConflictResolution.overwriteExisting,
    );

    final snapshot = await customRepository.load(
      catalogVersion: runtimeData.baseData.version,
    );
    expect(snapshot.entries, hasLength(1));
    expect(snapshot.entries.single.id, 'tal_custom');
    expect(snapshot.issues, isEmpty);
    expect((await repo.listHeroes()).single.id, 'new-id');
  });
}

CatalogRuntimeData _buildRuntimeData({
  String version = 'house_rules_v1',
  List<CustomCatalogEntryRecord> customEntries = const <CustomCatalogEntryRecord>[],
}) {
  final baseData = CatalogSourceData(
    version: version,
    source: 'tests',
    metadata: const <String, dynamic>{},
    sections: <CatalogSectionId, List<Map<String, dynamic>>>{
      for (final section in editableCatalogSections)
        section: const <Map<String, dynamic>>[],
    },
    reisebericht: const <Map<String, dynamic>>[],
  );
  final snapshot = CustomCatalogSnapshot(entries: customEntries);
  return CatalogRuntimeData.resolve(
    baseData: baseData,
    customSnapshot: snapshot,
  );
}
