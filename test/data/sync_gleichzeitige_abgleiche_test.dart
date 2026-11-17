import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support/in_memory_sync_metadata_store.dart';

import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/data/sync/sync_basis_store.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/sync_geraete.dart';

const String _krieger = 'bestand-f01';

/// Leitung, deren Schreibvorgänge an einem Tor warten können, wie ein
/// Upload, der noch unterwegs ist.
class _TorRemote extends GeraeteRemote {
  _TorRemote(super.cloud);

  Completer<void>? tor;
  final StreamController<void> erreicht = StreamController<void>.broadcast();

  /// `loadHero` wirft einen Fehler ohne Sync-Typ (etwa ein aufgebrauchtes
  /// Kontingent oder ein unlesbares Online-Dokument).
  bool ladenWirftFremdenFehler = false;

  Future<void> _warte() async {
    final offen = tor;
    if (offen != null) {
      erreicht.add(null);
      await offen.future;
    }
  }

  void oeffne() {
    tor?.complete();
    tor = null;
  }

  @override
  Future<RemoteHeroRecord?> loadHero(String heroId) {
    if (ladenWirftFremdenFehler) {
      throw StateError('resource-exhausted');
    }
    return super.loadHero(heroId);
  }

  @override
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  }) async {
    await _warte();
    return super.saveHero(hero, previousRevision: previousRevision);
  }

  @override
  Future<RemoteHeroStateRecord> saveHeroState(
    String heroId,
    HeroState state, {
    required String? previousRevision,
  }) async {
    await _warte();
    return super.saveHeroState(
      heroId,
      state,
      previousRevision: previousRevision,
    );
  }
}

class _TorGeraet {
  _TorGeraet(GeteilteCloud cloud) : remote = _TorRemote(cloud) {
    repo = SyncingHeroRepository(
      local: lokal,
      remote: remote,
      metadataStore: InMemorySyncMetadataStore(),
      basisStore: SpeicherSyncBasisStore(),
      accountId: 'konto-1',
      startRemoteListener: false,
    );
  }

  final _TorRemote remote;
  final JsonHeroRepository lokal = JsonHeroRepository();
  late final SyncingHeroRepository repo;

  List<SyncConflict> get konflikte => repo.currentStatus.openConflicts;
}

