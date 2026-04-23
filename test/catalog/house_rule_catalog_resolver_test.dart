import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_catalog_resolver.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_provenance.dart';
import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';

void main() {
  CatalogSourceData buildBaseData() {
    return CatalogSourceData(
      version: 'house_rules_v1',
      source: 'test',
      metadata: const <String, dynamic>{},
      sections: <CatalogSectionId, List<Map<String, dynamic>>>{
        CatalogSectionId.talents: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'tal_klettern',
            'name': 'Klettern',
            'group': 'Körperliche Talente',
            'steigerung': 'D',
            'attributes': <String>['MU', 'GE', 'KK'],
            'active': true,
          },
          <String, dynamic>{
            'id': 'tal_akrobatik',
            'name': 'Akrobatik',
            'group': 'Koerperliche Talente',
            'steigerung': 'D',
            'attributes': <String>['MU', 'GE', 'KK'],
            'active': true,
          },
          <String, dynamic>{
            'id': 'tal_sagen',
            'name': 'Sagen & Legenden',
            'group': 'Wissenstalente',
            'steigerung': 'C',
            'attributes': <String>['KL', 'KL', 'IN'],
            'active': true,
          },
        ],
        CatalogSectionId.combatSpecialAbilities: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'ksf_episch',
            'name': 'Epischer Stil',
            'gruppe': 'kampf',
            'typ': 'sonderfertigkeit',
            'seite': '1',
            'beschreibung': 'Nur episch',
            'erklarung_lang': '',
            'voraussetzungen': '',
            'verbreitung': '',
            'kosten': '200',
            'aktiviert_manoever_ids': <String>[],
            'kampfwert_boni': <Map<String, dynamic>>[],
            'ruleMeta': <String, dynamic>{
              'origin': 'house_rule',
              'sourceKey': 'epic_rules_v1.combat_sf',
            },
          },
        ],
      },
      reisebericht: const <Map<String, dynamic>>[],
    );
  }

  Map<String, dynamic> findEntry(
    CatalogSourceData data,
    CatalogSectionId section,
    String entryId,
  ) {
    return data
        .entriesFor(section)
        .firstWhere((entry) => entry['id'] == entryId);
  }

  test('tag and entry patches resolve talent complexity with provenance', () {
    const packCatalog = HouseRulePackCatalog(
      packs: <HouseRulePackManifest>[
        HouseRulePackManifest(
          id: 'group_patch',
          title: 'Körperliche Talente',
          description: 'Alle körperlichen Talente auf C',
          priority: 10,
          patches: <HouseRulePatch>[
            HouseRulePatch(
              section: CatalogSectionId.talents,
              selector: HouseRuleSelector(
                hasTags: <String>['talent.group.koerper'],
              ),
              setFields: <String, dynamic>{'steigerung': 'C'},
              addEntries: <Map<String, dynamic>>[],
              deactivateEntries: false,
            ),
          ],
        ),
        HouseRulePackManifest(
          id: 'entry_patch',
          title: 'Klettern-Ausnahme',
          description: 'Klettern auf B',
          priority: 20,
          patches: <HouseRulePatch>[
            HouseRulePatch(
              section: CatalogSectionId.talents,
              selector: HouseRuleSelector(entryId: 'tal_klettern'),
              setFields: <String, dynamic>{'steigerung': 'B'},
              addEntries: <Map<String, dynamic>>[],
              deactivateEntries: false,
            ),
          ],
        ),
        HouseRulePackManifest(
          id: 'conflict_patch',
          title: 'Konflikt',
          description: 'Gleiche Priorität wird ignoriert',
          priority: 20,
          patches: <HouseRulePatch>[
            HouseRulePatch(
              section: CatalogSectionId.talents,
              selector: HouseRuleSelector(entryId: 'tal_klettern'),
              setFields: <String, dynamic>{'steigerung': 'A'},
              addEntries: <Map<String, dynamic>>[],
              deactivateEntries: false,
            ),
          ],
        ),
      ],
    );

    final result = HouseRuleCatalogResolver.resolve(
      baseData: buildBaseData(),
      packCatalog: packCatalog,
      activePackIds: const <String>{
        'group_patch',
        'entry_patch',
        'conflict_patch',
      },
    );

    final klettern = findEntry(
      result.resolvedBaseData,
      CatalogSectionId.talents,
      'tal_klettern',
    );
    final sagen = findEntry(
      result.resolvedBaseData,
      CatalogSectionId.talents,
      'tal_sagen',
    );
    expect(klettern['steigerung'], 'B');
    expect(sagen['steigerung'], 'C');
    expect(result.issues, hasLength(1));
    expect(result.issues.single.message, contains('gleich hoher Prioritaet'));

    final resolver = CatalogRuleResolver(
      provenanceIndex: result.provenanceIndex,
    );
    final resolution = resolver.resolveTalentComplexity(
      talent: TalentDef.fromJson(klettern),
      gifted: true,
    );
    expect(resolution.baseKomplexitaet, 'D');
    expect(resolution.houseRuleKomplexitaet, 'B');
    expect(resolution.effectiveKomplexitaet, 'A');
    expect(resolution.packId, 'entry_patch');
    expect(resolution.houseRuleHint, 'Basis: D • Hausregel: Klettern-Ausnahme');
  });

  test('pack gated base entries disappear when the pack is inactive', () {
    const packCatalog = HouseRulePackCatalog(
      packs: <HouseRulePackManifest>[
        HouseRulePackManifest(
          id: 'epic_rules_v1',
          title: 'Epische Stufen',
          description: 'Root',
          patches: <HouseRulePatch>[],
        ),
        HouseRulePackManifest(
          id: 'epic_rules_v1.combat_sf',
          parentPackId: 'epic_rules_v1',
          title: 'Epische Kampf-SF',
          description: 'Child',
          patches: <HouseRulePatch>[],
        ),
      ],
    );

    final inactive = HouseRuleCatalogResolver.resolve(
      baseData: buildBaseData(),
      packCatalog: packCatalog,
      activePackIds: const <String>{},
    );
    expect(
      inactive.resolvedBaseData.entriesFor(
        CatalogSectionId.combatSpecialAbilities,
      ),
      isEmpty,
    );

    final active = HouseRuleCatalogResolver.resolve(
      baseData: buildBaseData(),
      packCatalog: packCatalog,
      activePackIds: const <String>{'epic_rules_v1', 'epic_rules_v1.combat_sf'},
    );
    expect(
      active.resolvedBaseData.entriesFor(
        CatalogSectionId.combatSpecialAbilities,
      ),
      hasLength(1),
    );
  });

  test('regelwerk talents pack patches Akrobatik to A* with provenance', () {
    const packCatalog = HouseRulePackCatalog(
      packs: <HouseRulePackManifest>[
        HouseRulePackManifest(
          id: 'regelwerk_ueberarbeitung_v1',
          title: 'Regelwerk-Überarbeitung',
          description: 'Root',
          patches: <HouseRulePatch>[],
        ),
        HouseRulePackManifest(
          id: 'regelwerk_ueberarbeitung_v1.talents_learning',
          parentPackId: 'regelwerk_ueberarbeitung_v1',
          title: 'Körperliche Talente',
          description: 'Kapitel 5',
          patches: <HouseRulePatch>[
            HouseRulePatch(
              section: CatalogSectionId.talents,
              selector: HouseRuleSelector(entryId: 'tal_akrobatik'),
              setFields: <String, dynamic>{'steigerung': 'A*'},
              addEntries: <Map<String, dynamic>>[],
              deactivateEntries: false,
            ),
          ],
        ),
      ],
    );

    final result = HouseRuleCatalogResolver.resolve(
      baseData: buildBaseData(),
      packCatalog: packCatalog,
      activePackIds: const <String>{
        'regelwerk_ueberarbeitung_v1',
        'regelwerk_ueberarbeitung_v1.talents_learning',
      },
    );

    final akrobatik = findEntry(
      result.resolvedBaseData,
      CatalogSectionId.talents,
      'tal_akrobatik',
    );
    expect(akrobatik['steigerung'], 'A*');

    final resolver = CatalogRuleResolver(
      provenanceIndex: result.provenanceIndex,
    );
    final resolution = resolver.resolveTalentComplexity(
      talent: TalentDef.fromJson(akrobatik),
      gifted: true,
    );
    expect(resolution.baseKomplexitaet, 'D');
    expect(resolution.houseRuleKomplexitaet, 'A*');
    expect(resolution.effectiveKomplexitaet, 'A*');
    expect(resolution.packId, 'regelwerk_ueberarbeitung_v1.talents_learning');
  });

  test(
    'runtime merge blocks custom ids that collide with pack-added entries',
    () {
      const packCatalog = HouseRulePackCatalog(
        packs: <HouseRulePackManifest>[
          HouseRulePackManifest(
            id: 'bonus_pack',
            title: 'Bonus',
            description: 'Fuegt einen Eintrag hinzu',
            patches: <HouseRulePatch>[
              HouseRulePatch(
                section: CatalogSectionId.talents,
                setFields: <String, dynamic>{},
                addEntries: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'tal_bonus',
                    'name': 'Bonuswissen',
                    'group': 'Wissenstalente',
                    'steigerung': 'B',
                    'attributes': <String>['KL', 'KL', 'IN'],
                    'active': true,
                  },
                ],
                deactivateEntries: false,
              ),
            ],
          ),
        ],
      );
      final resolved = HouseRuleCatalogResolver.resolve(
        baseData: buildBaseData(),
        packCatalog: packCatalog,
        activePackIds: const <String>{'bonus_pack'},
      );

      final runtimeData = CatalogRuntimeData.resolve(
        baseData: buildBaseData(),
        resolvedBaseData: resolved.resolvedBaseData,
        customSnapshot: const CustomCatalogSnapshot(
          entries: <CustomCatalogEntryRecord>[
            CustomCatalogEntryRecord(
              section: CatalogSectionId.talents,
              id: 'tal_bonus',
              filePath: 'C:/tmp/tal_bonus.json',
              data: <String, dynamic>{
                'id': 'tal_bonus',
                'name': 'Duplikat',
                'group': 'Wissenstalente',
                'steigerung': 'A',
                'attributes': <String>['KL', 'KL', 'IN'],
                'active': true,
              },
            ),
          ],
        ),
        packCatalog: packCatalog,
        activeHouseRulePackIds: const <String>{'bonus_pack'},
        houseRuleProvenanceIndex: resolved.provenanceIndex,
        houseRuleIssues: resolved.issues,
      );

      final effectiveIds = runtimeData.effectiveData
          .entriesFor(CatalogSectionId.talents)
          .map((entry) => entry['id'])
          .toList(growable: false);
      expect(
        effectiveIds.where((entryId) => entryId == 'tal_bonus'),
        hasLength(1),
      );
      expect(runtimeData.issues, hasLength(1));
      expect(runtimeData.issues.single.message, contains('kollidiert'));
    },
  );
}
