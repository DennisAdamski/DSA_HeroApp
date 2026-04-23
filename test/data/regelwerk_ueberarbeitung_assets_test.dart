import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';

void main() {
  Map<String, dynamic> readJsonObject(String relativePath) {
    final raw = readRepoFile(relativePath);
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  List<Map<String, dynamic>> readJsonList(String relativePath) {
    final raw = readRepoFile(relativePath);
    return (jsonDecode(raw) as List)
        .cast<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList(growable: false);
  }

  List<Map<String, dynamic>> readManifestAddEntries(String relativePath) {
    final manifest = HouseRulePackManifest.fromJson(
      readJsonObject(relativePath),
    );
    return manifest.patches
        .expand((patch) => patch.addEntries)
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  test('regelwerk ueberarbeitung manifests define the expected hierarchy', () {
    final root = HouseRulePackManifest.fromJson(
      readJsonObject(
        'assets/catalogs/house_rules_v1/packs/regelwerk_ueberarbeitung_v1/manifest.json',
      ),
    );
    final talents = HouseRulePackManifest.fromJson(
      readJsonObject(
        'assets/catalogs/house_rules_v1/packs/regelwerk_ueberarbeitung_v1_talents_learning/manifest.json',
      ),
    );

    expect(root.id, 'regelwerk_ueberarbeitung_v1');
    expect(root.isRoot, isTrue);
    expect(talents.parentPackId, 'regelwerk_ueberarbeitung_v1');
    expect(talents.patches, isNotEmpty);

    final patchedIds = talents.patches
        .map((entry) => entry.selector!.entryId)
        .toSet();
    expect(patchedIds, contains('tal_akrobatik'));
    expect(patchedIds, contains('tal_athletik'));
    expect(patchedIds, contains('tal_zechen'));
  });

  test('body talents use the official WdH baseline before pack overlays', () {
    final talents = readJsonList('assets/catalogs/house_rules_v1/talente.json');
    const affectedIds = <String>{
      'tal_akrobatik',
      'tal_athletik',
      'tal_fliegen',
      'tal_gaukeleien',
      'tal_klettern',
      'tal_koerperbeherrschung',
      'tal_reiten',
      'tal_schleichen',
      'tal_schwimmen',
      'tal_selbstbeherrschung',
      'tal_sich_verstecken',
      'tal_skifahren',
      'tal_singen',
      'tal_sinnesschaerfe',
      'tal_stimmen_imitieren',
      'tal_tanzen',
      'tal_taschendiebstahl',
      'tal_zechen',
    };

    for (final entry in talents.where(
      (candidate) => affectedIds.contains(candidate['id']),
    )) {
      expect(entry['steigerung'], 'D', reason: 'Baseline fuer ${entry['id']}');
      expect(entry['source'], 'Wege der Helden S. 316');
      final ruleMeta = (entry['ruleMeta'] as Map).cast<String, dynamic>();
      expect(ruleMeta['origin'], 'official');
      final citations = (ruleMeta['citations'] as List).cast<Map>();
      expect(citations.single['source'], 'Wege der Helden.pdf');
      expect(citations.single['locator'], 'S. 316');
    }
  });

  test('new entries are pack-gated and epic references stay untouched', () {
    final general = readManifestAddEntries(
      'assets/catalogs/house_rules_v1/packs/regelwerk_ueberarbeitung_v1_general_sf/manifest.json',
    );
    final combatAddEntries = readManifestAddEntries(
      'assets/catalogs/house_rules_v1/packs/regelwerk_ueberarbeitung_v1_combat/manifest.json',
    );
    final magicAddEntries = readManifestAddEntries(
      'assets/catalogs/house_rules_v1/packs/regelwerk_ueberarbeitung_v1_magic/manifest.json',
    );
    final karmal = readManifestAddEntries(
      'assets/catalogs/house_rules_v1/packs/regelwerk_ueberarbeitung_v1_karmal/manifest.json',
    );
    final combatBase = readJsonList(
      'assets/catalogs/house_rules_v1/kampf_sonderfertigkeiten.json',
    );
    final magicBase = readJsonList(
      'assets/catalogs/house_rules_v1/magische_sonderfertigkeiten.json',
    );
    final maneuvers = readJsonList(
      'assets/catalogs/house_rules_v1/manoever.json',
    );

    expect(findById(general, 'asf_berufsgeheimnis_perpetuatoren'), isNotNull);
    expect(
      findSourceKey(general, 'asf_gefuehle_vermitteln'),
      'regelwerk_ueberarbeitung_v1.general_sf',
    );
    expect(
      findSourceKey(combatAddEntries, 'ksf_tierkampf'),
      'regelwerk_ueberarbeitung_v1.combat',
    );
    expect(
      findSourceKey(combatAddEntries, 'ksf_pfeilhagel'),
      'regelwerk_ueberarbeitung_v1.combat',
    );
    expect(
      findSourceKey(magicAddEntries, 'msf_astralbrand'),
      'regelwerk_ueberarbeitung_v1.magic',
    );
    expect(
      findSourceKey(magicAddEntries, 'msf_zaubersaenger'),
      'regelwerk_ueberarbeitung_v1.magic',
    );
    expect(
      findSourceKey(karmal, 'kasf_goettlicher_begleiter'),
      'regelwerk_ueberarbeitung_v1.karmal',
    );
    expect(
      findSourceKey(maneuvers, 'man_seitenwechsel'),
      'regelwerk_ueberarbeitung_v1.combat',
    );
    expect(
      findSourceKey(maneuvers, 'man_offensiver_kampfstil'),
      'regelwerk_ueberarbeitung_v1.combat',
    );

    expect(
      findSourceKey(combatBase, 'esf_rittmeister'),
      'epic_rules_v1.combat_sf',
    );
    expect(
      findSourceKey(magicBase, 'emsf_infinitum_runen'),
      'epic_rules_v1.magic_sf',
    );
    expect(
      magicAddEntries.where((entry) => entry['name'] == 'Ottogaldr'),
      isEmpty,
    );
  });
}

Map<String, dynamic>? findById(
  List<Map<String, dynamic>> entries,
  String entryId,
) {
  for (final entry in entries) {
    if (entry['id'] == entryId) {
      return entry;
    }
  }
  return null;
}

String findSourceKey(List<Map<String, dynamic>> entries, String entryId) {
  final entry = findById(entries, entryId);
  expect(entry, isNotNull, reason: 'Eintrag $entryId fehlt');
  final ruleMeta = (entry!['ruleMeta'] as Map).cast<String, dynamic>();
  return ruleMeta['sourceKey'] as String? ?? '';
}

String readRepoFile(String relativePath) {
  final raw = File(relativePath).readAsStringSync();
  return raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
}
