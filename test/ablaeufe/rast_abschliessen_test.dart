import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/rast_abschliessen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/rast_protokoll.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_outcome_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/hero_fixtures.dart';

final _jetzt = DateTime.utc(2026, 9, 29, 20);

const _eigenschaften = Attributes(
  mu: 12,
  kl: 12,
  inn: 14,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 13,
  kk: 12,
);

const _werte = DerivedStats(
  maxLep: 30,
  maxAu: 32,
  maxAsp: 24,
  maxKap: 6,
  mr: 4,
  iniBase: 10,
  atBase: 7,
  paBase: 7,
  fkBase: 7,
  gs: 8,
  ausweichen: 7,
);

const _startzustand = HeroState(
  currentLep: 10,
  currentAsp: 5,
  currentKap: 2,
  currentAu: 10,
  ueberanstrengung: 2,
  erschoepfung: 4,
);

RestOutcomeInput _schlaf({
  Map<RestRollSlot, int> rolls = const {
    RestRollSlot.auRoll: 9,
    RestRollSlot.auKoProbe: 1,
    RestRollSlot.phase1Lep: 4,
    RestRollSlot.phase1KoProbe: 20,
    RestRollSlot.phase1Asp: 3,
    RestRollSlot.phase1InProbe: 2,
  },
}) {
  return RestOutcomeInput(
    activity: RestActivity.schlaf,
    rolls: rolls,
    effectiveAttributes: _eigenschaften,
    magicEnabled: true,
    maxLep: _werte.maxLep,
    maxAu: _werte.maxAu,
    maxAsp: _werte.maxAsp,
  );
}

RastAbschliessen _ablauf(FakeRepository repo) {
  return RastAbschliessen(repository: repo, uhr: () => _jetzt);
}

DiceLogEntry _fremderEintrag() {
  return diceLogEntryFromRoll(
    title: 'Zwischendurch',
    subtitle: 'anderer Schreibweg',
    diceValues: const <int>[6],
    timestamp: DateTime.utc(2026, 9, 29, 19),
  );
}

