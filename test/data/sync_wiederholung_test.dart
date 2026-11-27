import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/data/sync/sync_wiederholung.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';

import '../test_support/fake_remote_hero_sync_gateway.dart';
import '../test_support/fake_repository.dart';
import '../test_support/in_memory_sync_metadata_store.dart';

HeroSheet _held(String id, String name) => HeroSheet(
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

const SyncWiederholung _schnell = SyncWiederholung(
  abgleichNach: <Duration>[
    Duration(milliseconds: 5),
    Duration(milliseconds: 5),
  ],
  beobachtungNach: <Duration>[Duration(milliseconds: 5)],
);

/// Cloud, die vorübergehend nicht erreichbar ist.
class _WackeligeCloud extends FakeRemoteHeroSyncGateway {
  int ausfaelle = 0;
  int abfragen = 0;

  @override
  Future<List<RemoteHeroRecord>> loadAllHeroes() {
    abfragen++;
    if (ausfaelle > 0) {
      ausfaelle--;
      throw const SyncNetworkException('Cloud nicht erreichbar');
    }
    return super.loadAllHeroes();
  }
}

/// Beobachtung, deren Listener sich von außen zum Abbruch bringen lässt.
class _BeobachteteCloud extends FakeRemoteHeroSyncGateway {
  final List<StreamController<List<RemoteHeroRecord>>> listener =
      <StreamController<List<RemoteHeroRecord>>>[];

  @override
  Stream<List<RemoteHeroRecord>> watchHeroes() {
    final controller = StreamController<List<RemoteHeroRecord>>();
    listener.add(controller);
    return controller.stream;
  }

  /// Bricht den jüngsten Listener ab, wie Firestore nach einem Fehler.
  Future<void> brichAb(Object fehler) async {
    final letzter = listener.last;
    letzter.addError(fehler);
    await letzter.close();
  }
}

Future<void> _warte([int ms = 40]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('SyncWiederholung', () {
    test('wiederholt nur vorübergehende Fehler', () {
      expect(SyncWiederholung.istVoruebergehend(SyncErrorKind.network), isTrue);
      expect(SyncWiederholung.istVoruebergehend(SyncErrorKind.auth), isTrue);
      expect(SyncWiederholung.istVoruebergehend(SyncErrorKind.unknown), isTrue);
      expect(
        SyncWiederholung.istVoruebergehend(SyncErrorKind.conflict),
        isFalse,
      );
      expect(SyncWiederholung.istVoruebergehend(SyncErrorKind.decode), isFalse);
    });

    test('die Wartefolge ist endlich', () {
      const abstaende = <Duration>[Duration(seconds: 1), Duration(seconds: 2)];
      expect(
        SyncWiederholung.wartezeit(abstaende, 0),
        const Duration(seconds: 1),
      );
      expect(
        SyncWiederholung.wartezeit(abstaende, 1),
        const Duration(seconds: 2),
      );
      expect(SyncWiederholung.wartezeit(abstaende, 2), isNull);
    });
  });

  group('SyncingHeroRepository mit Wiederholung', () {
    test('gleicht nach einem Netzfehler von selbst erneut ab', () async {
      final remote = _WackeligeCloud()..ausfaelle = 1;
      await remote.saveHero(_held('h-1', 'Alrik'), previousRevision: null);
      final local = FakeRepository.empty();
      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user-1',
        startRemoteListener: false,
        wiederholung: _schnell,
      );
      addTearDown(repository.close);

      await repository.syncNow();
      expect(repository.currentStatus.lastFailure?.kind, SyncErrorKind.network);

      await _warte();
      expect(remote.abfragen, 2);
      expect(repository.currentStatus.lastFailure, isNull);
      expect(repository.currentStatus.lastSuccessfulSync, isNotNull);
      expect((await local.loadHeroById('h-1'))?.name, 'Alrik');
    });

    test('hört nach der letzten Wartezeit auf', () async {
      final remote = _WackeligeCloud()..ausfaelle = 100;
      final repository = SyncingHeroRepository(
        local: FakeRepository.empty(),
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user-1',
        startRemoteListener: false,
        wiederholung: _schnell,
      );
      addTearDown(repository.close);

      await repository.syncNow();
      await _warte(80);
      // Ein manueller und zwei automatische Versuche.
      expect(remote.abfragen, 3);
      expect(repository.currentStatus.lastFailure, isNotNull);

      // Sichtbar werden beginnt die Folge von vorn.
      remote.ausfaelle = 0;
      await repository.wiederholeNachFehler();
      expect(remote.abfragen, 4);
      expect(repository.currentStatus.lastFailure, isNull);
    });

    test('ohne Wiederholung bleibt es beim manuellen Abgleich', () async {
      final remote = _WackeligeCloud()..ausfaelle = 1;
      final repository = SyncingHeroRepository(
        local: FakeRepository.empty(),
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user-1',
        startRemoteListener: false,
      );
      addTearDown(repository.close);

      await repository.syncNow();
      await _warte();
      expect(remote.abfragen, 1);
      expect(repository.currentStatus.lastFailure, isNotNull);

      await repository.wiederholeNachFehler();
      expect(remote.abfragen, 1);
    });

    test('wiederholeNachFehler tut ohne Fehler nichts', () async {
      final remote = _WackeligeCloud();
      final repository = SyncingHeroRepository(
        local: FakeRepository.empty(),
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user-1',
        startRemoteListener: false,
        wiederholung: _schnell,
      );
      addTearDown(repository.close);

      await repository.syncNow();
      await repository.wiederholeNachFehler();
      expect(remote.abfragen, 1);
    });

    test('Konflikte werden nicht automatisch wiederholt', () async {
      final remote = _KonfliktCloud();
      final repository = SyncingHeroRepository(
        local: FakeRepository.empty(),
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user-1',
        startRemoteListener: false,
        wiederholung: _schnell,
      );
      addTearDown(repository.close);

      await repository.syncNow();
      expect(
        repository.currentStatus.lastFailure?.kind,
        SyncErrorKind.conflict,
      );
      await _warte();
      expect(remote.abfragen, 1);
    });

    test('startet einen abgebrochenen Listener neu', () async {
      final remote = _BeobachteteCloud();
      final repository = SyncingHeroRepository(
        local: FakeRepository.empty(),
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user-1',
        wiederholung: _schnell,
      );
      addTearDown(repository.close);
      expect(remote.listener, hasLength(1));

      await remote.brichAb(const SyncAuthException('Token abgelaufen'));
      await _warte();
      expect(remote.listener, hasLength(2));

      // Der neue Listener liefert wieder Online-Stände.
      final record = await remote.saveHero(
        _held('h-1', 'Alrik'),
        previousRevision: null,
      );
      remote.listener.last.add(<RemoteHeroRecord>[record]);
      await _warte();
      expect((await repository.local.loadHeroById('h-1'))?.name, 'Alrik');
    });

    test('ohne Wiederholung bleibt ein abgebrochener Listener aus', () async {
      final remote = _BeobachteteCloud();
      final repository = SyncingHeroRepository(
        local: FakeRepository.empty(),
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user-1',
      );
      addTearDown(repository.close);

      await remote.brichAb(const SyncAuthException('Token abgelaufen'));
      await _warte();
      expect(remote.listener, hasLength(1));
      expect(repository.currentStatus.lastFailure?.kind, SyncErrorKind.auth);
    });

    test('close beendet geplante Versuche', () async {
      final remote = _WackeligeCloud()..ausfaelle = 100;
      final repository = SyncingHeroRepository(
        local: FakeRepository.empty(),
        remote: remote,
        metadataStore: InMemorySyncMetadataStore(),
        accountId: 'user-1',
        startRemoteListener: false,
        wiederholung: _schnell,
      );

      await repository.syncNow();
      await repository.close();
      await _warte();
      expect(remote.abfragen, 1);
    });
  });
}

/// Meldet beim Abgleich einen Konflikt-Fehler, ohne die Cloud zu fragen.
class _KonfliktCloud extends FakeRemoteHeroSyncGateway {
  int abfragen = 0;

  @override
  Future<List<RemoteHeroRecord>> loadAllHeroes() async {
    abfragen++;
    throw const SyncPreconditionException('Revision geändert');
  }
}
