import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/auxiliator_einsetzen.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

final _jetzt = DateTime.utc(2026, 10, 11, 20);

const _talisman = ArtefaktDaten(
  art: ArtefaktArt.zaubertalisman,
  zauber: <ArtefaktZauber>[
    ArtefaktZauber(name: 'Ignifaxius', zfpStern: 5, kostenAsp: 9),
  ],
);

HeroState _zustand(int asp) =>
    HeroState(currentLep: 30, currentAsp: asp, currentKap: 0, currentAu: 30);

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

AuxiliatorEinsetzen _ablauf(FakeRepository repo) =>
    AuxiliatorEinsetzen(repository: repo, uhr: () => _jetzt);

AuxiliatorEinsatz _einsatz({
  bool gelungen = true,
  int grundkosten = 9,
  int w3 = 2,
  int bonus = 5,
}) => AuxiliatorEinsatz(
  zauberName: 'Ignifaxius',
  zfpProbe: 6,
  bonus: gelungen ? bonus : 0,
  spruchGelungen: gelungen,
  grundkosten: grundkosten,
  w3: w3,
  ziel: 'Ork',
);

void main() {
  test(
    'bucht Zauberkosten plus 1W3 und protokolliert in einem Dokument',
    () async {
      final repo = _ZaehlendesRepo(_zustand(30));

      final anwendung = await _ablauf(repo).setzeEin(
        heroId: 'held',
        artefaktName: 'Ring',
        daten: _talisman,
        einsatz: _einsatz(),
        wuerfe: const MatrixWuerfe(w20: 5),
      );

      expect(anwendung.einsatz.kosten, 11);
      expect(anwendung.einsatz.zfpGesamt, 11);
      expect(anwendung.stabilitaet.ausgang, MatrixAusgang.ok);
      final gespeichert = (await repo.loadHeroState('held'))!;
      expect(gespeichert.currentAsp, 19);
      expect(repo.speichervorgaenge, 1, reason: 'genau ein Dokument');
      final eintrag = gespeichert.diceLog.single;
      expect(eintrag.title, 'Auxiliator: Ring');
      expect(eintrag.subtitle, contains('Ignifaxius'));
      expect(eintrag.subtitle, contains('ZfP* 6 + 5 = 11'));
      expect(eintrag.subtitle, contains('11 AsP'));
      expect(
        eintrag.subtitle,
        contains('Matrix stabil: W20 5 → ohne Zwischenfall'),
      );
      expect(eintrag.subtitle, contains('Ziel: Ork'));
      expect(eintrag.total, 5);
    },
  );

  test(
    'ohne Zauberkosten (der Aufrufer bucht sie) bleibt nur der W3',
    () async {
      final repo = _ZaehlendesRepo(_zustand(30));

      final anwendung = await _ablauf(repo).setzeEin(
        heroId: 'held',
        artefaktName: 'Ring',
        daten: _talisman,
        einsatz: _einsatz(grundkosten: 0, w3: 3),
        wuerfe: const MatrixWuerfe(w20: 5),
      );

      expect(anwendung.einsatz.kosten, 3);
      expect((await repo.loadHeroState('held'))!.currentAsp, 27);
    },
  );

  test('ein misslungener Spruch: kein Bonus, +2 auf den Ausfallwurf', () async {
    final repo = _ZaehlendesRepo(_zustand(30));

    // stabil 2012: 17–19 gehemmt; 15 + 2 = 17.
    final anwendung = await _ablauf(repo).setzeEin(
      heroId: 'held',
      artefaktName: 'Ring',
      daten: _talisman,
      einsatz: _einsatz(gelungen: false),
      wuerfe: const MatrixWuerfe(w20: 15, w6Hemmung: 3),
    );

    expect(anwendung.einsatz.bonus, 0);
    expect(anwendung.stabilitaet.ausgang, MatrixAusgang.gehemmt);
    expect(anwendung.stabilitaet.hemmungSr, 3);
    final eintrag = (await repo.loadHeroState('held'))!.diceLog.single;
    expect(eintrag.subtitle, contains('Spruch misslungen, kein Bonus'));
    expect(eintrag.subtitle, contains('W20 15 +2 → gehemmt für 3 SR'));
  });

  test(
    'ein Ausfall kann die Matrix beschädigen, geschrieben wird es nicht',
    () async {
      final repo = _ZaehlendesRepo(_zustand(30));

      final anwendung = await _ablauf(repo).setzeEin(
        heroId: 'held',
        artefaktName: 'Ring',
        daten: _talisman,
        einsatz: _einsatz(),
        wuerfe: const MatrixWuerfe(w20: 20),
      );

      expect(anwendung.stabilitaet.ausgang, MatrixAusgang.irreparabel);
      expect(repo.speichervorgaenge, 1);
    },
  );

  test('zu wenig AsP: Fehler, nichts gebucht', () async {
    final repo = _ZaehlendesRepo(_zustand(5));

    await expectLater(
      _ablauf(repo).setzeEin(
        heroId: 'held',
        artefaktName: 'Ring',
        daten: _talisman,
        einsatz: _einsatz(),
        wuerfe: const MatrixWuerfe(w20: 5),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Zu wenig AsP'),
        ),
      ),
    );

    expect((await repo.loadHeroState('held'))!.currentAsp, 5);
    expect(repo.speichervorgaenge, 0);
  });

  test('ein beschädigter Talisman lässt sich nicht einsetzen', () async {
    final repo = _ZaehlendesRepo(_zustand(30));

    await expectLater(
      _ablauf(repo).setzeEin(
        heroId: 'held',
        artefaktName: 'Ring',
        daten: _talisman.copyWith(defekt: true),
        einsatz: _einsatz(),
        wuerfe: const MatrixWuerfe(w20: 5),
      ),
      throwsA(isA<StateError>()),
    );

    expect(repo.speichervorgaenge, 0);
  });

  test('andere Felder des gespeicherten Zustands bleiben erhalten', () async {
    final repo = _ZaehlendesRepo(
      HeroState(
        currentLep: 17,
        currentAsp: 30,
        currentKap: 4,
        currentAu: 22,
        unbekannteFelder: const {'future': 42},
      ),
    );

    await _ablauf(repo).setzeEin(
      heroId: 'held',
      artefaktName: 'Ring',
      daten: _talisman,
      einsatz: _einsatz(),
      wuerfe: const MatrixWuerfe(w20: 5),
    );

    final gespeichert = (await repo.loadHeroState('held'))!;
    expect(gespeichert.currentLep, 17);
    expect(gespeichert.currentKap, 4);
    expect(gespeichert.currentAu, 22);
    expect(gespeichert.unbekannteFelder['future'], 42);
  });
}
