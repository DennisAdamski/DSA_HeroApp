import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/schaden_erhalten.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/schaden_protokoll.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/hero_fixtures.dart';

final _jetzt = DateTime.utc(2026, 9, 29, 21);

const _startzustand = HeroState(
  currentLep: 30,
  currentAsp: 12,
  currentKap: 0,
  currentAu: 25,
);

SchadenErhalten _ablauf(FakeRepository repo) {
  return SchadenErhalten(repository: repo, uhr: () => _jetzt);
}

SchadensBuchung _brusttreffer() {
  return SchadensBuchung(
    art: SchadensArt.lebensenergie,
    tp: 14,
    rs: 3,
    zone: WundZone.brust,
    wunden: 1,
    zusatzSchaden: 4,
    angriffsModifikator: -2,
  );
}

DiceLogEntry _fremderEintrag() {
  return diceLogEntryFromRoll(
    title: 'Zwischendurch',
    subtitle: 'anderer Schreibweg',
    diceValues: const <int>[6],
    timestamp: DateTime.utc(2026, 9, 29, 20),
  );
}

void main() {
  test('ersetzt nur LeP, Wunden, Protokoll und Zeitstempel', () async {
    final repo = FakeRepository(states: {'held': _startzustand});

    final anwendung = await _ablauf(repo)
        .uebernehmeSchaden(heroId: 'held', buchung: _brusttreffer());

    final gespeichert = (await repo.loadHeroState('held'))!;
    expect(gespeichert.currentLep, 30 - 11 - 4);
    expect(gespeichert.wpiZustand.wundenInZone(WundZone.brust), 1);
    expect(gespeichert.lastModified, _jetzt);
    expect(anwendung.hinzugefuegteWunden, 1);
    expectNurGeaendert(_startzustand.toJson(), gespeichert.toJson(), {
      'currentLep',
      'wpiZustand',
      'diceLog',
      'lastModified',
    });
  });

  test('protokolliert die Buchung nachvollziehbar', () async {
    final repo = FakeRepository(states: {'held': _startzustand});

    await _ablauf(repo)
        .uebernehmeSchaden(heroId: 'held', buchung: _brusttreffer());

    final eintrag = (await repo.loadHeroState('held'))!.diceLog.single;
    expect(eintrag.title, schadenProtokollTitel);
    expect(
      eintrag.subtitle,
      'TP 14 − RS 3 = 11 SP · Brust · WS −2 · 1 Wunde · +4 SP Zusatz',
    );
    expect(eintrag.type, ProbeType.damage);
    expect(eintrag.total, 15);
    expect(eintrag.diceValues, isEmpty);
    expect(eintrag.timestamp, _jetzt);
  });

  test('Ausdauerschaden senkt AuP und mit der Hälfte die LeP', () async {
    final repo = FakeRepository(states: {'held': _startzustand});

    await _ablauf(repo).uebernehmeSchaden(
      heroId: 'held',
      buchung: SchadensBuchung(art: SchadensArt.ausdauer, tp: 8, rs: 1),
    );

    final gespeichert = (await repo.loadHeroState('held'))!;
    expect(gespeichert.currentAu, 18);
    // 7 SP(A): die Hälfte, kaufmännisch gerundet, trifft die LeP.
    expect(gespeichert.currentLep, 26);
    final eintrag = gespeichert.diceLog.single;
    expect(eintrag.subtitle, 'TP(A) 8 − RS 1 = 7 SP(A) · 4 SP auf LeP');
    expect(eintrag.total, 4);
    expectNurGeaendert(_startzustand.toJson(), gespeichert.toJson(), {
      'currentAu',
      'currentLep',
      'diceLog',
      'lastModified',
    });
  });

  test('Ausdauerschaden kann über die echten SP Wunden schlagen', () async {
    final repo = FakeRepository(states: {'held': _startzustand});

    await _ablauf(repo).uebernehmeSchaden(
      heroId: 'held',
      buchung: SchadensBuchung(
        art: SchadensArt.ausdauer,
        tp: 22,
        rs: 0,
        zone: WundZone.kopf,
        wunden: 1,
        kopfIniWurf: 5,
        angriffsModifikator: 2,
      ),
    );

    final gespeichert = (await repo.loadHeroState('held'))!;
    expect(gespeichert.currentAu, 3);
    expect(gespeichert.currentLep, 19);
    expect(gespeichert.wpiZustand.wundenInZone(WundZone.kopf), 1);
    expect(
      gespeichert.diceLog.single.subtitle,
      'TP(A) 22 − RS 0 = 22 SP(A) · 11 SP auf LeP · Kopf · WS +2 · 1 Wunde · '
      'INI −5',
    );
  });

  test(
    'rechnet auf dem frischen Stand und erhält Zwischenänderungen',
    () async {
      final repo = FakeRepository(states: {'held': _startzustand});
      // Nach dem Öffnen des Dialogs speichern andere Wege LeP, eine
      // Brustwunde und einen Wurf.
      await repo.saveHeroState(
        'held',
        _startzustand
            .copyWith(
              currentLep: 20,
              currentAsp: 7,
              wpiZustand: const WundZustand(
                wundenProZone: <WundZone, int>{WundZone.brust: 2},
              ),
            )
            .withAppendedDiceLog(_fremderEintrag()),
      );

      final anwendung = await _ablauf(repo).uebernehmeSchaden(
        heroId: 'held',
        buchung: SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 20,
          rs: 0,
          zone: WundZone.brust,
          wunden: 2,
        ),
      );

      final gespeichert = (await repo.loadHeroState('held'))!;
      expect(gespeichert.currentLep, 0);
      expect(gespeichert.currentAsp, 7);
      expect(gespeichert.wpiZustand.wundenInZone(WundZone.brust), 3);
      expect(anwendung.hinzugefuegteWunden, 1);
      expect(anwendung.verfalleneWunden, 1);
      expect(gespeichert.diceLog.map((eintrag) => eintrag.title), [
        'Zwischendurch',
        schadenProtokollTitel,
      ]);
      expect(gespeichert.diceLog.last.subtitle, contains('1 Wunde'));
    },
  );

  test('ein fehlender Zustand gilt als leer', () async {
    final repo = FakeRepository();

    await _ablauf(repo).uebernehmeSchaden(
      heroId: 'neu',
      buchung: SchadensBuchung(art: SchadensArt.lebensenergie, tp: 5, rs: 0),
    );

    expect((await repo.loadHeroState('neu'))!.currentLep, -5);
  });

  test('Speicherfehler werden durchgereicht', () async {
    final repo = _SchreibfehlerRepository();

    await expectLater(
      _ablauf(repo).uebernehmeSchaden(heroId: 'held', buchung: _brusttreffer()),
      throwsStateError,
    );
  });
}

/// Repository, dessen Zustandsschreibweg fehlschlägt.
class _SchreibfehlerRepository extends FakeRepository {
  _SchreibfehlerRepository() : super(states: {'held': _startzustand});

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async =>
      throw StateError('Schreibfehler');
}
