import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';
import 'package:dsa_heldenverwaltung/state/rules_index_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

// SPIEL-04: Hintergrundladen der Regel-Wissensbasis über die Cloud.

class _Repo implements HiveSettingsRepository {
  _Repo(this.settings);

  AppSettings settings;
  final StreamController<AppSettings> _stream =
      StreamController<AppSettings>.broadcast();

  @override
  AppSettings load() => settings;

  @override
  Stream<AppSettings> watch() => _stream.stream;

  @override
  Future<void> save(AppSettings next) async {
    settings = next;
    _stream.add(next);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Index implements RulesIndexSearch {
  bool freigegeben = false;

  @override
  List<RulesSearchHit> search(
    String query, {
    required Set<RulesSourceCategory> categories,
    int limit = 20,
  }) => const <RulesSearchHit>[];

  @override
  String loadChunkContext(int chunkId, {int window = 1}) => '';

  @override
  void dispose() => freigegeben = true;
}

class _Dienst extends RulesIndexSyncService {
  _Dienst({this.fehler, this.warten});

  final String version = 'v2';
  final Object? fehler;
  final Completer<void>? warten;
  final List<({String proof, String? installiert, bool ueberspringen})>
  aufrufe = [];
  final List<_Index> installiert = <_Index>[];

  @override
  Future<RulesIndexInstall> syncFromCloud({
    required String proof,
    String? installedVersion,
    bool skipIfCurrent = false,
    void Function(int received, int total)? onProgress,
  }) async {
    aufrufe.add((
      proof: proof,
      installiert: installedVersion,
      ueberspringen: skipIfCurrent,
    ));
    onProgress?.call(50, 100);
    await warten?.future;
    if (fehler != null) throw fehler!;
    if (skipIfCurrent && installedVersion == version) {
      return RulesIndexInstall(version: version, search: null);
    }
    final index = _Index();
    installiert.add(index);
    return RulesIndexInstall(version: version, search: index);
  }
}

void main() {
  final salt = Uint8List(32);

  Future<({ProviderContainer container, _Repo repo, _Dienst dienst})> aufbau({
    bool angemeldet = true,
    bool cloud = true,
    String? passwort = 'pw',
    bool indexVorhanden = false,
    RulesIndexRemoteConfig config = const RulesIndexRemoteConfig(),
    _Dienst? dienst,
    Uint8List? katalogSalt,
  }) async {
    final repo = _Repo(
      AppSettings(
        catalogContentPassword: passwort,
        rulesIndexRemoteConfig: config,
      ),
    );
    final d = dienst ?? _Dienst();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
        rulesIndexCloudAvailableProvider.overrideWithValue(cloud),
        rulesIndexSignedInProvider.overrideWithValue(angemeldet),
        rulesIndexCatalogSaltProvider.overrideWithValue(katalogSalt ?? salt),
        rulesIndexSyncServiceProvider.overrideWithValue(d),
        rulesIndexProofBuilderProvider.overrideWithValue(
          (password, salt) async => 'nachweis-$password',
        ),
        rulesIndexOpenerProvider.overrideWithValue(
          () async => indexVorhanden ? _Index() : null,
        ),
      ],
    );
    addTearDown(container.dispose);
    // Einstellungen laden lassen, wie es die App beim Start tut.
    final bereit = Completer<void>();
    container.listen(appSettingsProvider, (_, next) {
      if (next.hasValue && !bereit.isCompleted) bereit.complete();
    }, fireImmediately: true);
    await bereit.future;
    return (container: container, repo: repo, dienst: d);
  }

  RulesIndexAutoSync steuerung(ProviderContainer c) =>
      c.read(rulesIndexAutoSyncProvider.notifier);

  RulesIndexSyncState zustand(ProviderContainer c) =>
      c.read(rulesIndexAutoSyncProvider);