Future<void> _ruhe() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late GeteilteCloud cloud;
  late SyncTestGeraet a;
  late _TorGeraet b;
  late FlutterExceptionHandler? frueher;

  setUp(() async {
    // Gemeldete Übertragungsfehler (offline) sind hier erwartet.
    frueher = FlutterError.onError;
    FlutterError.onError = (_) {};
    cloud = GeteilteCloud();
    a = SyncTestGeraet(cloud);
    b = _TorGeraet(cloud);
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    await a.repo.saveHero(bundle.hero);
    await a.repo.saveHeroState(bundle.hero.id, bundle.state);
    await a.repo.warteAufUebertragungen();
    await a.repo.syncNow();
    await b.repo.syncNow();
  });

  tearDown(() {
    FlutterError.onError = frueher;
  });

  // B ändert offline die Dukaten, A online den Namen: Beim nächsten Abgleich
  // von B ist eine stille Zusammenführung fällig.
  Future<void> beideAendernDenHelden() async {
    b.remote.offline = true;
    final bHeld = (await b.lokal.loadHeroById(_krieger))!;
    await b.repo.saveHero(bHeld.copyWith(dukaten: '111'));
    b.remote.offline = false;
    final aHeld = (await a.lokal.loadHeroById(_krieger))!;
    await a.repo.saveHero(aHeld.copyWith(name: 'Neuer Name'));
  }

  group('Speichern während der stillen Zusammenführung (SYNC-01)', () {
    test(
      'eine weitere Heldenänderung bleibt lokal und online erhalten',
      () async {
        await beideAendernDenHelden();

        b.remote.tor = Completer<void>();
        final unterwegs = b.remote.erreicht.stream.first;
        final abgleich = b.repo.syncNow();
        await unterwegs;

        final frisch = (await b.lokal.loadHeroById(_krieger))!;
        final speichern = b.repo.saveHero(frisch.copyWith(gottheit: 'Phex'));
        await _ruhe();

        b.remote.oeffne();
        await abgleich;
        await speichern;

        final lokal = (await b.lokal.loadHeroById(_krieger))!;
        expect(lokal.gottheit, 'Phex');
        expect(lokal.dukaten, '111');
        expect(lokal.name, 'Neuer Name');
        final online = (await cloud.loadHero(_krieger))!;
        expect(online.contentHash, heroContentHash(lokal));
        expect(b.konflikte, isEmpty);
      },
    );

    test(
      'widerspricht sie dem Online-Stand, entscheidet ein Konflikt',
      () async {
        await beideAendernDenHelden();

        b.remote.tor = Completer<void>();
        final unterwegs = b.remote.erreicht.stream.first;
        final abgleich = b.repo.syncNow();
        await unterwegs;

        // Derselbe Wert, den A geändert hat.
        final frisch = (await b.lokal.loadHeroById(_krieger))!;
        final speichern = b.repo.saveHero(
          frisch.copyWith(name: 'Lokaler Name'),
        );
        await _ruhe();

        b.remote.oeffne();
        await abgleich;
        await speichern;

        // Nichts überschrieben: lokal die eigene Fassung, online die von A.
        expect((await b.lokal.loadHeroById(_krieger))!.name, 'Lokaler Name');
        expect((await cloud.loadHero(_krieger))!.hero!.name, 'Neuer Name');
        expect(b.konflikte, hasLength(1));
        expect(b.konflikte.single.localSummary, 'Lokaler Name');
        expect(b.konflikte.single.remoteSummary, 'Neuer Name');
      },
    );

    test('ein Klick am Zustand bleibt erhalten', () async {
      b.remote.offline = true;
      final bZustand = (await b.lokal.loadHeroState(_krieger))!;
      await b.repo.saveHeroState(_krieger, bZustand.copyWith(currentLep: 20));
      await b.repo.warteAufUebertragungen();
      b.remote.offline = false;
      final aZustand = (await a.lokal.loadHeroState(_krieger))!;
      await a.repo.saveHeroState(_krieger, aZustand.copyWith(currentAsp: 7));
      await a.repo.warteAufUebertragungen();

      b.remote.tor = Completer<void>();
      final unterwegs = b.remote.erreicht.stream.first;
      final abgleich = b.repo.syncNow();
      await unterwegs;

      final frisch = (await b.lokal.loadHeroState(_krieger))!;
      await b.repo.saveHeroState(_krieger, frisch.copyWith(currentLep: 15));
      await _ruhe();

      b.remote.oeffne();
      await abgleich;
      await b.repo.warteAufUebertragungen();

      final lokal = (await b.lokal.loadHeroState(_krieger))!;
      expect(lokal.currentLep, 15);
      expect(lokal.currentAsp, 7);
      final online = (await cloud.loadHeroState(_krieger))!.state!;
      expect(online.currentLep, 15);
      expect(online.currentAsp, 7);
      expect(b.konflikte, isEmpty);
    });
  });

  test('zwei gleichzeitige Abgleiche stellen keinen Scheinkonflikt '
      '(SYNC-04)', () async {
    await beideAendernDenHelden();

    await Future.wait(<Future<void>>[b.repo.syncNow(), b.repo.syncNow()]);

    expect(b.konflikte, isEmpty);
    final lokal = (await b.lokal.loadHeroById(_krieger))!;
    expect(lokal.dukaten, '111');
    expect(lokal.name, 'Neuer Name');
    expect(
      (await cloud.loadHero(_krieger))!.contentHash,
      heroContentHash(lokal),
    );
  });

  test('ein Übertragungsfehler ohne Sync-Typ lässt das Speichern gelingen '
      '(SYNC-03)', () async {
    b.remote.ladenWirftFremdenFehler = true;
    final held = (await b.lokal.loadHeroById(_krieger))!;

    await b.repo.saveHero(held.copyWith(dukaten: '222'));

    expect((await b.lokal.loadHeroById(_krieger))!.dukaten, '222');
    expect(b.repo.currentStatus.lastFailure, isNotNull);

    // Der nächste Abgleich holt den Upload nach.
    b.remote.ladenWirftFremdenFehler = false;
    await b.repo.syncNow();
    expect((await cloud.loadHero(_krieger))!.hero!.dukaten, '222');
  });
}
