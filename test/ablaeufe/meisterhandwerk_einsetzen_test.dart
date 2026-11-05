import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/meisterhandwerk_einsetzen.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meisterhandwerk_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

final _jetzt = DateTime.utc(2026, 11, 2, 20);

HeroState _zustand({int asp = 10, int erschoepfung = 0}) => HeroState(
  currentLep: 30,
  currentAsp: asp,
  currentKap: 0,
  currentAu: 30,
  erschoepfung: erschoepfung,
);

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

MeisterhandwerkEinsetzen _ablauf(FakeRepository repo) =>
    MeisterhandwerkEinsetzen(repository: repo, uhr: () => _jetzt);

const _buchung = MeisterhandwerkBuchung(
  talent: 'Singen',
  asp: 6,
  erschoepfung: 2,
  beschreibung: 'TaP* +4: 6 AsP, 2 Erschöpfung',
);

void main() {
  test(
    'bucht AsP, Erschöpfung und Protokoll in einem Speichervorgang',
    () async {
      final repo = _ZaehlendesRepo(_zustand(asp: 10, erschoepfung: 1));

      await _ablauf(repo).buche(heroId: 'held', buchung: _buchung);

      final gespeichert = (await repo.loadHeroState('held'))!;
      expect(gespeichert.currentAsp, 4);
      expect(gespeichert.erschoepfung, 3);
      expect(repo.speichervorgaenge, 1, reason: 'genau ein Dokument');
      final eintrag = gespeichert.diceLog.single;
      expect(eintrag.title, 'Meisterhandwerk: Singen');
      expect(eintrag.subtitle, 'TaP* +4: 6 AsP, 2 Erschöpfung');
      expect(eintrag.type, ProbeType.genericRoll);
      expect(eintrag.isNeutral, isTrue);
      expect(eintrag.timestamp, _jetzt);
    },
  );

  test('rechnet vom gespeicherten Zustand und erhält andere Felder', () async {
    final repo = _ZaehlendesRepo(
      HeroState(
        currentLep: 17,
        currentAsp: 8,
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

    await _ablauf(repo).buche(
      heroId: 'held',
      buchung: const MeisterhandwerkBuchung(
        talent: 'Singen',
        asp: 3,
        beschreibung: '3 AsP vorab (+6 TaW)',
      ),
    );

    final gespeichert = (await repo.loadHeroState('held'))!;
    expect(gespeichert.currentLep, 17);
    expect(gespeichert.currentAsp, 5);
    expect(gespeichert.erschoepfung, 0);
    expect(gespeichert.diceLog.map((e) => e.title), <String>[
      'Früher',
      'Meisterhandwerk: Singen',
    ]);
  });

  test('wirft ohne genug AsP und schreibt nichts', () async {
    final repo = _ZaehlendesRepo(_zustand(asp: 5));

    await expectLater(
      _ablauf(repo).buche(heroId: 'held', buchung: _buchung),
      throwsA(isA<StateError>()),
    );

    expect(repo.speichervorgaenge, 0);
    expect((await repo.loadHeroState('held'))!.currentAsp, 5);
  });
}