  test(
    'lädt von selbst, wenn die Wissensbasis fehlt, und merkt die Version',
    () async {
      final t = await aufbau();

      await steuerung(t.container).autoStart();

      expect(t.dienst.aufrufe, hasLength(1));
      final aufruf = t.dienst.aufrufe.single;
      expect(aufruf.proof, 'nachweis-pw');
      // Fehlt die Datei, wird auch bei gleicher Version geladen.
      expect(aufruf.ueberspringen, isFalse);
      expect(zustand(t.container).phase, RulesIndexSyncPhase.done);
      expect(zustand(t.container).revision, 1);
      // Die geöffnete Datenbank wird nicht festgehalten, der Dialog öffnet selbst.
      expect(t.dienst.installiert.single.freigegeben, isTrue);
      expect(t.repo.settings.rulesIndexRemoteConfig.installedVersion, 'v2');
      expect(t.repo.settings.rulesIndexRemoteConfig.lastSyncedAt, isNotNull);
    },
  );

  test('lädt nichts, wenn sie da und frisch ist', () async {
    final t = await aufbau(
      indexVorhanden: true,
      config: RulesIndexRemoteConfig(
        lastSyncedAt: DateTime.now().subtract(const Duration(days: 2)),
        installedVersion: 'v2',
      ),
    );

    await steuerung(t.container).autoStart();

    expect(t.dienst.aufrufe, isEmpty);
    expect(zustand(t.container).phase, RulesIndexSyncPhase.idle);
  });

  test('fragt bei veralteter Wissensbasis nach und lädt nur Neueres', () async {
    final t = await aufbau(
      indexVorhanden: true,
      config: RulesIndexRemoteConfig(
        lastSyncedAt: DateTime.now().subtract(const Duration(days: 30)),
        installedVersion: 'v2',
      ),
    );

    await steuerung(t.container).autoStart();

    expect(t.dienst.aufrufe.single.ueberspringen, isTrue);
    expect(t.dienst.aufrufe.single.installiert, 'v2');
    // Gleiche Version: nichts installiert, aber der Zeitpunkt ist erneuert.
    expect(zustand(t.container).phase, RulesIndexSyncPhase.done);
    expect(zustand(t.container).revision, 0);
    final danach = t.repo.settings.rulesIndexRemoteConfig.lastSyncedAt!;
    expect(DateTime.now().difference(danach).inMinutes, lessThan(1));
  });

  test(
    'ohne Passwort, ohne Konto, ohne Cloud oder ohne Salt passiert nichts',
    () async {
      for (final t in [
        await aufbau(passwort: null),
        await aufbau(passwort: ''),
        await aufbau(angemeldet: false),
        await aufbau(cloud: false),
      ]) {
        await steuerung(t.container).autoStart();
        expect(t.dienst.aufrufe, isEmpty);
        expect(zustand(t.container).phase, RulesIndexSyncPhase.idle);
      }
    },
  );

  test(
    'ein fehlender Voraussetzungsgrund verbraucht den Versuch nicht',
    () async {
      // Ohne Konto passiert nichts; derselbe Dienst startet später doch, sobald
      // alle Voraussetzungen da sind.
      final aus = await aufbau(angemeldet: false);
      await steuerung(aus.container).autoStart();
      expect(aus.dienst.aufrufe, isEmpty);

      final an = await aufbau();
      await steuerung(an.container).autoStart();
      expect(an.dienst.aufrufe, hasLength(1));
    },
  );

  test('startet höchstens einmal je Sitzung von selbst', () async {
    const fehler = RulesIndexDownloadException(
      RulesIndexDownloadErrorKind.network,
      'Server nicht erreichbar: x',
    );
    final t = await aufbau(dienst: _Dienst(fehler: fehler));

    await steuerung(t.container).autoStart();
    await steuerung(t.container).autoStart();

    expect(t.dienst.aufrufe, hasLength(1));
    expect(zustand(t.container).phase, RulesIndexSyncPhase.failed);
    expect(zustand(t.container).message, 'Server nicht erreichbar: x');
    expect(zustand(t.container).needsLogin, isFalse);

    // Von Hand lässt es sich wiederholen.
    await steuerung(t.container).start(force: true);
    expect(t.dienst.aufrufe, hasLength(2));
  });

