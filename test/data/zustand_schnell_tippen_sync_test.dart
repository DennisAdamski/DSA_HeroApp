import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/sync/in_memory_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/fake_remote_hero_sync_gateway.dart';

// Schnelles Tippen am Spieltisch (zehnmal AsP −1) mit Konto-Sync. Die Cloud
// antwortet verzögert und schickt jeden eigenen Schreibvorgang wie Firestore
// als Echo zurück. Früher entstanden dabei Konflikte mit sich selbst, und
// jede Änderung wartete auf zwei Netzwege.

/// Cloud mit Laufzeit je Aufruf und Echo jedes Schreibvorgangs.
class _LangsameCloud extends FakeRemoteHeroAndStateSyncGateway {
  static const laufzeit = Duration(milliseconds: 40);
  final _echo = StreamController<List<RemoteHeroStateRecord>>.broadcast();
  int schreibvorgaenge = 0;
  bool offline = false;

  @override
  Future<RemoteHeroStateRecord?> loadHeroState(String heroId) async {
    await Future<void>.delayed(laufzeit);
    if (offline) {
      throw const SyncNetworkException('offline');
    }
    return super.loadHeroState(heroId);
  }

  @override
  Future<RemoteHeroStateRecord> saveHeroState(
    String heroId,
    HeroState state, {
    required String? previousRevision,
  }) async {
    await Future<void>.delayed(laufzeit ~/ 2);
    final record = await super.saveHeroState(
      heroId,
      state,
      previousRevision: previousRevision,
    );
    schreibvorgaenge++;
    // Wie bei Firestore kann das Echo vor der Antwort eintreffen.
    _echo.add(<RemoteHeroStateRecord>[record]);
    await Future<void>.delayed(laufzeit ~/ 2);
    return record;
  }

  @override
  Stream<List<RemoteHeroStateRecord>> watchHeroStates() => _echo.stream;

  /// Schreibt wie ein anderes Gerät, dessen Änderung hier nicht ankommt.
  Future<void> speichereOhneEcho(
    String heroId,
    HeroState state,
    String previousRevision,
  ) {
    return super.saveHeroState(
      heroId,
      state,
      previousRevision: previousRevision,
    );
  }
}

HeroState _einWeniger(HeroState z) => z.copyWith(currentAsp: z.currentAsp - 1);

void main() {
  late _LangsameCloud cloud;
  late FakeRepository lokal;
  late SyncingHeroRepository repo;

  setUp(() {
    cloud = _LangsameCloud();
    lokal = FakeRepository(
      heroes: [
        const HeroSheet(
          id: 'held',
          name: 'Rondra',
          level: 1,
          attributes: Attributes(
            mu: 12,
            kl: 12,
            inn: 12,
            ch: 12,
            ff: 12,
            ge: 12,
            ko: 12,
            kk: 12,
          ),
        ),
      ],
      states: {'held': const HeroState.empty().copyWith(currentAsp: 30)},
    );
    repo = SyncingHeroRepository(
      local: lokal,
      remote: cloud,
      metadataStore: InMemorySyncMetadataStore(),
      accountId: 'konto',
    );
  });

  tearDown(() => repo.close());

  /// Zehn Klicks im Abstand von 10 ms, jeder über den frischen Schreibweg.
  Future<Duration> zehnKlicks() async {
    final uhr = Stopwatch()..start();
    final klicks = <Future<HeroState>>[];
    for (var i = 0; i < 10; i++) {
      klicks.add(
        aendereGespeichertenZustand(
          repository: repo,
          heroId: 'held',
          aenderung: _einWeniger,
          uhr: DateTime.now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future.wait(klicks);
    return uhr.elapsed;
  }

  test('jeder Klick zählt, lokal sofort und ohne Konflikt', () async {
    final dauer = await zehnKlicks();

    // Lokal steht jeder Klick, ohne auf die Cloud zu warten: zwei Netzwege
    // je Klick wären hier schon 800 ms.
    expect((await lokal.loadHeroState('held'))!.currentAsp, 20);
    expect(dauer, lessThan(const Duration(milliseconds: 400)));

    await repo.warteAufUebertragungen();
    await Future<void>.delayed(_LangsameCloud.laufzeit * 3);

    final online = await cloud.loadHeroState('held');
    expect(online!.state!.currentAsp, 20);
    expect(repo.currentStatus.openConflicts, isEmpty);
    expect(repo.currentStatus.lastFailure, isNull);
    // Gebündelt: nicht jeder Klick braucht einen eigenen Upload.
    expect(cloud.schreibvorgaenge, lessThan(10));
  });

  test(
    'offline bleibt jeder Klick lokal, der Abgleich holt ihn nach',
    () async {
      cloud.offline = true;

      await zehnKlicks();
      await repo.warteAufUebertragungen();

      expect((await lokal.loadHeroState('held'))!.currentAsp, 20);
      expect(repo.currentStatus.lastFailure, isNotNull);
      expect(repo.currentStatus.openConflicts, isEmpty);

      cloud.offline = false;
      await repo.syncNow();
      await repo.warteAufUebertragungen();

      final online = await cloud.loadHeroState('held');
      expect(online!.state!.currentAsp, 20);
      expect(repo.currentStatus.openConflicts, isEmpty);
      expect(repo.currentStatus.lastFailure, isNull);
    },
  );

  /// Lässt ein anderes Gerät LeP 3 speichern, mit oder ohne Echo hierher.
  Future<void> fremdesGeraet({required bool mitEcho}) async {
    await zehnKlicks();
    await repo.warteAufUebertragungen();
    await Future<void>.delayed(_LangsameCloud.laufzeit * 3);
    final basis = await cloud.loadHeroState('held');
    final fremd = basis!.state!.copyWith(currentLep: 3);
    if (mitEcho) {
      await cloud.saveHeroState(
        'held',
        fremd,
        previousRevision: basis.revision,
      );
    } else {
      await cloud.speichereOhneEcho('held', fremd, basis.revision);
    }
  }

  test(
    'eine gemeldete fremde Änderung wird übernommen, nicht überschrieben',
    () async {
      await fremdesGeraet(mitEcho: true);
      await zehnKlicks();
      await repo.warteAufUebertragungen();
      await Future<void>.delayed(_LangsameCloud.laufzeit * 3);

      final lokalStand = (await lokal.loadHeroState('held'))!;
      final online = (await cloud.loadHeroState('held'))!.state!;
      expect(lokalStand.currentLep, 3);
      expect(lokalStand.currentAsp, 10);
      expect(online.currentLep, 3);
      expect(online.currentAsp, 10);
      expect(repo.currentStatus.openConflicts, isEmpty);
    },
  );

  test('eine nicht gemeldete fremde Änderung wird ein Konflikt', () async {
    await fremdesGeraet(mitEcho: false);
    await zehnKlicks();
    await repo.warteAufUebertragungen();
    await Future<void>.delayed(_LangsameCloud.laufzeit * 3);

    expect(repo.currentStatus.openConflicts, hasLength(1));
    expect((await lokal.loadHeroState('held'))!.currentAsp, 10);
    expect((await cloud.loadHeroState('held'))!.state!.currentLep, 3);
  });
}
