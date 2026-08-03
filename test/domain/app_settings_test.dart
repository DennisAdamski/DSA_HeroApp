import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';

void main() {
  test('serializes and deserializes hero storage path', () {
    const settings = AppSettings(
      debugModus: true,
      dunkelModus: true,
      heroStoragePath: 'C:/Cloud/Helden',
    );

    final json = settings.toJson();
    final restored = AppSettings.fromJson(json);

    expect(restored.debugModus, isTrue);
    expect(restored.dunkelModus, isTrue);
    expect(restored.heroStoragePath, 'C:/Cloud/Helden');
  });

  test('copyWith can clear hero storage path explicitly', () {
    const settings = AppSettings(heroStoragePath: 'C:/Cloud/Helden');

    final updated = settings.copyWith(heroStoragePath: null);

    expect(updated.heroStoragePath, isNull);
  });

  test('last selected hero id round-trips through json', () {
    const settings = AppSettings(lastSelectedHeroId: 'hero-alrik');

    final json = settings.toJson();
    final restored = AppSettings.fromJson(json);

    expect(restored.lastSelectedHeroId, 'hero-alrik');
  });

  test('copyWith can clear last selected hero id explicitly', () {
    const settings = AppSettings(lastSelectedHeroId: 'hero-alrik');

    final updated = settings.copyWith(lastSelectedHeroId: null);

    expect(updated.lastSelectedHeroId, isNull);
  });

  test('disabled house rule pack ids round-trip through json', () {
    const settings = AppSettings(
      disabledHouseRulePackIds: {'epic_rules_v1', 'epic_rules_v1.advantages'},
    );

    final json = settings.toJson();
    final restored = AppSettings.fromJson(json);

    expect(restored.disabledHouseRulePackIds, {
      'epic_rules_v1',
      'epic_rules_v1.advantages',
    });
  });

  test('legacy disabledHouseRuleSourceKeys migrate to pack ids', () {
    final settings = AppSettings.fromJson(const <String, dynamic>{
      'disabledHouseRuleSourceKeys': <String>[
        'epic_rules_v1',
        'epic_rules_v1.advantages',
      ],
    });

    expect(settings.disabledHouseRulePackIds, {
      'epic_rules_v1',
      'epic_rules_v1.advantages',
    });
  });

  test('missing disabledHouseRulePackIds defaults to empty set', () {
    final settings = AppSettings.fromJson(const <String, dynamic>{});

    expect(settings.disabledHouseRulePackIds, isEmpty);
  });

  test('copyWith can replace disabledHouseRulePackIds', () {
    const settings = AppSettings();

    final updated = settings.copyWith(
      disabledHouseRulePackIds: const {'epic_rules_v1'},
    );

    expect(updated.disabledHouseRulePackIds, {'epic_rules_v1'});
  });

  test('rulesIndexRemoteConfig round-trips through json', () {
    final settings = AppSettings(
      rulesIndexRemoteConfig: RulesIndexRemoteConfig(
        serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
        username: 'dsa-rules-reader',
        password: 'secret',
        lastSyncedAt: DateTime.utc(2026, 8, 1, 12, 30),
      ),
    );

    final json = settings.toJson();
    final restored = AppSettings.fromJson(json);

    expect(
      restored.rulesIndexRemoteConfig.serverUrl,
      'https://example.myfritz.net/nas/index.sqlite',
    );
    expect(restored.rulesIndexRemoteConfig.username, 'dsa-rules-reader');
    expect(restored.rulesIndexRemoteConfig.password, 'secret');
    expect(
      restored.rulesIndexRemoteConfig.lastSyncedAt,
      DateTime.utc(2026, 8, 1, 12, 30),
    );
  });

  test('missing rulesIndexRemoteConfig defaults to unconfigured value', () {
    final settings = AppSettings.fromJson(const <String, dynamic>{});

    expect(settings.rulesIndexRemoteConfig.isConfigured, isFalse);
    expect(settings.rulesIndexRemoteConfig.lastSyncedAt, isNull);
  });
}
