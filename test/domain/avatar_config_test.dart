import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarApiConfig', () {
    test('roundtrip toJson/fromJson', () {
      const config = AvatarApiConfig(
        provider: AvatarApiProvider.openaiDalle3,
        apiKey: 'sk-test-key-123',
      );
      final json = config.toJson();
      final restored = AvatarApiConfig.fromJson(json);

      expect(restored.provider, config.provider);
      expect(restored.apiKey, config.apiKey);
    });

    test('fromJson mit leerer Map liefert Defaults', () {
      final config = AvatarApiConfig.fromJson(const {});

      expect(config.provider, AvatarApiProvider.openaiDalle3);
      expect(config.apiKey, '');
      expect(config.isConfigured, isFalse);
    });

    test('fromJson mit unbekanntem Provider faellt auf Default zurueck', () {
      final config = AvatarApiConfig.fromJson(const {
        'provider': 'unknown_provider',
        'apiKey': 'sk-123',
      });

      expect(config.provider, AvatarApiProvider.openaiDalle3);
      expect(config.apiKey, 'sk-123');
    });

    test('isConfigured ist true wenn apiKey nicht leer', () {
      const empty = AvatarApiConfig();
      const withKey = AvatarApiConfig(apiKey: 'sk-test');

      expect(empty.isConfigured, isFalse);
      expect(withKey.isConfigured, isTrue);
    });

    test('copyWith ueberschreibt gezielt', () {
      const original = AvatarApiConfig(apiKey: 'alt');
      final updated = original.copyWith(apiKey: 'neu');

      expect(updated.apiKey, 'neu');
      expect(updated.provider, original.provider);
    });
  });

  group('AvatarApiProvider', () {
    test('fromId findet bekannte Provider', () {
      expect(
        AvatarApiProvider.fromId('openaiDalle3'),
        AvatarApiProvider.openaiDalle3,
      );
    });

    test('fromId gibt null fuer unbekannte IDs', () {
      expect(AvatarApiProvider.fromId('fantasy'), isNull);
      expect(AvatarApiProvider.fromId(null), isNull);
    });
  });
}
