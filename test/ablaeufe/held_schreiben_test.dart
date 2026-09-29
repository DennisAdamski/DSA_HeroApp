import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

const _held = HeroSheet(
  id: 'held',
  name: 'Rondra',
  level: 1,
  apTotal: 100,
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
);

/// Speichert unverändert und gibt den Stand zurück, wie `HeroActions` den
/// normalisierten Helden.
BogenSpeichern _speichereIn(FakeRepository repo) {
  return (held) async {
    await repo.saveHero(held);
    return held;
  };
}

void main() {
  test('arbeitet auf dem frisch geladenen Helden', () async {
    final repo = FakeRepository(heroes: [_held]);
    // Ein anderer Schreibweg ändert den Helden nach dem UI-Aufbau.
    await repo.saveHero(_held.copyWith(name: 'Rondra die Kühne'));

    await aendereGespeichertenHelden(
      repository: repo,
      heroId: 'held',
      aenderung: (held) => held.copyWith(apTotal: held.apTotal + 10),
      speichere: _speichereIn(repo),
    );

    final gespeichert = await repo.loadHeroById('held');
    expect(gespeichert!.apTotal, 110);
    expect(gespeichert.name, 'Rondra die Kühne');
  });

  test('liefert, was die Speicherung zurückgibt', () async {
    final repo = FakeRepository(heroes: [_held]);

    final ergebnis = await aendereGespeichertenHelden(
      repository: repo,
      heroId: 'held',
      aenderung: (held) => held.copyWith(apTotal: 120),
      speichere: (held) async {
        final normalisiert = held.copyWith(apAvailable: 120);
        await repo.saveHero(normalisiert);
        return normalisiert;
      },
    );

    expect(ergebnis.apAvailable, 120);
    expect((await repo.loadHeroById('held'))!.apAvailable, 120);
  });

  test('ein fehlender Held wird gemeldet, gespeichert wird nichts', () async {
    final repo = FakeRepository();
    var gespeichert = 0;

    await expectLater(
      aendereGespeichertenHelden(
        repository: repo,
        heroId: 'fehlt',
        aenderung: (held) => held,
        speichere: (held) async {
          gespeichert++;
          return held;
        },
      ),
      throwsStateError,
    );
    expect(gespeichert, 0);
  });

  test('dasselbe Objekt zurück heißt: nichts speichern', () async {
    final repo = FakeRepository(heroes: [_held]);
    var gespeichert = 0;

    final ergebnis = await aendereGespeichertenHelden(
      repository: repo,
      heroId: 'held',
      aenderung: (held) => held,
      speichere: (held) async {
        gespeichert++;
        return held;
      },
    );

    expect(gespeichert, 0);
    expect(ergebnis.id, 'held');
  });

  test(
    'gleichzeitige Änderungen desselben Helden laufen nacheinander',
    () async {
      final repo = FakeRepository(heroes: [_held]);

      // Zwei nicht abgewartete Schritte, etwa zwei schnelle Klicks auf „+“:
      // ohne Reihenfolge läse der zweite vor dem Speichern des ersten.
      final erste = aendereGespeichertenHelden(
        repository: repo,
        heroId: 'held',
        aenderung: (held) => held.copyWith(apTotal: held.apTotal + 10),
        speichere: _speichereIn(repo),
      );
      final zweite = aendereGespeichertenHelden(
        repository: repo,
        heroId: 'held',
        aenderung: (held) => held.copyWith(apTotal: held.apTotal + 5),
        speichere: _speichereIn(repo),
      );
      await Future.wait([erste, zweite]);

      expect((await repo.loadHeroById('held'))!.apTotal, 115);
    },
  );

  test('ein eingereihter Vorgang wartet auf die laufende Änderung', () async {
    final repo = _Repository(heroes: [_held], haltLaden: {'held'});
    final reihenfolge = <String>[];

    final aenderung = aendereGespeichertenHelden(
      repository: repo,
      heroId: 'held',
      aenderung: (held) {
        reihenfolge.add('Änderung');
        return held.copyWith(apTotal: 150);
      },
      speichere: _speichereIn(repo),
    );
    final vorgang = reiheBogenvorgangEin(
      repository: repo,
      heroId: 'held',
      vorgang: () async => reihenfolge.add('Vorgang'),
    );

    await Future<void>.delayed(Duration.zero);
    expect(reihenfolge, isEmpty);
    repo.gibLadenFrei();
    await Future.wait([aenderung, vorgang]);
    expect(reihenfolge, ['Änderung', 'Vorgang']);
  });

  test('ein Fehler hält die folgenden Änderungen nicht auf', () async {
    final repo = FakeRepository(heroes: [_held]);

    final fehlschlag = aendereGespeichertenHelden(
      repository: repo,
      heroId: 'held',
      aenderung: (_) => throw StateError('Regel'),
      speichere: _speichereIn(repo),
    );
    final danach = aendereGespeichertenHelden(
      repository: repo,
      heroId: 'held',
      aenderung: (held) => held.copyWith(apTotal: 130),
      speichere: _speichereIn(repo),
    );

    await expectLater(fehlschlag, throwsStateError);
    await danach;
    expect((await repo.loadHeroById('held'))!.apTotal, 130);
  });

  test('verschiedene Helden warten nicht aufeinander', () async {
    final repo = _Repository(
      heroes: [_held, _held.copyWith(id: 'b')],
      haltLaden: {'held'},
    );

    final a = aendereGespeichertenHelden(
      repository: repo,
      heroId: 'held',
      aenderung: (held) => held.copyWith(apTotal: 1),
      speichere: _speichereIn(repo),
    );
    await aendereGespeichertenHelden(
      repository: repo,
      heroId: 'b',
      aenderung: (held) => held.copyWith(apTotal: 2),
      speichere: _speichereIn(repo),
    );

    expect((await repo.loadHeroById('b'))!.apTotal, 2);
    repo.gibLadenFrei();
    await a;
    expect((await repo.loadHeroById('held'))!.apTotal, 1);
  });

  test('Bogen und Laufzeitzustand warten nicht aufeinander', () async {
    final repo = _Repository(heroes: [_held], haltLaden: {'held'});

    final bogen = aendereGespeichertenHelden(
      repository: repo,
      heroId: 'held',
      aenderung: (held) => held.copyWith(apTotal: 1),
      speichere: _speichereIn(repo),
    );
    await aendereGespeichertenZustand(
      repository: repo,
      heroId: 'held',
      aenderung: (zustand) => zustand.copyWith(currentLep: 5),
      uhr: () => DateTime.utc(2026, 9, 29),
    );

    expect((await repo.loadHeroState('held'))!.currentLep, 5);
    repo.gibLadenFrei();
    await bogen;
  });

  test('Speicherfehler werden durchgereicht', () async {
    final repo = FakeRepository(heroes: [_held]);

    await expectLater(
      aendereGespeichertenHelden(
        repository: repo,
        heroId: 'held',
        aenderung: (held) => held.copyWith(apTotal: 1),
        speichere: (_) async => throw StateError('Schreibfehler'),
      ),
      throwsStateError,
    );
    expect((await repo.loadHeroById('held'))!.apTotal, 100);
  });
}

/// Repository, dessen Heldenladen für einzelne IDs angehalten werden kann.
class _Repository extends FakeRepository {
  _Repository({super.heroes, this.haltLaden = const <String>{}});

  /// Helden, deren Laden bis [gibLadenFrei] hängt.
  final Set<String> haltLaden;
  final Completer<void> _freigabe = Completer<void>();

  /// Lässt die in [haltLaden] angehaltenen Ladevorgänge weiterlaufen.
  void gibLadenFrei() => _freigabe.complete();

  @override
  Future<HeroSheet?> loadHeroById(String heroId) async {
    if (haltLaden.contains(heroId)) {
      await _freigabe.future;
    }
    return super.loadHeroById(heroId);
  }
}
