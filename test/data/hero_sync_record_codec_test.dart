import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/sync/hero_sync_record_codec.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

void main() {
  HeroSheet hero(String id, String name) {
    return HeroSheet(
      id: id,
      name: name,
      level: 1,
      attributes: const Attributes(
        mu: 8,
        kl: 8,
        inn: 8,
        ch: 8,
        ff: 8,
        ge: 8,
        ko: 8,
        kk: 8,
      ),
    );
  }

  group('encode', () {
    test('payload write fields contain exactly the five wire keys', () {
      final sheet = hero('h-1', 'Alrik');
      final fields = encodeSyncPayloadWriteFields(
        payload: sheet.toJson(),
        revision: 'r-1',
        contentHash: 'hash-1',
        lastModifiedValue: DateTime.utc(2026, 1, 1),
      );

      expect(
        fields.keys,
        unorderedEquals(<String>[
          'deleted',
          'payload',
          'revision',
          'contentHash',
          'lastModified',
        ]),
      );
      expect(fields['deleted'], isFalse);
      expect(fields['payload'], sheet.toJson());
      expect(fields['revision'], 'r-1');
      expect(fields['contentHash'], 'hash-1');
      expect(fields['lastModified'], DateTime.utc(2026, 1, 1));
    });

    test('tombstone write fields mark the document as deleted', () {
      final fields = encodeSyncTombstoneWriteFields(
        revision: 'r-2',
        lastModifiedValue: DateTime.utc(2026, 1, 2),
      );

      expect(
        fields.keys,
        unorderedEquals(<String>[
          'deleted',
          'payload',
          'revision',
          'contentHash',
          'lastModified',
        ]),
      );
      expect(fields['deleted'], isTrue);
      expect(fields['payload'], isNull);
      expect(fields['revision'], 'r-2');
      expect(fields['contentHash'], '');
    });
  });

  group('decode', () {
    test('roundtrips a hero record', () {
      final sheet = hero('h-1', 'Alrik');
      final contentHash = heroContentHash(sheet);
      final updatedAt = DateTime.utc(2026, 1, 3, 12);
      final fields = encodeSyncPayloadWriteFields(
        payload: sheet.toJson(),
        revision: 'r-3',
        contentHash: contentHash,
        lastModifiedValue: updatedAt,
      );

      final record = decodeRemoteHeroRecord(
        id: 'h-1',
        data: fields,
        updatedAt: updatedAt,
      );

      expect(record, isNotNull);
      expect(record!.id, 'h-1');
      expect(record.hero?.name, 'Alrik');
      expect(record.revision, 'r-3');
      expect(record.contentHash, contentHash);
      expect(record.isDeleted, isFalse);
      expect(record.updatedAt, updatedAt);
    });

    test('roundtrips a hero state record', () {
      final state = const HeroState.empty().copyWith(currentLep: 17);
      final contentHash = stableContentHash(state.toJson());
      final fields = encodeSyncPayloadWriteFields(
        payload: state.toJson(),
        revision: 'r-4',
        contentHash: contentHash,
        lastModifiedValue: DateTime.utc(2026, 1, 4),
      );

      final record = decodeRemoteHeroStateRecord(
        heroId: 'h-1',
        data: fields,
        updatedAt: DateTime.utc(2026, 1, 4),
      );

      expect(record, isNotNull);
      expect(record!.heroId, 'h-1');
      expect(record.state?.currentLep, 17);
      expect(record.revision, 'r-4');
      expect(record.contentHash, contentHash);
      expect(record.isDeleted, isFalse);
    });

    test('roundtrips a tombstone record', () {
      final fields = encodeSyncTombstoneWriteFields(
        revision: 'r-5',
        lastModifiedValue: DateTime.utc(2026, 1, 5),
      );

      final record = decodeRemoteHeroRecord(
        id: 'h-gone',
        data: fields,
        updatedAt: DateTime.utc(2026, 1, 5),
      );

      expect(record, isNotNull);
      expect(record!.isDeleted, isTrue);
      expect(record.hero, isNull);
      expect(record.revision, 'r-5');
      expect(record.contentHash, '');
    });

    test('returns null when payload is not a map', () {
      final record = decodeRemoteHeroRecord(
        id: 'h-broken',
        data: <String, dynamic>{
          'deleted': false,
          'payload': 'kein-map',
          'revision': 'r-6',
          'contentHash': '',
          'lastModified': null,
        },
        updatedAt: null,
      );

      expect(record, isNull);
    });

    test('computes contentHash fallback when the field is missing', () {
      final sheet = hero('h-1', 'Alrik');
      final record = decodeRemoteHeroRecord(
        id: 'h-1',
        data: <String, dynamic>{
          'deleted': false,
          'payload': sheet.toJson(),
          'revision': 'r-7',
        },
        updatedAt: null,
      );

      expect(record, isNotNull);
      expect(record!.contentHash, heroContentHash(sheet));
    });
  });

  group('readSyncRevision', () {
    test('prefers the stored revision', () {
      final revision = readSyncRevision(
        <String, dynamic>{'revision': 'r-8'},
        DateTime.utc(2026, 1, 6),
      );

      expect(revision, 'r-8');
    });

    test('falls back to legacy timestamp revision', () {
      final updatedAt = DateTime.utc(2026, 1, 6);
      final revision = readSyncRevision(<String, dynamic>{}, updatedAt);

      expect(revision, 'legacy-${updatedAt.microsecondsSinceEpoch}');
    });

    test('falls back to legacy hash revision without timestamp', () {
      final revision = readSyncRevision(
        <String, dynamic>{},
        null,
        fallbackHash: 'hash-9',
      );

      expect(revision, 'legacy-hash-9');
    });
  });

  test('newSyncRevision produces unique, sortable revisions', () {
    final first = newSyncRevision();
    final second = newSyncRevision();

    expect(first, isNot(second));
    expect(first, matches(RegExp(r'^\d+-[0-9a-f-]{36}$')));
  });
}
