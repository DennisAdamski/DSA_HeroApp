import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/sync/in_memory_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/editor_entwurf_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/fake_remote_hero_sync_gateway.dart';

const _knowledge = HeroRitualKnowledge(
  name: 'Gildenmagie',
  value: 9,
  unbekannteFelder: {'future': true},
);
const _hero = HeroSheet(
  id: 'shared',
  name: 'Shared',
  level: 1,
  attributes: Attributes.zero(),
  ritualKnowledge: {'gildenmagier': _knowledge},
  ritualCategories: [
    HeroRitualCategory(
      id: 'staff',
      name: 'Stabzauber',
      traditionId: 'gildenmagier',
      knowledgeMode: HeroRitualKnowledgeMode.traditionKnowledge,
      unbekannteFelder: {'futureCategory': 'kept'},
    ),
  ],
);

void main() {
  test(
    'real Hive restart retains common knowledge and unknown fields',
    () async {
      final directory = await Directory.systemTemp.createTemp('dsa_shared_rk_');
      addTearDown(() => directory.delete(recursive: true));
      final first = await HiveHeroRepository.create(
        storagePath: directory.path,
      );
      await first.saveHero(_hero);
      await first.close();
      final reopened = await HiveHeroRepository.create(
        storagePath: directory.path,
      );
      addTearDown(reopened.close);
      final restored = await reopened.loadHeroById(_hero.id);
      expect(restored!.ritualKnowledge['gildenmagier'], _knowledge);
      expect(restored.ritualCategories, _hero.ritualCategories);
    },
  );

  test(
    'editor merges unrelated writes and detects simultaneous RK changes',
    () {
      final updated = _hero.copyWith(
        ritualKnowledge: {'gildenmagier': _knowledge.copyWith(value: 12)},
      );
      final merged = uebernimmEditorEntwurf(
        basis: _hero,
        entwurf: _hero.copyWith(name: 'Edited'),
        aktuell: updated,
        neueId: () => 'new-id',
      );
      expect(merged.name, 'Edited');
      expect(merged.ritualKnowledge['gildenmagier']!.value, 12);
      expect(
        () => uebernimmEditorEntwurf(
          basis: _hero,
          entwurf: _hero.copyWith(
            ritualKnowledge: {'gildenmagier': _knowledge.copyWith(value: 11)},
          ),
          aktuell: updated,
          neueId: () => 'new-id',
        ),
        throwsA(
          isA<EditorEntwurfKonflikt>().having(
            (error) => error.schluessel,
            'conflict key',
            contains('ritualKnowledge'),
          ),
        ),
      );
    },
  );

  test(
    'two devices expose common RK conflict and keep remote without loss',
    () async {
      final remote = FakeRemoteHeroSyncGateway();
      await remote.saveHero(_hero, previousRevision: null);
      final localA = FakeRepository.empty();
      final localB = FakeRepository.empty();
      final a = SyncingHeroRepository(
        local: localA,
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user',
        startRemoteListener: false,
      );
      final b = SyncingHeroRepository(
        local: localB,
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user',
        startRemoteListener: false,
      );
      addTearDown(a.close);
      addTearDown(b.close);
      await a.syncNow();
      await b.syncNow();
      await a.saveHero(
        _hero.copyWith(
          ritualKnowledge: {'gildenmagier': _knowledge.copyWith(value: 12)},
        ),
      );
      await a.syncNow();
      await b.saveHero(
        _hero.copyWith(
          ritualKnowledge: {'gildenmagier': _knowledge.copyWith(value: 11)},
        ),
      );
      expect(b.currentStatus.openConflicts, hasLength(1));
      final conflict = b.currentStatus.openConflicts.single;
      await b.resolveConflict(conflict.id, SyncResolutionChoice.keepRemote);
      final restored = await localB.loadHeroById(_hero.id);
      expect(restored!.ritualKnowledge['gildenmagier']!.value, 12);
      expect(
        restored.ritualKnowledge['gildenmagier']!.unbekannteFelder['future'],
        true,
      );
      expect(restored.ritualCategories, _hero.ritualCategories);
    },
  );
}
