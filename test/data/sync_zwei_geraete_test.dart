import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/sync_geraete.dart';

const String _krieger = 'bestand-f01';
const String _geode = 'bestand-f02';
const String _geweihter = 'bestand-f03';

// Legt einen Bestandshelden samt Zustand ueber das Sync-Repository an, so
// wie ein Import es tut.
Future<void> _importiere(SyncTestGeraet geraet, Bestandsheld held) async {
  final HeroTransferBundle bundle = ladeBestandsheld(held);
  await geraet.repo.saveHero(bundle.hero);
  await geraet.repo.saveHeroState(bundle.hero.id, bundle.state);
}

// Speichert eine Aenderung am lokal gespeicherten Helden.
Future<void> _aendere(
  SyncTestGeraet geraet,
  String heroId,
  HeroSheet Function(HeroSheet held) aenderung,
) async {
  final held = (await geraet.lokal.loadHeroById(heroId))!;
  await geraet.repo.saveHero(aenderung(held));
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

  // Gemeinsamer Ausgangsstand: A importiert, beide gleichen ab.
  Future<void> gemeinsamerStart(List<Bestandsheld> helden) async {
    for (final held in helden) {
      await _importiere(a, held);
    }
    await a.repo.syncNow();
    await b.repo.syncNow();
  }

  group('S1 gemeinsame Ausgangsversion', () {
    test('beide Geräte und die Cloud tragen denselben Inhalt', () async {
      await gemeinsamerStart(<Bestandsheld>[
        Bestandsheld.kriegerNormal,
        Bestandsheld.geodeMagisch,
      ]);

      for (final id in <String>[_krieger, _geode]) {
        final cloudHeld = (await cloud.loadHero(id))!;
        expect(await a.heldHash(id), cloudHeld.contentHash);
        expect(await b.heldHash(id), cloudHeld.contentHash);
        expect(
          heroStateContentHash((await b.lokal.loadHeroState(id))!),
          (await cloud.loadHeroState(id))!.contentHash,
        );
      }
      expect(a.konflikte, isEmpty);
      expect(b.konflikte, isEmpty);
    });

    test('eine weitere Runde schreibt nichts', () async {
      await gemeinsamerStart(<Bestandsheld>[
        Bestandsheld.kriegerNormal,
        Bestandsheld.geodeMagisch,
      ]);
      final vorher = cloud.schreibvorgaenge;

      await a.repo.syncNow();
      await b.repo.syncNow();

      expect(cloud.schreibvorgaenge, vorher);
    });
  });

  test('S2 unabhängige Änderungen an verschiedenen Helden', () async {
    await gemeinsamerStart(<Bestandsheld>[
      Bestandsheld.kriegerNormal,
      Bestandsheld.geodeMagisch,
    ]);
    final kriegerVorher = cloud.heldSchreibvorgaenge[_krieger]!;
    final geodeVorher = cloud.heldSchreibvorgaenge[_geode]!;

    await _aendere(a, _krieger, (held) => held.copyWith(dukaten: '20'));
    await _aendere(b, _geode, (held) => held.copyWith(dukaten: '5'));
    await a.repo.syncNow();
    await b.repo.syncNow();
    await a.repo.syncNow();

    for (final geraet in <SyncTestGeraet>[a, b]) {
      expect(geraet.konflikte, isEmpty);
      expect((await geraet.lokal.loadHeroById(_krieger))!.dukaten, '20');
      expect((await geraet.lokal.loadHeroById(_geode))!.dukaten, '5');
    }
    expect(cloud.heldSchreibvorgaenge[_krieger], kriegerVorher + 1);
    expect(cloud.heldSchreibvorgaenge[_geode], geodeVorher + 1);
  });

  group('S3 derselbe Held auf beiden Geräten', () {
    // Beide aendern offline, A kommt zuerst wieder online.
    Future<void> konkurrierendeAenderung() async {
      await gemeinsamerStart(<Bestandsheld>[Bestandsheld.kriegerNormal]);
      a.remote.offline = true;
      b.remote.offline = true;
      await _aendere(a, _krieger, (held) => held.copyWith(dukaten: '20'));
      await _aendere(b, _krieger, (held) => held.copyWith(dukaten: '30'));
      a.remote.offline = false;
      b.remote.offline = false;
      await a.repo.syncNow();
      await b.repo.syncNow();
    }

    test('ergibt genau einen Konflikt auf dem zweiten Gerät', () async {
      await konkurrierendeAenderung();

      expect(a.konflikte, isEmpty);
      expect(b.konflikte.map((konflikt) => konflikt.id), <String>[
        'hero-$_krieger',
      ]);
      expect((await b.lokal.loadHeroById(_krieger))!.dukaten, '30');
    });

    final erwartet = <SyncResolutionChoice, String>{
      SyncResolutionChoice.keepLocal: '30',
      SyncResolutionChoice.keepRemote: '20',
      SyncResolutionChoice.keepBoth: '20',
    };
    for (final eintrag in erwartet.entries) {
      test('${eintrag.key.name}: beide Geräte enden gleich', () async {
        await konkurrierendeAenderung();

        await b.repo.resolveConflict(b.konflikte.single.id, eintrag.key);
        await a.repo.syncNow();
        await b.repo.syncNow();

        expect(a.konflikte, isEmpty);
        expect(b.konflikte, isEmpty);
        for (final geraet in <SyncTestGeraet>[a, b]) {
          final held = (await geraet.lokal.loadHeroById(_krieger))!;
          expect(held.dukaten, eintrag.value);
        }
        expect(await a.heldHash(_krieger), await b.heldHash(_krieger));

        if (eintrag.key == SyncResolutionChoice.keepBoth) {
          for (final geraet in <SyncTestGeraet>[a, b]) {
            final kopie = (await geraet.lokal.listHeroes()).singleWhere(
              (held) => held.name.endsWith('(lokale Kopie)'),
            );
            expect(kopie.dukaten, '30');
          }
        }

        final vorher = cloud.schreibvorgaenge;
        await a.repo.syncNow();
        await b.repo.syncNow();
        expect(cloud.schreibvorgaenge, vorher, reason: 'danach Ruhe');
      });
    }
  });

  group('S4 Abbruch mitten im Abgleich', () {
    test(
      'die Wiederholung legt den Rest ab, ohne doppelt zu schreiben',
      () async {
        a.remote.offline = true;
        for (final held in <Bestandsheld>[
          Bestandsheld.kriegerNormal,
          Bestandsheld.geodeMagisch,
          Bestandsheld.geweihterKarmal,
        ]) {
          await _importiere(a, held);
        }
        a.remote
          ..offline = false
          ..schreibvorgaengeBisAbbruch = 1;

        await a.repo.syncNow();

        expect(a.repo.currentStatus.lastFailure?.kind, SyncErrorKind.network);
        // Namensreihenfolge: Alrik (f01) kommt zuerst durch.
        expect(cloud.heldSchreibvorgaenge, <String, int>{_krieger: 1});

        a.remote.schreibvorgaengeBisAbbruch = null;
        await a.repo.syncNow();

        expect(a.repo.currentStatus.lastFailure, isNull);
        expect(cloud.heldSchreibvorgaenge, <String, int>{
          _krieger: 1,
          _geode: 1,
          _geweihter: 1,
        });
        expect(a.konflikte, isEmpty);
      },
    );

    test('eine verlorene Antwort führt weder zu Doppelbuchung noch '
        'Konflikt', () async {
      await gemeinsamerStart(<Bestandsheld>[Bestandsheld.kriegerNormal]);
      final vorher = cloud.heldSchreibvorgaenge[_krieger]!;
      a.remote.naechsteAntwortVerlieren = true;

      await _aendere(a, _krieger, (held) => held.copyWith(dukaten: '20'));
      expect((await cloud.loadHero(_krieger))!.hero!.dukaten, '20');
      await a.repo.syncNow();

      expect(a.konflikte, isEmpty);
      expect(cloud.heldSchreibvorgaenge[_krieger], vorher + 1);
      await b.repo.syncNow();
      expect((await b.lokal.loadHeroById(_krieger))!.dukaten, '20');
    });
  });

  group('S5 Neustart mit ausstehendem Abgleich', () {
    test(
      'ein offline gespeicherter Stand wird genau einmal übertragen',
      () async {
        await gemeinsamerStart(<Bestandsheld>[Bestandsheld.kriegerNormal]);
        final vorher = cloud.heldSchreibvorgaenge[_krieger]!;
        a.remote.offline = true;
        await _aendere(a, _krieger, (held) => held.copyWith(dukaten: '20'));

        await a.neustart();
        a.remote.offline = false;
        await a.repo.syncNow();
        await a.repo.syncNow();

        expect(cloud.heldSchreibvorgaenge[_krieger], vorher + 1);
        expect((await cloud.loadHero(_krieger))!.hero!.dukaten, '20');
      },
    );

    test(
      'mit echtem Hive überlebt der ausstehende Abgleich den Neustart',
      () async {
        final pfad = await hiveTempVerzeichnis('arch07_sync_');
        final remote = GeraeteRemote(cloud);

        Future<(SyncingHeroRepository, Future<void> Function())>
        starte() async {
          final lokal = await HiveHeroRepository.create(storagePath: pfad);
          final metadaten = await HiveSyncMetadataStore.create(
            storagePath: pfad,
          );
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
        await repo.syncNow();
        final vorher = cloud.heldSchreibvorgaenge[_krieger]!;

        remote.offline = true;
        await repo.saveHero(bundle.hero.copyWith(dukaten: '20'));
        await schliessen();

        (repo, schliessen) = await starte();
        remote.offline = false;
        await repo.syncNow();
        await repo.syncNow();

        expect(cloud.heldSchreibvorgaenge[_krieger], vorher + 1);
        expect((await cloud.loadHero(_krieger))!.hero!.dukaten, '20');
        expect(repo.currentStatus.openConflicts, isEmpty);
      },
    );

    test('Befund ARCH-07-B8: offline geänderte Lebenspunkte lädt der '
        'nächste Abgleich nicht hoch', () async {
      await gemeinsamerStart(<Bestandsheld>[Bestandsheld.kriegerNormal]);
      final vorher = cloud.zustandSchreibvorgaenge[_krieger]!;
      a.remote.offline = true;
      final zustand = (await a.lokal.loadHeroState(_krieger))!;
      await a.repo.saveHeroState(_krieger, zustand.copyWith(currentLep: 11));

      a.remote.offline = false;
      await a.repo.syncNow();
      await a.neustart();
      await a.repo.syncNow();

      // Gewollt wäre 11 in der Cloud und ein Schreibvorgang mehr:
      // `_syncHeroStates` lädt nur Zustände hoch, die online noch fehlen.
      expect((await cloud.loadHeroState(_krieger))!.state!.currentLep, 28);
      expect(cloud.zustandSchreibvorgaenge[_krieger], vorher);
      expect((await a.lokal.loadHeroState(_krieger))!.currentLep, 11);
      expect(a.konflikte, isEmpty);
    });

    test('Befund ARCH-07-B1: ein Inspector-Modifikator erzeugt nach dem '
        'Neuladen einen zusätzlichen Upload', () async {
      await gemeinsamerStart(<Bestandsheld>[Bestandsheld.freitextMerkmale]);
      const id = 'bestand-f05';
      final vorher = cloud.heldSchreibvorgaenge[id]!;

      // So speichert der Inspector: nur `persistentMods`, benannte
      // Modifikatoren leer. Erst das Laden aus JSON spiegelt den Wert.
      await _aendere(a, id, (held) {
        return held.copyWith(
          persistentMods: held.persistentMods.copyWith(iniBase: 2),
          statModifiers: const {},
        );
      });
      await a.repo.syncNow();
      await a.repo.syncNow();

      // Gewollt wäre +1: Der gespeicherte Stand ist nach dem Laden ein
      // anderer als der hochgeladene, die nächste Runde lädt erneut hoch.
      expect(cloud.heldSchreibvorgaenge[id], vorher + 2);
      expect(a.konflikte, isEmpty);
    });
  });

  group('S6 Held und Zustand gemeinsam', () {
    // A aendert Held und Lebenspunkte online, B dieselben offline.
    // (Offline geaenderte Zustaende laedt `syncNow` nicht hoch, Befund B8 —
    // deshalb ist A hier online.)
    Future<void> konkurrierendeAenderung() async {
      await gemeinsamerStart(<Bestandsheld>[Bestandsheld.kriegerNormal]);
      b.remote.offline = true;
      for (final (geraet, dukaten, lep) in <(SyncTestGeraet, String, int)>[
        (a, '20', 11),
        (b, '30', 22),
      ]) {
        await _aendere(
          geraet,
          _krieger,
          (held) => held.copyWith(dukaten: dukaten),
        );
        final zustand = (await geraet.lokal.loadHeroState(_krieger))!;
        await geraet.repo.saveHeroState(
          _krieger,
          zustand.copyWith(currentLep: lep),
        );
      }
      b.remote.offline = false;
      await b.repo.syncNow();
    }

    test(
      'ergibt einen einzigen Konflikt, der den Zustand einschließt',
      () async {
        await konkurrierendeAenderung();

        final konflikt = b.konflikte.single;
        expect(konflikt.id, 'hero-$_krieger');
        expect(konflikt.includesHeroState, isTrue);
      },
    );

    final erwartet = <SyncResolutionChoice, int>{
      SyncResolutionChoice.keepLocal: 22,
      SyncResolutionChoice.keepRemote: 11,
      SyncResolutionChoice.keepBoth: 11,
    };
    for (final eintrag in erwartet.entries) {
      test('${eintrag.key.name}: der Zustand folgt seinem Helden', () async {
        await konkurrierendeAenderung();

        await b.repo.resolveConflict(b.konflikte.single.id, eintrag.key);
        await a.repo.syncNow();
        await b.repo.syncNow();

        expect(a.konflikte, isEmpty);
        expect(b.konflikte, isEmpty);
        for (final geraet in <SyncTestGeraet>[a, b]) {
          final zustand = (await geraet.lokal.loadHeroState(_krieger))!;
          expect(zustand.currentLep, eintrag.value);
        }
        if (eintrag.key == SyncResolutionChoice.keepBoth) {
          final kopie = (await b.lokal.listHeroes()).singleWhere(
            (held) => held.name.endsWith('(lokale Kopie)'),
          );
          expect((await b.lokal.loadHeroState(kopie.id))!.currentLep, 22);
        }
      });
    }
  });
}
