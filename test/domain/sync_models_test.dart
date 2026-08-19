import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
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

  group('heroStateContentHash', () {
    HeroState state({int currentLep = 30, DateTime? lastModified}) {
      return HeroState(
        currentLep: currentLep,
        currentAsp: 12,
        currentKap: 0,
        currentAu: 20,
        lastModified: lastModified,
      );
    }

    test('ignores lastModified so a re-save alone is no conflict', () {
      final early = state(lastModified: DateTime.utc(2026, 1, 1));
      final late = state(lastModified: DateTime.utc(2026, 8, 20));

      expect(heroStateContentHash(early), heroStateContentHash(late));
    });

    test('treats a missing timestamp like any other timestamp', () {
      expect(
        heroStateContentHash(state()),
        heroStateContentHash(state(lastModified: DateTime.utc(2026, 8, 20))),
      );
    });

    test('still changes when real runtime values change', () {
      expect(
        heroStateContentHash(state(currentLep: 30)),
        isNot(heroStateContentHash(state(currentLep: 29))),
      );
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
