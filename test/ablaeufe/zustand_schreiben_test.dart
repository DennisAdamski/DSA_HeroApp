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
  _Repository({this.ladeFehler = false, this.schreibFehler = false});

  final bool ladeFehler;
  final bool schreibFehler;
  int schreibversuche = 0;

  @override
  Future<HeroState?> loadHeroState(String heroId) async {
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
