import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/held_importieren.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/schaden_erhalten.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/schaden_zuruecknehmen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/vorgaenge_wiederaufnehmen.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/hive_vorgangsjournal.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_ruecknahme_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/sync_geraete.dart';

// Speichervertrag ARCH-06: Bogen und Zustand werden als ganze Dokumente mit
// Revision übertragen; ausstehend ist, was vom gemerkten Hash abweicht. Ein
// Neustart verliert deshalb keinen Abgleich, und eine Wiederholung schreibt
// dasselbe Dokument, statt eine Aktion erneut anzuwenden.

const String _krieger = 'bestand-f01';

/// Leitet alles an [_innen] weiter; nur das Speichern des Zustands hängt —
/// so bricht ein Import nach dem Bogen ab.
class _HaengtBeimZustand implements HeroRepository {
  _HaengtBeimZustand(this._innen);

  final HeroRepository _innen;

  @override
  Future<void> saveHeroState(String heroId, HeroState state) =>
      Completer<void>().future;

  @override
  Future<void> deleteHero(String heroId) => _innen.deleteHero(heroId);

  @override
  Future<List<HeroSheet>> listHeroes() => _innen.listHeroes();

  @override
  Future<HeroSheet?> loadHeroById(String heroId) => _innen.loadHeroById(heroId);

  @override
  Future<HeroState?> loadHeroState(String heroId) =>
      _innen.loadHeroState(heroId);

  @override
  Future<void> saveHero(HeroSheet hero) => _innen.saveHero(hero);

  @override
  Stream<Map<String, HeroSheet>> watchHeroIndex() => _innen.watchHeroIndex();

  @override
  Stream<HeroState> watchHeroState(String heroId) =>
      _innen.watchHeroState(heroId);
}

