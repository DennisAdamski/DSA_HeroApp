import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';

void main() {
  test('copyWith can set lastSyncedAt and installedVersion explicitly', () {
    const config = RulesIndexRemoteConfig();
    final now = DateTime.utc(2026, 8, 2, 9);

    final updated = config.copyWith(lastSyncedAt: now, installedVersion: 'v1');

    expect(updated.lastSyncedAt, now);
    expect(updated.installedVersion, 'v1');
    expect(updated.copyWith(installedVersion: '').installedVersion, isEmpty);
  });

  test('toJson/fromJson round-trips all fields', () {
    final config = RulesIndexRemoteConfig(
      lastSyncedAt: DateTime.utc(2026, 8, 1, 12, 30),
      installedVersion: '2026-08-01T00:00:00Z',
    );

    final restored = RulesIndexRemoteConfig.fromJson(config.toJson());

    expect(restored.lastSyncedAt, config.lastSyncedAt);
    expect(restored.installedVersion, config.installedVersion);
  });

  test('fromJson tolerates missing fields', () {
    final restored = RulesIndexRemoteConfig.fromJson(const <String, dynamic>{});

    expect(restored.lastSyncedAt, isNull);
    expect(restored.installedVersion, isEmpty);
  });

  test('gespeicherte WebDAV-Zugangsdaten werden verworfen', () {
    // Der WebDAV-Bezug ist entfallen; alte Einstellungen tragen noch URL,
    // Benutzer und Passwort. Sie werden gelesen, aber nicht wieder
    // geschrieben, damit kein Passwort liegen bleibt.
    final alt = RulesIndexRemoteConfig.fromJson(const <String, dynamic>{
      'serverUrl': 'https://example.myfritz.net/nas/index.sqlite',
      'username': 'reader',
      'password': 'secret',
      'lastSyncedAt': '2026-08-01T12:30:00.000Z',
    });

    expect(alt.lastSyncedAt, DateTime.utc(2026, 8, 1, 12, 30));
    expect(
      alt.toJson().keys,
      isNot(anyOf(contains('serverUrl'), contains('password'))),
    );
  });
}
