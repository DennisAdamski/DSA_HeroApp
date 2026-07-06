import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';

void main() {
  group('computeSyncObjectDiff', () {
    test('meldet geaenderte Skalare mit beiden Werten', () {
      final diff = computeSyncObjectDiff(
        {'name': 'Alrik', 'level': 3},
        {'name': 'Alrik', 'level': 5},
      );

      expect(diff.entries, hasLength(1));
      final entry = diff.entries.single;
      expect(entry.path, ['level']);
      expect(entry.kind, SyncDiffKind.changed);
      expect(entry.localValue, 3);
      expect(entry.remoteValue, 5);
      expect(diff.hatAenderungen, isTrue);
    });

    test('liefert leeres Diff fuer identische Maps', () {
      final diff = computeSyncObjectDiff(
        {
          'name': 'Alrik',
          'attributes': {'mu': 12},
          'tags': ['a', 'b'],
        },
        {
          'name': 'Alrik',
          'attributes': {'mu': 12},
          'tags': ['a', 'b'],
        },
      );

      expect(diff.entries, isEmpty);
      expect(diff.hatAenderungen, isFalse);
    });

    test('rekursiert in verschachtelte Maps mit vollem Pfad', () {
      final diff = computeSyncObjectDiff(
        {
          'attributes': {'mu': 12, 'kl': 10},
        },
        {
          'attributes': {'mu': 14, 'kl': 10},
        },
      );

      expect(diff.entries, hasLength(1));
      expect(diff.entries.single.path, ['attributes', 'mu']);
      expect(diff.entries.single.localValue, 12);
      expect(diff.entries.single.remoteValue, 14);
    });

    test('meldet nur einseitig vorhandene Keys', () {
      final diff = computeSyncObjectDiff(
        {'name': 'Alrik', 'titel': 'Ritter'},
        {'name': 'Alrik', 'stand': 'Adel'},
      );

      expect(diff.entries, hasLength(2));
      expect(diff.entries[0].path, ['titel']);
      expect(diff.entries[0].kind, SyncDiffKind.onlyLocal);
      expect(diff.entries[0].localValue, 'Ritter');
      expect(diff.entries[1].path, ['stand']);
      expect(diff.entries[1].kind, SyncDiffKind.onlyRemote);
      expect(diff.entries[1].remoteValue, 'Adel');
    });

    test('ignoriert lastModified und schemaVersion auf oberster Ebene', () {
      final diff = computeSyncObjectDiff(
        {'schemaVersion': 5, 'lastModified': '2026-01-01', 'name': 'Alrik'},
        {'schemaVersion': 6, 'lastModified': '2026-02-02', 'name': 'Alrik'},
      );

      expect(diff.entries, isEmpty);
    });

    test('diffed primitive Listen mengenbasiert ohne Reihenfolge', () {
      final unchanged = computeSyncObjectDiff(
        {
          'representationen': ['Magier', 'Elf'],
        },
        {
          'representationen': ['Elf', 'Magier'],
        },
      );
      expect(unchanged.entries, isEmpty);

      final changed = computeSyncObjectDiff(
        {
          'representationen': ['Magier', 'Elf'],
        },
        {
          'representationen': ['Magier', 'Druide'],
        },
      );
      expect(changed.entries, hasLength(2));
      expect(changed.entries[0].kind, SyncDiffKind.onlyLocal);
      expect(changed.entries[0].localValue, 'Elf');
      expect(changed.entries[1].kind, SyncDiffKind.onlyRemote);
      expect(changed.entries[1].remoteValue, 'Druide');
    });

    test('keyed Map-Listen nach id und vergleicht Elemente rekursiv', () {
      final diff = computeSyncObjectDiff(
        {
          'inventoryEntries': [
            {'id': 'a', 'name': 'Schwert', 'anzahl': 1},
            {'id': 'b', 'name': 'Schild', 'anzahl': 1},
          ],
        },
        {
          'inventoryEntries': [
            // Umsortiert und ein Feld geaendert.
            {'id': 'b', 'name': 'Schild', 'anzahl': 2},
            {'id': 'a', 'name': 'Schwert', 'anzahl': 1},
          ],
        },
      );

      expect(diff.entries, hasLength(1));
      expect(diff.entries.single.path, ['inventoryEntries', 'Schild', 'anzahl']);
      expect(diff.entries.single.kind, SyncDiffKind.changed);
      expect(diff.entries.single.localValue, 1);
      expect(diff.entries.single.remoteValue, 2);
    });

    test('meldet nur einseitige ids in Map-Listen mit Namenslabel', () {
      final diff = computeSyncObjectDiff(
        {
          'notes': [
            {'id': 'n1', 'name': 'Reise', 'text': 'lang'},
          ],
        },
        {
          'notes': [
            {'id': 'n2', 'text': 'ohne Namen'},
          ],
        },
      );

      expect(diff.entries, hasLength(2));
      expect(diff.entries[0].path, ['notes', 'Reise']);
      expect(diff.entries[0].kind, SyncDiffKind.onlyLocal);
      expect(diff.entries[1].path, ['notes', 'n2']);
      expect(diff.entries[1].kind, SyncDiffKind.onlyRemote);
    });

    test('faellt bei id-losen Map-Listen auf Indexvergleich zurueck', () {
      final diff = computeSyncObjectDiff(
        {
          'werte': [
            {'wert': 1},
            {'wert': 2},
          ],
        },
        {
          'werte': [
            {'wert': 1},
          ],
        },
      );

      expect(diff.entries, hasLength(1));
      expect(diff.entries.single.path, ['werte', '[1]']);
      expect(diff.entries.single.kind, SyncDiffKind.onlyLocal);
    });

    test('setzt Missing-Flags bei fehlenden Seiten', () {
      final remoteMissing = computeSyncObjectDiff({'name': 'Alrik'}, null);
      expect(remoteMissing.remoteMissing, isTrue);
      expect(remoteMissing.localMissing, isFalse);
      expect(remoteMissing.entries, isEmpty);
      expect(remoteMissing.hatAenderungen, isTrue);

      final localMissing = computeSyncObjectDiff(null, {'name': 'Alrik'});
      expect(localMissing.localMissing, isTrue);
      expect(localMissing.remoteMissing, isFalse);
    });

    test('bricht bei maxEntries ab und markiert truncated', () {
      final local = <String, dynamic>{
        for (var i = 0; i < 20; i++) 'feld$i': i,
      };
      final remote = <String, dynamic>{
        for (var i = 0; i < 20; i++) 'feld$i': i + 1,
      };

      final diff = computeSyncObjectDiff(local, remote, maxEntries: 5);

      expect(diff.entries, hasLength(5));
      expect(diff.truncated, isTrue);
    });
  });

  group('formatSyncDiffValue', () {
    test('formatiert Sonderfaelle lesbar', () {
      expect(formatSyncDiffValue(null), '—');
      expect(formatSyncDiffValue(''), '(leer)');
      expect(formatSyncDiffValue({'a': 1, 'b': 2}), '{…} (2 Felder)');
      expect(formatSyncDiffValue([1, 2, 3]), '[…] (3 Einträge)');
      expect(formatSyncDiffValue(42), '42');
    });

    test('kuerzt lange Texte auf maxLength', () {
      final text = 'x' * 100;
      final formatted = formatSyncDiffValue(text, maxLength: 10);
      expect(formatted, '${'x' * 10}…');
    });
  });
}