  test(
    'Formatfehler der Datei werden gemeldet, nichts wird gespeichert',
    () async {
      final t = await aufbau(
        dienst: _Dienst(
          fehler: const FormatException('Die geladene Datei passt nicht.'),
        ),
      );

      await steuerung(t.container).start(force: true);

      expect(zustand(t.container).phase, RulesIndexSyncPhase.failed);
      expect(zustand(t.container).message, 'Die geladene Datei passt nicht.');
      expect(t.repo.settings.rulesIndexRemoteConfig.installedVersion, isEmpty);
    },
  );

  test('von Hand ohne Konto erklärt start die Anmeldung', () async {
    final t = await aufbau(angemeldet: false);

    await steuerung(t.container).start(force: true);

    expect(t.dienst.aufrufe, isEmpty);
    expect(zustand(t.container).phase, RulesIndexSyncPhase.failed);
    expect(zustand(t.container).needsLogin, isTrue);
    expect(zustand(t.container).message, contains('anmelden'));
  });

  test('ohne bekanntes Passwort läuft start nicht', () async {
    final t = await aufbau(passwort: null);
    await steuerung(t.container).start(force: true);
    expect(t.dienst.aufrufe, isEmpty);
    expect(zustand(t.container).phase, RulesIndexSyncPhase.idle);
  });

  test('start ohne Katalog-Salt meldet, dass der Katalog fehlt', () async {
    final t = await aufbau();
    // Salt nachträglich entfernen: neuer Container mit leerem Salt.
    final leer = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(t.repo),
        rulesIndexCloudAvailableProvider.overrideWithValue(true),
        rulesIndexSignedInProvider.overrideWithValue(true),
        rulesIndexCatalogSaltProvider.overrideWithValue(null),
        rulesIndexSyncServiceProvider.overrideWithValue(t.dienst),
      ],
    );
    addTearDown(leer.dispose);
    final bereit = Completer<void>();
    leer.listen(appSettingsProvider, (_, next) {
      if (next.hasValue && !bereit.isCompleted) bereit.complete();
    }, fireImmediately: true);
    await bereit.future;

    await steuerung(leer).start(force: true);

    expect(zustand(leer).phase, RulesIndexSyncPhase.failed);
    expect(zustand(leer).message, contains('Katalog'));
    expect(t.dienst.aufrufe, isEmpty);
  });

  test('meldet den Fortschritt und läuft nicht doppelt', () async {
    final warten = Completer<void>();
    final t = await aufbau(dienst: _Dienst(warten: warten));
    final phasen = <RulesIndexSyncPhase>[];
    final anteile = <double?>[];
    t.container.listen(rulesIndexAutoSyncProvider, (_, next) {
      phasen.add(next.phase);
      anteile.add(next.fraction);
    });

    final erster = steuerung(t.container).start(force: true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(zustand(t.container).running, isTrue);
    expect(zustand(t.container).fraction, 0.5);
    // Ein zweiter Start während des Laufs wird ignoriert.
    await steuerung(t.container).start(force: true);
    expect(t.dienst.aufrufe, hasLength(1));

    warten.complete();
    await erster;

    expect(
      phasen,
      containsAllInOrder(<RulesIndexSyncPhase>[
        RulesIndexSyncPhase.preparing,
        RulesIndexSyncPhase.downloading,
        RulesIndexSyncPhase.done,
      ]),
    );
    expect(anteile, contains(0.5));
    expect(zustand(t.container).fraction, isNull);
  });

  test('start ohne force fragt nur nach Neuem', () async {
    final t = await aufbau(
      indexVorhanden: true,
      config: const RulesIndexRemoteConfig(installedVersion: 'v2'),
    );
    await steuerung(t.container).start();
    expect(t.dienst.aufrufe.single.ueberspringen, isTrue);
    expect(zustand(t.container).revision, 0);
  });

  test('jede neue Installation zählt die Revision hoch', () async {
    final t = await aufbau();
    await steuerung(t.container).start(force: true);
    await steuerung(t.container).start(force: true);
    expect(zustand(t.container).revision, 2);
  });
}
