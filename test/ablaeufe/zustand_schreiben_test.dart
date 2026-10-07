import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

final _jetzt = DateTime.utc(2026, 9, 29, 20);

void main() {
  test('mitAenderungszeitpunkt stempelt in UTC', () {
    final lokal = DateTime(2026, 9, 29, 22);

    final gestempelt = mitAenderungszeitpunkt(const HeroState.empty(), lokal);

    expect(gestempelt.lastModified, lokal.toUtc());
    expect(gestempelt.lastModified!.isUtc, isTrue);
  });

  test('arbeitet auf dem frisch geladenen Zustand', () async {
    final repo = FakeRepository(
      states: {'held': const HeroState.empty().copyWith(currentLep: 10)},
    );
    // Ein anderer Schreibweg ändert den Zustand nach dem UI-Aufbau.
    await repo.saveHeroState(
      'held',
      const HeroState.empty().copyWith(currentLep: 10, currentAu: 7),
    );

    final ergebnis = await aendereGespeichertenZustand(
      repository: repo,
      heroId: 'held',
      aenderung: (zustand) => zustand.copyWith(currentLep: 12),
      uhr: () => _jetzt,
    );

    final gespeichert = await repo.loadHeroState('held');
    expect(gespeichert!.currentLep, 12);
    expect(gespeichert.currentAu, 7);
    expect(gespeichert.lastModified, _jetzt);
    expect(ergebnis.toJson(), gespeichert.toJson());
  });

  test('dieselbe Instanz zurück heißt: nichts speichern (ARCH-06)', () async {
    final gespeichert = const HeroState.empty().copyWith(currentLep: 10);
    final repo = FakeRepository(states: {'held': gespeichert});

    final ergebnis = await aendereGespeichertenZustand(
      repository: repo,
      heroId: 'held',
      aenderung: (zustand) => zustand,
      uhr: () => _jetzt,
    );

    expect(identical(ergebnis, gespeichert), isTrue);
    expect((await repo.loadHeroState('held'))!.lastModified, isNull);
  });

  test('ein fehlender Zustand wird auch leer geschrieben', () async {
    final repo = FakeRepository();

    await aendereGespeichertenZustand(
      repository: repo,
      heroId: 'neu',
      aenderung: (zustand) => zustand,
      uhr: () => _jetzt,
    );

    expect((await repo.loadHeroState('neu'))!.lastModified, _jetzt);
  });

  test('ein fehlender Zustand gilt als leer', () async {
    final repo = FakeRepository();

    await aendereGespeichertenZustand(
      repository: repo,
      heroId: 'neu',
      aenderung: (zustand) {
        expect(zustand.toJson(), const HeroState.empty().toJson());
        return zustand.copyWith(currentAu: 3);
      },
      uhr: () => _jetzt,
    );

    expect((await repo.loadHeroState('neu'))!.currentAu, 3);
  });

  test(
    'gleichzeitige Änderungen desselben Helden laufen nacheinander',
    () async {
      final repo = FakeRepository(
        states: {'held': const HeroState.empty().copyWith(currentLep: 10)},
      );

      // Zwei nicht abgewartete Schreibwege, etwa zwei schnell protokollierte
      // Würfe: ohne Reihenfolge läse der zweite vor dem Speichern des ersten.
      final erste = aendereGespeichertenZustand(
        repository: repo,
        heroId: 'held',
        aenderung: (zustand) =>
            zustand.copyWith(currentLep: zustand.currentLep - 3),
        uhr: () => _jetzt,
      );
      final zweite = aendereGespeichertenZustand(
        repository: repo,
        heroId: 'held',
        aenderung: (zustand) => zustand.copyWith(currentAu: 4),
        uhr: () => _jetzt,
      );
      await Future.wait([erste, zweite]);

      final gespeichert = await repo.loadHeroState('held');
      expect(gespeichert!.currentLep, 7);
      expect(gespeichert.currentAu, 4);
    },
  );

  test('ein Fehler hält die folgenden Änderungen nicht auf', () async {
    final repo = FakeRepository(
      states: {'held': const HeroState.empty().copyWith(currentLep: 10)},
    );

    final fehlschlag = aendereGespeichertenZustand(
      repository: repo,
      heroId: 'held',
      aenderung: (_) => throw StateError('Regel'),
      uhr: () => _jetzt,
    );
    final danach = aendereGespeichertenZustand(
      repository: repo,
      heroId: 'held',
      aenderung: (zustand) => zustand.copyWith(currentLep: 11),
      uhr: () => _jetzt,
    );

    await expectLater(fehlschlag, throwsStateError);
    await danach;
    expect((await repo.loadHeroState('held'))!.currentLep, 11);
  });

  test('verschiedene Helden warten nicht aufeinander', () async {
    final repo = _Repository(haltLaden: {'a'});

    final a = aendereGespeichertenZustand(
      repository: repo,
      heroId: 'a',
      aenderung: (zustand) => zustand.copyWith(currentLep: 1),
      uhr: () => _jetzt,
    );
    await aendereGespeichertenZustand(
      repository: repo,
      heroId: 'b',
      aenderung: (zustand) => zustand.copyWith(currentLep: 2),
      uhr: () => _jetzt,
    );

    expect((await repo.loadHeroState('b'))!.currentLep, 2);
    repo.gibLadenFrei();
    await a;
    expect((await repo.loadHeroState('a'))!.currentLep, 1);
  });

  test('Ladefehler werden durchgereicht, gespeichert wird nichts', () async {
    final repo = _Repository(ladeFehler: true);

    await expectLater(
      aendereGespeichertenZustand(
        repository: repo,
        heroId: 'held',
        aenderung: (zustand) => zustand,
        uhr: () => _jetzt,
      ),
      throwsStateError,
    );
    expect(repo.schreibversuche, 0);
  });

  test('Speicherfehler werden durchgereicht', () async {
    final repo = _Repository(schreibFehler: true);

    await expectLater(
      aendereGespeichertenZustand(
        repository: repo,
        heroId: 'held',
        aenderung: (zustand) => zustand.copyWith(currentLep: 1),
        uhr: () => _jetzt,
      ),
      throwsStateError,
    );
    expect(repo.schreibversuche, 1);
  });
}

/// Repository mit schaltbarem Lade- bzw. Schreibfehler.
class _Repository extends FakeRepository {
  _Repository({
    this.ladeFehler = false,
    this.schreibFehler = false,
    this.haltLaden = const <String>{},
  });

  final bool ladeFehler;
  final bool schreibFehler;

  /// Helden, deren Laden bis [gibLadenFrei] hängt.
  final Set<String> haltLaden;
  final Completer<void> _freigabe = Completer<void>();
  int schreibversuche = 0;

  /// Lässt die in [haltLaden] angehaltenen Ladevorgänge weiterlaufen.
  void gibLadenFrei() => _freigabe.complete();

  @override
  Future<HeroState?> loadHeroState(String heroId) async {
    if (haltLaden.contains(heroId)) {
      await _freigabe.future;
    }
    if (ladeFehler) {
      throw StateError('Ladefehler');
    }
    return super.loadHeroState(heroId);
  }

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    schreibversuche++;
    if (schreibFehler) {
      throw StateError('Schreibfehler');
    }
    await super.saveHeroState(heroId, state);
  }
}
