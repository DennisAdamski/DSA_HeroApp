import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_vorgangsjournal.dart';
import 'package:dsa_heldenverwaltung/data/sync/sync_konflikt_vorgang.dart';
import 'package:dsa_heldenverwaltung/data/vorgangsjournal.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/sync_geraete.dart';

// ARCH-06: Konfliktentscheidungen über Bogen und Zustand sind dauerhaft.
// Jeder Abbruch, jede verlorene Antwort und jeder Neustart setzt die einmal
// gewählte Fassung fort; nichts wird doppelt oder gegen eine neuere Änderung
// geschrieben.
//
// Aufbau wie in der Abnahme (docs/arch06_abnahme.md): A und B gleichen
// denselben Helden mit 28 LeP ab, ändern offline Dukaten (A 20, B 30) und LeP
// (A −5, B −7), A gleicht zuerst ab, bei B entsteht ein Heldenkonflikt mit
// gebundenem Zustand: online 23 LeP, lokal 21 LeP.

const String _id = 'bestand-f01';

/// Journal, dessen Ablegen scheitert.
class _KaputtesJournal extends SpeicherVorgangsjournal {
  @override
  Future<void> merke(String vorgangId, Map<String, Object?> eintrag) {
    throw const SyncNetworkException('Journal nicht schreibbar');
  }
}

