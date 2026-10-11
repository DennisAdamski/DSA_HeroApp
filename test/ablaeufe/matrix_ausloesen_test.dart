import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/matrix_ausloesen.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

final _jetzt = DateTime.utc(2026, 10, 11, 20);

const _daten = ArtefaktDaten(
  zauber: <ArtefaktZauber>[
    ArtefaktZauber(name: 'Gardianum', kostenAsp: 9),
    ArtefaktZauber(name: 'Armatrutz', kostenAsp: 6),
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

MatrixAusloesen _ablauf(FakeRepository repo) =>
    MatrixAusloesen(repository: repo, uhr: () => _jetzt);

void main() {
  test(
    'bucht die Zauberkosten und protokolliert den Stabilitätswurf',
    () async {
      final repo = _ZaehlendesRepo(_zustand(20));

      final anwendung = await _ablauf(repo).loeseAus(
        heroId: 'held',
        artefaktName: 'Armschiene',
        daten: _daten,
        wuerfe: const MatrixWuerfe(w20: 5),
        ziel: 'Thalion',
      );

      expect(anwendung.kosten, 15);
      expect(anwendung.stabilitaet.ausgang, MatrixAusgang.ok);
      final gespeichert = (await repo.loadHeroState('held'))!;
      expect(gespeichert.currentAsp, 5);
      expect(repo.speichervorgaenge, 1, reason: 'genau ein Dokument');
      final eintrag = gespeichert.diceLog.single;
      expect(eintrag.title, 'Matrixgeber: Armschiene');
      expect(eintrag.subtitle, contains('Gardianum + Armatrutz'));
      expect(eintrag.subtitle, contains('15 AsP'));
      expect(eintrag.subtitle, contains('Ziel: Thalion'));
      expect(eintrag.total, 5);
    },
  );

  test('andere Felder des gespeicherten Zustands bleiben erhalten', () async {
    final repo = _ZaehlendesRepo(
      HeroState(
        currentLep: 17,
        currentAsp: 20,
        currentKap: 0,
        currentAu: 30,
        diceLog: <DiceLogEntry>[
          diceLogEntryFromRoll(
            title: 'Früher',
            subtitle: '',
            diceValues: const <int>[3],
          ),
        ],
      ),
    );

    await _ablauf(repo).loeseAus(
      heroId: 'held',
      artefaktName: 'x',
      daten: _daten,
      wuerfe: const MatrixWuerfe(w20: 5),
    );

    final gespeichert = (await repo.loadHeroState('held'))!;
    expect(gespeichert.currentLep, 17);
    expect(gespeichert.diceLog, hasLength(2));
  });

  test('nach Fassung 2011 weichen die Kosten um den W6 ab', () async {
    final repo = _ZaehlendesRepo(_zustand(30));

    final anwendung = await _ablauf(repo).loeseAus(
      heroId: 'held',
      artefaktName: 'x',
      daten: _daten.copyWith(regelfassung: MatrixRegelfassung.staebeRinge2011),
      wuerfe: const MatrixWuerfe(w20: 5, w6Kosten: 4),
    );

    expect(anwendung.kosten, 19);
    expect((await repo.loadHeroState('held'))!.currentAsp, 11);
  });

  test('zu wenig AsP: nichts wird gebucht', () async {
    final repo = _ZaehlendesRepo(_zustand(14));

    await expectLater(
      _ablauf(repo).loeseAus(
        heroId: 'held',
        artefaktName: 'x',
        daten: _daten,
        wuerfe: const MatrixWuerfe(w20: 5),
      ),
      throwsA(isA<StateError>()),
    );

    expect(repo.speichervorgaenge, 0);
    expect((await repo.loadHeroState('held'))!.currentAsp, 14);
  });

  test('ein beschädigtes Artefakt lässt sich nicht auslösen', () async {
    final repo = _ZaehlendesRepo(_zustand(30));

    await expectLater(
      _ablauf(repo).loeseAus(
        heroId: 'held',
        artefaktName: 'x',
        daten: _daten.copyWith(defekt: true),
        wuerfe: const MatrixWuerfe(w20: 5),
      ),
      throwsA(isA<StateError>()),
    );

    expect(repo.speichervorgaenge, 0);
  });

  test(
    'Hemmung und Beschädigung stehen im Ergebnis und im Protokoll',
    () async {
      final repo = _ZaehlendesRepo(_zustand(30));

      final gehemmt = await _ablauf(repo).loeseAus(
        heroId: 'held',
        artefaktName: 'x',
        daten: _daten,
        wuerfe: const MatrixWuerfe(w20: 18, w6Hemmung: 3),
      );
      final defekt = await _ablauf(repo).loeseAus(
        heroId: 'held',
        artefaktName: 'x',
        daten: _daten.copyWith(stabilitaet: MatrixStabilitaet.labil),
        wuerfe: const MatrixWuerfe(w20: 20),
      );

      expect(gehemmt.stabilitaet.ausgang, MatrixAusgang.gehemmt);
      expect(gehemmt.stabilitaet.hemmungSr, 3);
      expect(defekt.stabilitaet.ausgang, MatrixAusgang.irreparabel);
      final log = (await repo.loadHeroState('held'))!.diceLog;
      expect(log.first.subtitle, contains('gehemmt für 3 SR'));
      expect(log.last.subtitle, contains('irreparabel beschädigt'));
    },
  );
}
