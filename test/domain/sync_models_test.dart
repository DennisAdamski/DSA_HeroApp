import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

void main() {
  group('stableContentHash', () {
    test('ignores map insertion order recursively', () {
      final first = <String, dynamic>{
        'name': 'Alrik',
        'attributes': <String, dynamic>{'mu': 12, 'kl': 11},
        'talents': <dynamic>[
          <String, dynamic>{'id': 'tal_sagen', 'wert': 7},
        ],
      };
      final second = <String, dynamic>{
        'talents': <dynamic>[
          <String, dynamic>{'wert': 7, 'id': 'tal_sagen'},
        ],
        'attributes': <String, dynamic>{'kl': 11, 'mu': 12},
        'name': 'Alrik',
      };

      expect(stableContentHash(first), stableContentHash(second));
    });

    test('changes when a nested value changes', () {
      final first = <String, dynamic>{
        'name': 'Alrik',
        'attributes': <String, dynamic>{'mu': 12, 'kl': 11},
      };
      final second = <String, dynamic>{
        'name': 'Alrik',
        'attributes': <String, dynamic>{'mu': 13, 'kl': 11},
      };

      expect(stableContentHash(first), isNot(stableContentHash(second)));
    });
  });

  group('SyncObjectKey', () {
    test('builds stable metadata keys per object type and id', () {
      const key = SyncObjectKey(type: SyncObjectType.hero, id: 'hero-1');

      expect(key.storageKey, 'hero::hero-1');
      expect(SyncObjectKey.parse(key.storageKey), key);
    });
  });
}