void main() {
  late GeteilteCloud cloud;
  late SyncTestGeraet a;
  late SyncTestGeraet b;

  setUp(() {
    cloud = GeteilteCloud();
    a = SyncTestGeraet(cloud);
    b = SyncTestGeraet(cloud);
  });

  Future<void> gemeinsamerStart() async {
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    await a.repo.saveHero(bundle.hero);
    await a.repo.saveHeroState(_krieger, bundle.state);
    await a.repo.syncNow();
    await b.repo.syncNow();
  }

  test('ein offline geänderter Zustand übersteht den Neustart und wird '
      'genau einmal übertragen', () async {
    await gemeinsamerStart();
    final vorher = cloud.zustandSchreibvorgaenge[_krieger]!;
    a.remote.offline = true;
    final zustand = (await a.lokal.loadHeroState(_krieger))!;
    await a.repo.saveHeroState(_krieger, zustand.copyWith(currentLep: 9));
    await a.repo.warteAufUebertragungen();

    await a.neustart();
    a.remote.offline = false;
    await a.repo.syncNow();
    await a.repo.syncNow();

    expect(cloud.zustandSchreibvorgaenge[_krieger], vorher + 1);
    expect(a.konflikte, isEmpty);
    await b.repo.syncNow();
    expect((await b.lokal.loadHeroState(_krieger))!.currentLep, 9);
  });

  test(
    'mit echtem Hive überlebt ein ausstehender Zustand den Neustart',
    () async {
      final pfad = await hiveTempVerzeichnis('arch06_zustand_');
      final remote = GeraeteRemote(cloud);

      Future<(SyncingHeroRepository, Future<void> Function())> starte() async {
        final lokal = await HiveHeroRepository.create(storagePath: pfad);
        final metadaten = await HiveSyncMetadataStore.create(storagePath: pfad);
        final repo = SyncingHeroRepository(
          local: lokal,
          remote: remote,
          metadataStore: metadaten,
          accountId: 'konto-1',
          startRemoteListener: false,
        );
        var geschlossen = false;
        Future<void> schliessen() async {
          if (geschlossen) return;
          geschlossen = true;
          await repo.close();
          await lokal.close();
          await metadaten.close();
        }

        addTearDown(schliessen);
        return (repo, schliessen);
      }

      var (repo, schliessen) = await starte();
      final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
      await repo.saveHero(bundle.hero);
      await repo.saveHeroState(_krieger, bundle.state);
      await repo.syncNow();
      final vorher = cloud.zustandSchreibvorgaenge[_krieger]!;

      remote.offline = true;
      await repo.saveHeroState(_krieger, bundle.state.copyWith(currentLep: 9));
      await repo.warteAufUebertragungen();
      await schliessen();

      (repo, schliessen) = await starte();
      remote.offline = false;
      await repo.syncNow();
      await repo.syncNow();

      expect(cloud.zustandSchreibvorgaenge[_krieger], vorher + 1);
      expect((await cloud.loadHeroState(_krieger))!.state!.currentLep, 9);
      expect(repo.currentStatus.openConflicts, isEmpty);
    },
  );

  test('eine verlorene Antwort beim Zustand schreibt genau einmal und '
      'meldet keinen Konflikt', () async {
    await gemeinsamerStart();
    final vorher = cloud.zustandSchreibvorgaenge[_krieger]!;
    a.remote.naechsteAntwortVerlieren = true;

    final zustand = (await a.lokal.loadHeroState(_krieger))!;
    await a.repo.saveHeroState(_krieger, zustand.copyWith(currentLep: 9));
    await a.repo.warteAufUebertragungen();
    await a.repo.syncNow();
    await a.repo.syncNow();

    expect(cloud.zustandSchreibvorgaenge[_krieger], vorher + 1);
    expect(a.konflikte, isEmpty);
    await b.repo.syncNow();
    expect((await b.lokal.loadHeroState(_krieger))!.currentLep, 9);
  });

  test('ein abgebrochener Import wird beim Neustart vor dem Abgleich zu Ende '
      'geführt und sein Zustand genau einmal übertragen', () async {
    final pfad = await hiveTempVerzeichnis('arch06_import_');
    final journal = await HiveVorgangsjournal.create(storagePath: pfad);
    addTearDown(journal.close);
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);

    unawaited(
      HeldImportieren(
        repository: _HaengtBeimZustand(a.repo),
        speichere: (held) async {
          await a.repo.saveHero(held);
          return held;
        },
        uebernimmKatalog: (_) async {},
        speichereGaleriebild: ({
          required heroId,
          required entryId,
          required bytes,
        }) async => '',
        speichereHauptbild: ({required heroId, required bytes}) async => '',
        loescheBild: (_) async {},
        journal: journal,
        neueId: () => 'neu',
        uhr: DateTime.now,
        maxHelden: 5,
      ).importiere(bundle, neuAnlegen: false),
    );
    await pumpEventQueue();
    expect(await a.lokal.loadHeroState(_krieger), isNull);
    expect((await cloud.loadHero(_krieger))?.hero, isNotNull);

    // Neustart: Wiederanlauf auf dem lokalen Speicher, dann Abgleich.
    await a.neustart();
    final bericht = await VorgaengeWiederaufnehmen(
      repository: a.lokal,
      journal: journal,
      loescheBild: (_) async {},
      uhr: DateTime.now,
    ).fuehreAus();
    await a.repo.syncNow();
    await a.repo.syncNow();

    expect(bericht.fortgesetzt, 1);
    expect(await journal.offene(), isEmpty);
    expect(cloud.zustandSchreibvorgaenge[_krieger], 1);
    expect(a.konflikte, isEmpty);
    await b.repo.syncNow();
    expect(
      (await b.lokal.loadHeroState(_krieger))!.currentLep,
      bundle.state.currentLep,
    );
  });

  group('Buchungen auf zwei Geräten (ARCH-06)', () {
    Future<void> bucheTreffer(SyncTestGeraet geraet, String id, int tp) async {
      await SchadenErhalten(
        repository: geraet.repo,
        uhr: DateTime.now,
      ).uebernehmeSchaden(
        heroId: _krieger,
        buchung: SchadensBuchung(art: SchadensArt.lebensenergie, tp: tp, rs: 0),
        vorgangId: id,
      );
      await geraet.repo.warteAufUebertragungen();
    }

    Future<HeroState> zustand(SyncTestGeraet geraet) async =>
        (await geraet.lokal.loadHeroState(_krieger))!;

    // LeP und Buchungen passen zusammen: keine halbe oder doppelte Buchung.
    void erwarteStimmig(HeroState zustand, int startLep) {
      final summe = zustand.buchungen.fold<int>(
        0,
        (bisher, buchung) => bisher + buchung.lepDelta,
      );
      expect(zustand.currentLep, startLep + summe);
    }

    test('eine verlorene Antwort bucht den Treffer genau einmal', () async {
      await gemeinsamerStart();
      final startLep = (await zustand(a)).currentLep;
      final vorher = cloud.zustandSchreibvorgaenge[_krieger]!;
      a.remote.naechsteAntwortVerlieren = true;

      await bucheTreffer(a, 't1', 6);
      // Der Nutzer versucht es erneut: dieselbe Vorgangs-ID.
      await bucheTreffer(a, 't1', 6);
      await a.repo.syncNow();
      await a.repo.syncNow();
      await b.repo.syncNow();

      expect(cloud.zustandSchreibvorgaenge[_krieger], vorher + 1);
      expect(a.konflikte, isEmpty);
      final beiB = await zustand(b);
      expect(beiB.currentLep, startLep - 6);
      expect(
        beiB.buchungen.where((buchung) => buchung.id == 't1'),
        hasLength(1),
      );
    });

    test('B nimmt zurück, A übernimmt die Rücknahme und kann sie nicht '
        'wiederholen', () async {
      await gemeinsamerStart();
      final startLep = (await zustand(a)).currentLep;
      await bucheTreffer(a, 't1', 6);
      await a.repo.syncNow();
      await b.repo.syncNow();

      await SchadenZuruecknehmen(
        repository: b.repo,
        uhr: DateTime.now,
      ).nimmZurueck(heroId: _krieger, buchungId: 't1', vorgangId: 'r1');
      await b.repo.warteAufUebertragungen();
      await b.repo.syncNow();
      await a.repo.syncNow();

      final beiA = await zustand(a);
      expect(beiA.currentLep, startLep);
      expect(
        schadensBuchungsStatus(beiA, 't1'),
        SchadensBuchungsStatus.zurueckgenommen,
      );
      await expectLater(
        SchadenZuruecknehmen(
          repository: a.repo,
          uhr: DateTime.now,
        ).nimmZurueck(heroId: _krieger, buchungId: 't1', vorgangId: 'r2'),
        throwsA(isA<StateError>()),
      );
    });

    test('offline gebuchte Treffer beider Geräte werden ohne Konflikt '
        'zusammengeführt und bleiben einzeln zurücknehmbar', () async {
      await gemeinsamerStart();
      final startLep = (await zustand(a)).currentLep;
      a.remote.offline = true;
      b.remote.offline = true;
      await bucheTreffer(a, 'ta', 5);
      await bucheTreffer(b, 'tb', 7);
      a.remote.offline = false;
      b.remote.offline = false;
      await a.repo.syncNow();
      await b.repo.syncNow();
      await a.repo.syncNow();

      expect(a.konflikte, isEmpty);
      expect(b.konflikte, isEmpty);
      for (final geraet in <SyncTestGeraet>[a, b]) {
        final ergebnis = await zustand(geraet);
        expect(ergebnis.currentLep, startLep - 12);
        expect(ergebnis.buchungen.map((buchung) => buchung.id).toSet(), {
          'ta',
          'tb',
        });
        erwarteStimmig(ergebnis, startLep);
        expect(
          schadensBuchungsStatus(ergebnis, 'ta'),
          SchadensBuchungsStatus.ruecknehmbar,
        );
      }
    });
  });
}
