import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';

void main() {
  test('effective values fall back to empty build defaults when unset', () {
    const config = RulesIndexRemoteConfig();

    // Ohne --dart-define sind die eingebauten Defaults leer; der Test läuft
    // damit unabhängig vom jeweiligen Build.
    expect(config.effectiveServerUrl, isEmpty);
    expect(config.effectiveUsername, isEmpty);
    expect(config.effectivePassword, isEmpty);
    expect(config.isConfigured, isFalse);
  });

  test('explicit override wins over build default', () {
    const config = RulesIndexRemoteConfig(
      serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
      username: 'reader',
      password: 'secret',
    );

    expect(
      config.effectiveServerUrl,
      'https://example.myfritz.net/nas/index.sqlite',
    );
    expect(config.effectiveUsername, 'reader');
    expect(config.effectivePassword, 'secret');
    expect(config.isConfigured, isTrue);
  });

  test('copyWith replaces only given fields', () {
    const config = RulesIndexRemoteConfig(
      serverUrl: 'https://old.example/index.sqlite',
      username: 'user',
    );

    final updated = config.copyWith(serverUrl: 'https://new.example/index.sqlite');

    expect(updated.serverUrl, 'https://new.example/index.sqlite');
    expect(updated.username, 'user');
  });

  test('copyWith can set lastSyncedAt explicitly', () {
    const config = RulesIndexRemoteConfig();
    final now = DateTime.utc(2026, 8, 2, 9);

    final updated = config.copyWith(lastSyncedAt: now);

    expect(updated.lastSyncedAt, now);
  });

  test('toJson/fromJson round-trips all fields', () {
    final config = RulesIndexRemoteConfig(
      serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
      username: 'reader',
      password: 'secret',
      lastSyncedAt: DateTime.utc(2026, 8, 1, 12, 30),
    );

    final restored = RulesIndexRemoteConfig.fromJson(config.toJson());

    expect(restored.serverUrl, config.serverUrl);
    expect(restored.username, config.username);
    expect(restored.password, config.password);
    expect(restored.lastSyncedAt, config.lastSyncedAt);
  });

  test('fromJson tolerates missing fields', () {
    final restored = RulesIndexRemoteConfig.fromJson(const <String, dynamic>{});

    expect(restored.serverUrl, isEmpty);
    expect(restored.username, isEmpty);
    expect(restored.password, isEmpty);
    expect(restored.lastSyncedAt, isNull);
  });
}