void main() {
  late GeteilteCloud cloud;
  late SyncTestGeraet a;
  late SyncTestGeraet b;
  late int lokaleLep;
  late int onlineLep;

  Future<void> bereiteKonfliktVor() async {
    cloud = GeteilteCloud();
    a = SyncTestGeraet(cloud);
    b = SyncTestGeraet(cloud);
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    await a.repo.saveHero(bundle.hero);
    await a.repo.saveHeroState(_id, bundle.state);
    await a.repo.warteAufUebertragungen();
    await a.repo.syncNow();
    await b.repo.syncNow();
    for (final geraet in [a, b]) {
      geraet.remote.offline = true;
      final held = (await geraet.lokal.loadHeroById(_id))!;
      final zustand = (await geraet.lokal.loadHeroState(_id))!;
      final istA = identical(geraet, a);
      await geraet.repo.saveHero(held.copyWith(dukaten: istA ? '20' : '30'));
      await geraet.repo.saveHeroState(
        _id,
        zustand.copyWith(currentLep: zustand.currentLep - (istA ? 5 : 7)),
      );
      await geraet.repo.warteAufUebertragungen();
      geraet.remote.offline = false;
    }
    lokaleLep = (await b.lokal.loadHeroState(_id))!.currentLep;
    await a.repo.syncNow();
    onlineLep = (await cloud.loadHeroState(_id))!.state!.currentLep;
    await b.repo.syncNow();
    expect(b.konflikte.single.includesHeroState, isTrue);
  }

  setUp(bereiteKonfliktVor);

  tearDown(() async {
    await a.repo.close();
    await b.repo.close();
  });

  // Entscheidet bei B und fängt Netzfehler ab, wie die Oberfläche sie zeigt.
  Future<void> entscheide(
    SyncResolutionChoice wahl, {
    bool automatisch = false,
  }) async {
    final id = b.konflikte.single.id;
    try {
      if (automatisch) {
        final vorschau = await b.repo.konfliktVorschau(id);
        await b.repo.resolveConflictAutomatisch(id, <String, SyncSeite>{
          for (final feld in vorschau!.felder) feld.schluessel: SyncSeite.lokal,
        });
      } else {
        await b.repo.resolveConflict(id, wahl);
      }
    } on SyncNetworkException {
      // Abbruch mitten in der Entscheidung.
    }
  }

  Future<List<String>> heldenIds() async {
    return [for (final h in await b.lokal.listHeroes()) h.id]..sort();
  }

  group('Abbruch an jeder Stelle: Neustart setzt die Entscheidung fort', () {
    for (final abbruchNach in [0, 1, 2, 3]) {
      test(
        'Nur Lokal, Leitung bricht nach $abbruchNach Schreibvorgängen ab',
        () async {
          b.remote.schreibvorgaengeBisAbbruch = abbruchNach;
          await entscheide(SyncResolutionChoice.keepLocal);
          b.remote.schreibvorgaengeBisAbbruch = null;
          await b.neustart();
          await b.repo.syncNow();

          expect((await b.lokal.loadHeroById(_id))!.dukaten, '30');
          expect((await b.lokal.loadHeroState(_id))!.currentLep, lokaleLep);
          expect((await cloud.loadHero(_id))!.hero!.dukaten, '30');
          expect(
            (await cloud.loadHeroState(_id))!.state!.currentLep,
            lokaleLep,
          );
          expect(b.konflikte, isEmpty);
          expect(await b.journal.offene(), isEmpty);
          expect(b.repo.currentStatus.ausstehendeVorgaenge, 0);
          expect(b.repo.currentStatus.lastSuccessfulSync, isNotNull);
        },
      );

      test(
        'Beide behalten, Leitung bricht nach $abbruchNach Schreibvorgängen ab',
        () async {
          b.remote.schreibvorgaengeBisAbbruch = abbruchNach;
          await entscheide(SyncResolutionChoice.keepBoth);
          b.remote.schreibvorgaengeBisAbbruch = null;
          await b.neustart();
          await b.repo.syncNow();

          final ids = await heldenIds();
          expect(ids, hasLength(2));
          final kopie = ids.firstWhere((id) => id != _id);
          // Original trägt die Online-Fassung, die Kopie die lokale samt Zustand.
          expect((await b.lokal.loadHeroById(_id))!.dukaten, '20');
          expect((await b.lokal.loadHeroState(_id))!.currentLep, onlineLep);
          expect((await b.lokal.loadHeroById(kopie))!.dukaten, '30');
          expect((await b.lokal.loadHeroState(kopie))!.currentLep, lokaleLep);
          expect((await cloud.loadHero(kopie))!.hero!.dukaten, '30');
          expect(
            (await cloud.loadHeroState(kopie))!.state!.currentLep,
            lokaleLep,
          );
          expect(b.konflikte, isEmpty);
          expect(await b.journal.offene(), isEmpty);
        },
      );

      test(
        'Nur Online, Leitung bricht nach $abbruchNach Schreibvorgängen ab',
        () async {
          b.remote.schreibvorgaengeBisAbbruch = abbruchNach;
          await entscheide(SyncResolutionChoice.keepRemote);
          b.remote.schreibvorgaengeBisAbbruch = null;
          await b.neustart();
          await b.repo.syncNow();

          expect((await b.lokal.loadHeroById(_id))!.dukaten, '20');
          expect((await b.lokal.loadHeroState(_id))!.currentLep, onlineLep);
          expect(await heldenIds(), [_id]);
          expect(b.konflikte, isEmpty);
          expect(await b.journal.offene(), isEmpty);
        },
      );

      test(
        'Automatisch, Leitung bricht nach $abbruchNach Schreibvorgängen ab',
        () async {
          b.remote.schreibvorgaengeBisAbbruch = abbruchNach;
          await entscheide(SyncResolutionChoice.keepLocal, automatisch: true);
          b.remote.schreibvorgaengeBisAbbruch = null;
          await b.neustart();
          await b.repo.syncNow();

          // Zähler einmal verrechnet: 28 − 5 − 7.
          const zusammen = 16;
          expect((await b.lokal.loadHeroById(_id))!.dukaten, '30');
          expect((await b.lokal.loadHeroState(_id))!.currentLep, zusammen);
          expect((await cloud.loadHeroState(_id))!.state!.currentLep, zusammen);
          expect(b.konflikte, isEmpty);
          expect(await b.journal.offene(), isEmpty);

          // Auch das andere Gerät sieht die Zusammenführung genau einmal.
          await a.repo.syncNow();
          expect((await a.lokal.loadHeroState(_id))!.currentLep, zusammen);
        },
      );
    }
  });

  group('Verlorene Antwort und Wiederholung', () {
    test(
      'verlorene Antwort des Bogens schreibt ihn nicht ein zweites Mal',
      () async {
        final heldVorher = cloud.heldSchreibvorgaenge[_id]!;
        final zustandVorher = cloud.zustandSchreibvorgaenge[_id]!;
        b.remote.naechsteAntwortVerlieren = true;
        await entscheide(SyncResolutionChoice.keepLocal);
        await b.neustart();
        await b.repo.syncNow();

        expect(cloud.heldSchreibvorgaenge[_id], heldVorher + 1);
        expect(cloud.zustandSchreibvorgaenge[_id], zustandVorher + 1);
        expect((await b.lokal.loadHeroState(_id))!.currentLep, lokaleLep);
        expect(await b.journal.offene(), isEmpty);
      },
    );

    test('verlorene Antwort der Kopie legt keine zweite Kopie an', () async {
      // Erster Schreibvorgang der Entscheidung ist der Upload der Kopie.
      b.remote.naechsteAntwortVerlieren = true;
      await entscheide(SyncResolutionChoice.keepBoth);
      final erste = await heldenIds();
      expect(erste, hasLength(2));
      await b.neustart();
      await b.repo.syncNow();

      expect(await heldenIds(), erste);
      expect(
        (await cloud.loadAllHeroes()).where((h) => !h.isDeleted),
        hasLength(2),
      );
    });

    test(
      'Doppelklick verwendet denselben Vorgang und dieselbe Kopie',
      () async {
        final id = b.konflikte.single.id;
        await Future.wait([
          b.repo.resolveConflict(id, SyncResolutionChoice.keepBoth),
          b.repo.resolveConflict(id, SyncResolutionChoice.keepBoth),
        ]);
        expect(await heldenIds(), hasLength(2));
        expect(b.konflikte, isEmpty);
        expect(await b.journal.offene(), isEmpty);
      },
    );

    test('Wiederholung nach Netzfehler behält die Kopie-ID', () async {
      b.remote.schreibvorgaengeBisAbbruch = 0;
      await entscheide(SyncResolutionChoice.keepBoth);
      final erste = await heldenIds();
      final schreibvorgaenge = cloud.schreibvorgaenge;
      b.remote.schreibvorgaengeBisAbbruch = null;
      // Dieselbe Karte, derselbe Knopf, ohne Neustart.
      await b.repo.resolveConflict(
        b.konflikte.single.id,
        SyncResolutionChoice.keepBoth,
      );
      expect(await heldenIds(), erste);
      expect(cloud.schreibvorgaenge, schreibvorgaenge + 2);
      expect(b.konflikte, isEmpty);
    });
  });

  group('Sperre und Sichtbarkeit offener Vorgänge', () {
    test(
      'ohne Netz bleibt der Vorgang sichtbar und der Start lokal möglich',
      () async {
        b.remote.schreibvorgaengeBisAbbruch = 1;
        await entscheide(SyncResolutionChoice.keepLocal);
        b.remote.schreibvorgaengeBisAbbruch = null;
        await b.neustart();
        b.remote.offline = true;
        await b.repo.syncNow();

        expect(await b.journal.offene(), hasLength(1));
        expect(b.repo.currentStatus.ausstehendeVorgaenge, 1);
        expect(b.repo.currentStatus.lastSuccessfulSync, isNull);
        expect(b.repo.currentStatus.lastFailure, isNotNull);
        expect((await b.lokal.loadHeroState(_id))!.currentLep, lokaleLep);

        b.remote.offline = false;
        await b.repo.syncNow();
        expect(await b.journal.offene(), isEmpty);
        expect(b.repo.currentStatus.ausstehendeVorgaenge, 0);
        expect((await cloud.loadHeroState(_id))!.state!.currentLep, lokaleLep);
      },
    );

    test(
      'Zustandsklicks und syncNow übertragen gesperrte Helden nicht',
      () async {
        b.remote.schreibvorgaengeBisAbbruch = 1;
        await entscheide(SyncResolutionChoice.keepLocal);
        b.remote.schreibvorgaengeBisAbbruch = null;
        await b.neustart();
        // Der Vorgang ist noch offen (gelesen, aber nicht ausgeführt).
        await b.repo.warteAufUebertragungen();
        final vorher = cloud.schreibvorgaenge;
        final zustand = (await b.lokal.loadHeroState(_id))!;
        await b.repo.saveHeroState(
          _id,
          zustand.copyWith(currentLep: zustand.currentLep - 1),
        );
        await b.repo.warteAufUebertragungen();
        expect(cloud.schreibvorgaenge, vorher);
        expect(
          (await b.lokal.loadHeroState(_id))!.currentLep,
          lokaleLep - 1,
          reason: 'Lokal wird weiter gespeichert',
        );
      },
    );
  });

  group('Neue Änderungen während eines offenen Vorgangs', () {
    test(
      'neue Online-Änderung: kein Überschreiben, Konflikt mit Hinweis',
      () async {
        b.remote.schreibvorgaengeBisAbbruch = 1;
        await entscheide(SyncResolutionChoice.keepLocal);
        b.remote.schreibvorgaengeBisAbbruch = null;

        // Gerät A ändert den Zustand online, während B noch offen ist.
        final zustand = (await a.lokal.loadHeroState(_id))!;
        await a.repo.saveHeroState(_id, zustand.copyWith(currentLep: 3));
        await a.repo.warteAufUebertragungen();
        await a.repo.syncNow();
        final onlineVorher = (await cloud.loadHeroState(_id))!.revision;

        await b.neustart();
        await b.repo.syncNow();

        // Online wurde nicht blind überschrieben.
        expect((await cloud.loadHeroState(_id))!.revision, onlineVorher);
        expect((await cloud.loadHeroState(_id))!.state!.currentLep, 3);
        expect((await b.lokal.loadHeroState(_id))!.currentLep, lokaleLep);
        final konflikt = b.konflikte.single;
        expect(konflikt.hinweis, contains('Nur Lokal'));
        expect(await b.journal.offene(), hasLength(1));

        // Der Nutzer entscheidet erneut: jetzt vollständig und endgültig.
        await b.repo.resolveConflict(
          konflikt.id,
          SyncResolutionChoice.keepLocal,
        );
        expect(b.konflikte, isEmpty);
        expect(await b.journal.offene(), isEmpty);
        expect((await cloud.loadHeroState(_id))!.state!.currentLep, lokaleLep);
      },
    );

    test(
      'Online-Änderung vor der Entscheidung stellt den Konflikt neu',
      () async {
        final zustand = (await a.lokal.loadHeroState(_id))!;
        await a.repo.saveHeroState(_id, zustand.copyWith(currentLep: 4));
        await a.repo.warteAufUebertragungen();
        final schreibvorgaenge = cloud.schreibvorgaenge;

        await b.repo.resolveConflict(
          b.konflikte.single.id,
          SyncResolutionChoice.keepLocal,
        );

        expect(cloud.schreibvorgaenge, schreibvorgaenge);
        expect(await b.journal.offene(), isEmpty);
        expect(b.konflikte, isNotEmpty);
        expect(b.repo.currentStatus.lastFailure?.kind, SyncErrorKind.conflict);
      },
    );

    test(
      'lokale Änderung vor dem lokalen Schritt wird nie überschrieben',
      () async {
        b.remote.schreibvorgaengeBisAbbruch = 1;
        await entscheide(SyncResolutionChoice.keepLocal, automatisch: true);
        b.remote.schreibvorgaengeBisAbbruch = null;

        // Der Nutzer spielt weiter; der Zustand ist im Plan noch zu schreiben.
        final zustand = (await b.lokal.loadHeroState(_id))!;
        await b.repo.saveHeroState(_id, zustand.copyWith(currentLep: 5));
        await b.repo.warteAufUebertragungen();

        await b.neustart();
        await b.repo.syncNow();

        expect((await b.lokal.loadHeroState(_id))!.currentLep, 5);
        expect(b.konflikte.single.hinweis, contains('lokal'));
        expect(await b.journal.offene(), hasLength(1));
      },
    );
  });

  group('Journal', () {
    test(
      'ist das Journal nicht schreibbar, beginnt kein Dokumentzugriff',
      () async {
        await b.neustartMitJournal(_KaputtesJournal());
        await b.repo.syncNow();
        final schreibvorgaenge = cloud.schreibvorgaenge;
        final lokalVorher = await b.heldHash(_id);

        await expectLater(
          b.repo.resolveConflict(
            b.konflikte.single.id,
            SyncResolutionChoice.keepBoth,
          ),
          throwsA(isA<SyncNetworkException>()),
        );

        expect(cloud.schreibvorgaenge, schreibvorgaenge);
        expect(await b.heldHash(_id), lokalVorher);
        expect(await heldenIds(), [_id]);
      },
    );

    test(
      'ein unbekanntes Format bleibt unangetastet und sperrt seinen Helden',
      () async {
        await b.journal.merke('syncKonflikt-$_id', <String, Object?>{
          'art': 'syncKonflikt',
          'version': 99,
          'kontoId': 'konto-1',
          'originalId': _id,
          'zukunft': <String, Object?>{'x': 1},
        });
        await b.neustart();
        final vorher = cloud.schreibvorgaenge;
        await b.repo.syncNow();

        expect((await b.journal.offene())['syncKonflikt-$_id']!['version'], 99);
        expect(b.repo.currentStatus.ausstehendeVorgaenge, 1);
        expect(b.repo.currentStatus.lastSuccessfulSync, isNull);
        expect(cloud.schreibvorgaenge, vorher);
      },
    );

    test(
      'ein nicht bestimmbarer Eintrag sperrt den schreibenden Sync',
      () async {
        await b.journal.merke('kaputt', <String, Object?>{
          'art': '_beschaedigt',
        });
        await b.neustart();
        final vorher = cloud.schreibvorgaenge;
        final held = (await b.lokal.loadHeroById(_id))!;
        await b.repo.saveHero(held.copyWith(dukaten: '99'));
        await b.repo.syncNow();

        expect(cloud.schreibvorgaenge, vorher);
        expect((await b.lokal.loadHeroById(_id))!.dukaten, '99');
        expect((await b.journal.offene()).keys, contains('kaputt'));
      },
    );

    test(
      'echte Hive-Box: der Vorgang überlebt Schließen und Wiederöffnen',
      () async {
        final pfad = await hiveTempVerzeichnis('arch06_konflikt_');
        var journal = await HiveVorgangsjournal.create(storagePath: pfad);
        await b.neustartMitJournal(journal);
        await b.repo.syncNow();
        b.remote.schreibvorgaengeBisAbbruch = 1;
        await entscheide(SyncResolutionChoice.keepBoth);
        b.remote.schreibvorgaengeBisAbbruch = null;
        final ids = await heldenIds();
        await journal.close();

        journal = await HiveVorgangsjournal.create(storagePath: pfad);
        addTearDown(journal.close);
        final offen = await journal.offene();
        expect(offen.keys, ['syncKonflikt-$_id']);
        final gelesen = SyncKonfliktVorgang.lies(
          'syncKonflikt-$_id',
          offen.values.single,
          kontoId: 'konto-1',
        );
        expect(gelesen, isA<SyncKonfliktGueltig>());
        final vorgang = (gelesen! as SyncKonfliktGueltig).vorgang;
        expect(vorgang.kopieId, ids.firstWhere((id) => id != _id));

        await b.neustartMitJournal(journal);
        await b.repo.syncNow();

        expect(await heldenIds(), ids);
        expect(await journal.offene(), isEmpty);
        final kopie = ids.firstWhere((id) => id != _id);
        expect((await b.lokal.loadHeroState(kopie))!.currentLep, lokaleLep);
        expect(
          (await cloud.loadHeroState(kopie))!.state!.currentLep,
          lokaleLep,
        );
      },
    );
  });

  group('Fehlendes Online-Zustandsdokument', () {
    // Der Held liegt online, sein Zustand nur lokal bei B.
    Future<SyncTestGeraet> aufbau(GeteilteCloud wolke) async {
      final gA = SyncTestGeraet(wolke);
      final gB = SyncTestGeraet(wolke);
      addTearDown(gA.repo.close);
      addTearDown(gB.repo.close);
      final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
      await gA.repo.saveHero(bundle.hero);
      await gA.repo.syncNow();
      await gB.repo.syncNow();
      await gB.lokal.saveHeroState(_id, bundle.state);
      for (final g in [gA, gB]) {
        g.remote.offline = true;
        final held = (await g.lokal.loadHeroById(_id))!;
        await g.repo.saveHero(
          held.copyWith(dukaten: identical(g, gA) ? '20' : '30'),
        );
        g.remote.offline = false;
      }
      await gA.repo.syncNow();
      await gB.repo.syncNow();
      expect(gB.konflikte, hasLength(1));
      return gB;
    }

    test('Nur Online lässt den lokalen Zustand stehen', () async {
      final wolke = GeteilteCloud();
      final gB = await aufbau(wolke);
      final zustand = (await gB.lokal.loadHeroState(_id))!;

      await gB.repo.resolveConflict(
        gB.konflikte.single.id,
        SyncResolutionChoice.keepRemote,
      );

      expect((await gB.lokal.loadHeroById(_id))!.dukaten, '20');
      expect(
        (await gB.lokal.loadHeroState(_id))!.currentLep,
        zustand.currentLep,
      );
      expect(await gB.journal.offene(), isEmpty);
    });

    test('Nur Lokal legt den Zustand online neu an', () async {
      final wolke = GeteilteCloud();
      final gB = await aufbau(wolke);
      final zustand = (await gB.lokal.loadHeroState(_id))!;

      await gB.repo.resolveConflict(
        gB.konflikte.single.id,
        SyncResolutionChoice.keepLocal,
      );

      expect((await wolke.loadHero(_id))!.hero!.dukaten, '30');
      expect(
        (await wolke.loadHeroState(_id))!.state!.currentLep,
        zustand.currentLep,
      );
      expect(await gB.journal.offene(), isEmpty);
    });
  });
}
