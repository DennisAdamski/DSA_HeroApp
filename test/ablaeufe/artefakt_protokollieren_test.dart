import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/artefakt_protokollieren.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

final _jetzt = DateTime.utc(2026, 10, 11, 20);

/// Zählt die Speichervorgänge des Zustands.
class _ZaehlendesRepo extends FakeRepository {
  _ZaehlendesRepo(HeroState start) : super(states: {'held': start});

  int speichervorgaenge = 0;

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    speichervorgaenge++;
    await super.saveHeroState(heroId, state);
  }
}

const _ladung = ArtefaktLadung(
  id: 'a',
  zauber: <ArtefaktZauber>[
    ArtefaktZauber(name: 'Psychostabilis'),
    ArtefaktZauber(name: 'Illusion auflösen'),
  ],
);

void main() {
  test('hängt genau einen Eintrag an und lässt den Rest unberührt', () async {
    final repo = _ZaehlendesRepo(
      HeroState(currentLep: 17, currentAsp: 20, currentKap: 0, currentAu: 30),
    );

    await ArtefaktProtokollieren(
      repository: repo,
      uhr: () => _jetzt,
    ).protokolliere(
      heroId: 'held',
      baue: (t) => baueSpruchspeicherProtokoll(
        artefaktName: 'Stirnreif',
        zauber: _ladung.zauber,
        vorgang: 'Ladung ausgelöst (1 von 2 frei)',
        ziel: 'Händler',
        zeitpunkt: t,
      ),
    );

    final zustand = (await repo.loadHeroState('held'))!;
    expect(repo.speichervorgaenge, 1, reason: 'genau ein Dokument');
    expect(zustand.currentLep, 17);
    expect(
      zustand.currentAsp,
      20,
      reason: 'ein Spruchspeicher kostet keine AsP',
    );
    final eintrag = zustand.diceLog.single;
    expect(eintrag.title, 'Spruchspeicher: Stirnreif');
    expect(eintrag.subtitle, contains('Psychostabilis + Illusion auflösen'));
    expect(eintrag.subtitle, contains('1 von 2 frei'));
    expect(eintrag.subtitle, contains('Ziel: Händler'));
    expect(eintrag.timestamp, _jetzt);
  });

  test('der Aufladeeintrag nennt Wurf, Schwelle und Ausgang', () {
    final ok = baueAufladeProtokoll(
      artefaktName: 'Stirnreif',
      w20: 7,
      schadenAb: 19,
      beschaedigt: false,
      zeitpunkt: _jetzt,
    );
    final kaputt = baueAufladeProtokoll(
      artefaktName: '',
      w20: 19,
      schadenAb: 19,
      beschaedigt: true,
      zeitpunkt: _jetzt,
    );

    expect(ok.title, 'Aufladen: Stirnreif');
    expect(ok.subtitle, contains('W20 7 (Schaden ab 19)'));
    expect(ok.subtitle, contains('unversehrt'));
    expect(ok.total, 7);
    expect(kaputt.title, 'Aufladen: Artefakt');
    expect(kaputt.subtitle, contains('irreparabel beschädigt'));
  });

  test('ein Fehler beim Speichern erreicht den Aufrufer', () async {
    final repo = _FehlerRepo();

    await expectLater(
      ArtefaktProtokollieren(repository: repo, uhr: () => _jetzt).protokolliere(
        heroId: 'held',
        baue: (t) => baueAufladeProtokoll(
          artefaktName: 'x',
          w20: 1,
          schadenAb: 20,
          beschaedigt: false,
          zeitpunkt: t,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

class _FehlerRepo extends FakeRepository {
  _FehlerRepo()
    : super(
        states: {
          'held': HeroState(
            currentLep: 1,
            currentAsp: 1,
            currentKap: 0,
            currentAu: 1,
          ),
        },
      );

  @override
  Future<void> saveHeroState(String heroId, HeroState state) =>
      throw StateError('Speicher voll');
}