void main() {
  group('uebernehmeRast', () {
    test('ersetzt nur Rastwerte, Protokoll und Zeitstempel', () async {
      final repo = FakeRepository(states: {'held': _startzustand});

      await _ablauf(repo).uebernehmeRast(heroId: 'held', eingabe: _schlaf());

      final gespeichert = (await repo.loadHeroState('held'))!;
      // Au 10 + 9 + 6, LeP 10 + 4, AsP 5 + 3 + 1 (IN-Probe).
      expect(gespeichert.currentAu, 25);
      expect(gespeichert.currentLep, 14);
      expect(gespeichert.currentAsp, 9);
      expect(gespeichert.ueberanstrengung, 0);
      expect(gespeichert.erschoepfung, 0);
      expect(gespeichert.lastModified, _jetzt);
      expectNurGeaendert(_startzustand.toJson(), gespeichert.toJson(), {
        'currentLep',
        'currentAu',
        'currentAsp',
        'ueberanstrengung',
        'erschoepfung',
        'diceLog',
        'lastModified',
      });
    });

    test(
      'rechnet auf dem frischen Stand und erhält Zwischenänderungen',
      () async {
        final repo = FakeRepository(states: {'held': _startzustand});
        // Nach dem Öffnen des Dialogs speichern andere Wege Wunde, Protokoll
        // und neue Lebenspunkte.
        await repo.saveHeroState(
          'held',
          _startzustand
              .copyWith(
                currentLep: 20,
                wpiZustand: const WundZustand(
                  wundenProZone: <WundZone, int>{WundZone.brust: 1},
                ),
              )
              .withAppendedDiceLog(_fremderEintrag()),
        );

        final ergebnis = await _ablauf(repo)
            .uebernehmeRast(heroId: 'held', eingabe: _schlaf());

        final gespeichert = (await repo.loadHeroState('held'))!;
        expect(ergebnis.before.currentLep, 20);
        expect(gespeichert.currentLep, 24);
        expect(gespeichert.wpiZustand.wundenInZone(WundZone.brust), 1);
        expect(gespeichert.diceLog.first.title, 'Zwischendurch');
        expect(gespeichert.diceLog, hasLength(7));
      },
    );

    test('protokolliert die geltenden Würfe in fester Reihenfolge', () async {
      final repo = FakeRepository(states: {'held': _startzustand});

      await _ablauf(repo).uebernehmeRast(
        heroId: 'held',
        eingabe: _schlaf(
          rolls: const {
            RestRollSlot.auRoll: 9,
            RestRollSlot.auKoProbe: 1,
            RestRollSlot.phase1Lep: 4,
            RestRollSlot.phase1InProbe: 2,
            // Gilt beim Schlaf nicht und wird nicht protokolliert.
            RestRollSlot.phase2Lep: 6,
          },
        ),
        manuelleWuerfe: const {RestRollSlot.auRoll, RestRollSlot.phase1InProbe},
      );

      final protokoll = (await repo.loadHeroState('held'))!.diceLog;
      expect(protokoll.map((eintrag) => eintrag.title), [
        'Rast: Ausdauerwurf',
        'Rast: KO-Probe (Ausruhen)',
        'Regeneration Phase 1: LeP-Wurf',
        'Regeneration Phase 1: IN-Probe',
      ]);
      expect(protokoll.map((eintrag) => eintrag.subtitle), [
        '3W6 manuell',
        'Zielwert 13',
        '1W6 (Summe)',
        'Zielwert 14, manuell',
      ]);
      expect(
        protokoll.map((eintrag) => eintrag.timestamp),
        everyElement(_jetzt),
      );
      expect(protokoll[0].total, 9);
      expect(protokoll[1].success, isTrue);
    });

    test('hält die Protokollgrenze ein', () async {
      final voll = List<DiceLogEntry>.generate(
        HeroState.diceLogMax,
        (_) => _fremderEintrag(),
      );
      final repo = FakeRepository(
        states: {'held': _startzustand.copyWith(diceLog: voll)},
      );

      await _ablauf(repo).uebernehmeRast(heroId: 'held', eingabe: _schlaf());

      final protokoll = (await repo.loadHeroState('held'))!.diceLog;
      expect(protokoll, hasLength(HeroState.diceLogMax));
      expect(protokoll.last.title, 'Regeneration Phase 1: IN-Probe');
    });

    test('ein fehlender Zustand gilt als leer', () async {
      final repo = FakeRepository();

      final ergebnis = await _ablauf(repo)
          .uebernehmeRast(heroId: 'neu', eingabe: _schlaf());

      expect(ergebnis.before.currentAu, 0);
      expect((await repo.loadHeroState('neu'))!.currentAu, 15);
    });

    test('Speicherfehler werden durchgereicht', () async {
      final repo = _SchreibfehlerRepository();

      await expectLater(
        _ablauf(repo).uebernehmeRast(heroId: 'held', eingabe: _schlaf()),
        throwsStateError,
      );
    });

    test('Protokoll entspricht baueRastProtokoll', () async {
      final repo = FakeRepository(states: {'held': _startzustand});
      final eingabe = _schlaf();

      await _ablauf(repo).uebernehmeRast(heroId: 'held', eingabe: eingabe);

      final erwartet = baueRastProtokoll(eingabe: eingabe, zeitpunkt: _jetzt);
      final gespeichert = (await repo.loadHeroState('held'))!.diceLog;
      expect(
        gespeichert.map((eintrag) => eintrag.toJson()),
        erwartet.map((eintrag) => eintrag.toJson()),
      );
    });
  });

  group('vollstaendigeErholung', () {
    test('setzt Maxima, heilt Wunden und erhält Zwischenänderungen', () async {
      final repo = FakeRepository(
        states: {
          'held': _startzustand
              .copyWith(
                wpiZustand: const WundZustand(
                  wundenProZone: <WundZone, int>{WundZone.kopf: 2},
                  kopfIniMalus: 4,
                ),
              )
              .withAppendedDiceLog(_fremderEintrag()),
        },
      );

      await _ablauf(repo).vollstaendigeErholung(heroId: 'held', werte: _werte);

      final gespeichert = (await repo.loadHeroState('held'))!;
      expect(gespeichert.currentLep, 30);
      expect(gespeichert.currentAu, 32);
      expect(gespeichert.currentAsp, 24);
      expect(gespeichert.currentKap, 6);
      expect(gespeichert.erschoepfung, 0);
      expect(gespeichert.ueberanstrengung, 0);
      expect(gespeichert.wpiZustand.gesamtWunden, 0);
      expect(gespeichert.wpiZustand.kopfIniMalus, 0);
      expect(gespeichert.diceLog.single.title, 'Zwischendurch');
      expect(gespeichert.lastModified, _jetzt);
    });

    test('Speicherfehler werden durchgereicht', () async {
      await expectLater(
        _ablauf(_SchreibfehlerRepository())
            .vollstaendigeErholung(heroId: 'held', werte: _werte),
        throwsStateError,
      );
    });
  });
}

/// Repository, dessen Zustandsschreibweg fehlschlägt.
class _SchreibfehlerRepository extends FakeRepository {
  _SchreibfehlerRepository() : super(states: {'held': _startzustand});

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async =>
      throw StateError('Schreibfehler');
}
