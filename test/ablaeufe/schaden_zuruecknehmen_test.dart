import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/schaden_erhalten.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/schaden_protokoll.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/schaden_zuruecknehmen.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

final _treffer = DateTime.utc(2026, 10, 7, 12);
final _jetzt = DateTime.utc(2026, 10, 7, 13);

const _startzustand = HeroState(
  currentLep: 30,
  currentAsp: 12,
  currentKap: 0,
  currentAu: 25,
);

/// Zählt die Speichervorgänge des Zustands.
class _Repo extends FakeRepository {
  _Repo() : super(states: {'held': _startzustand});

  int speichervorgaenge = 0;
  Object? fehler;

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    final f = fehler;
    if (f != null) {
      throw f;
    }
    speichervorgaenge++;
    await super.saveHeroState(heroId, state);
  }
}

SchadensBuchung _brusttreffer() => SchadensBuchung(
  art: SchadensArt.lebensenergie,
  tp: 14,
  rs: 3,
  zone: WundZone.brust,
  wunden: 1,
);

Future<_Repo> _getroffen() async {
  final repo = _Repo();
  await SchadenErhalten(
    repository: repo,
    uhr: () => _treffer,
  ).uebernehmeSchaden(
    heroId: 'held',
    buchung: _brusttreffer(),
    vorgangId: 'treffer',
  );
  repo.speichervorgaenge = 0;
  return repo;
}

SchadenZuruecknehmen _ablauf(FakeRepository repo) =>
    SchadenZuruecknehmen(repository: repo, uhr: () => _jetzt);

void main() {
  test('nimmt den Treffer zurück und protokolliert die Rücknahme', () async {
    final repo = await _getroffen();

    final plan = await _ablauf(repo)
        .nimmZurueck(heroId: 'held', buchungId: 'treffer', vorgangId: 'gegen');

    expect(plan!.lepPlus, 11);
    final zustand = (await repo.loadHeroState('held'))!;
    expect(zustand.currentLep, 30);
    expect(zustand.wpiZustand.wundenInZone(WundZone.brust), 0);
    expect(zustand.lastModified, _jetzt);
    final gegen = zustand.buchungen.last;
    expect(gegen.art, ZustandsBuchungsArt.schadenRuecknahme);
    expect(gegen.ruecknahmeVon, 'treffer');
    final eintrag = zustand.diceLog.last;
    expect(eintrag.title, schadenRuecknahmeProtokollTitel);
    expect(eintrag.type, ProbeType.damage);
    expect(eintrag.buchungId, 'gegen');
    expect(eintrag.subtitle, '+11 LeP · 1 Wunde Brust entfernt');
    // Der ursprüngliche Eintrag bleibt im Verlauf.
    expect(zustand.diceLog.first.title, schadenProtokollTitel);
    expect(zustand.buchungen.first.id, 'treffer');
  });

  test('eine zweite Rücknahme scheitert und ändert nichts', () async {
    final repo = await _getroffen();
    await _ablauf(repo)
        .nimmZurueck(heroId: 'held', buchungId: 'treffer', vorgangId: 'gegen');
    final vorher = (await repo.loadHeroState('held'))!.toJson();

    await expectLater(
      _ablauf(
        repo,
      ).nimmZurueck(heroId: 'held', buchungId: 'treffer', vorgangId: 'nochmal'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'Meldung',
          contains('bereits zurückgenommen'),
        ),
      ),
    );
    expect((await repo.loadHeroState('held'))!.toJson(), vorher);
  });

  test('zwei gleichzeitige Rücknahmen buchen genau eine', () async {
    final repo = await _getroffen();

    final ergebnisse = await Future.wait(<Future<Object?>>[
      _ablauf(repo)
          .nimmZurueck(heroId: 'held', buchungId: 'treffer', vorgangId: 'a')
          .then<Object?>((plan) => plan, onError: (Object e) => e),
      _ablauf(repo)
          .nimmZurueck(heroId: 'held', buchungId: 'treffer', vorgangId: 'b')
          .then<Object?>((plan) => plan, onError: (Object e) => e),
    ]);

    expect(ergebnisse.whereType<StateError>(), hasLength(1));
    final zustand = (await repo.loadHeroState('held'))!;
    expect(zustand.currentLep, 30);
    expect(
      zustand.buchungen.where(
        (b) => b.art == ZustandsBuchungsArt.schadenRuecknahme,
      ),
      hasLength(1),
    );
  });

  test('dieselbe Vorgangs-ID nimmt nicht ein zweites Mal zurück', () async {
    final repo = await _getroffen();
    await _ablauf(repo)
        .nimmZurueck(heroId: 'held', buchungId: 'treffer', vorgangId: 'gegen');
    repo.speichervorgaenge = 0;

    final wiederholt = await _ablauf(repo)
        .nimmZurueck(heroId: 'held', buchungId: 'treffer', vorgangId: 'gegen');

    expect(wiederholt, isNull);
    expect(repo.speichervorgaenge, 0);
    expect((await repo.loadHeroState('held'))!.currentLep, 30);
  });

  test('zwischenzeitlich Gespeichertes bleibt erhalten', () async {
    final repo = await _getroffen();
    final getroffen = (await repo.loadHeroState('held'))!;
    await repo.saveHeroState(
      'held',
      getroffen.copyWith(currentLep: 25, currentAsp: 4),
    );

    await _ablauf(repo)
        .nimmZurueck(heroId: 'held', buchungId: 'treffer', vorgangId: 'gegen');

    final zustand = (await repo.loadHeroState('held'))!;
    expect(zustand.currentLep, 36);
    expect(zustand.currentAsp, 4);
  });

  test('Speicherfehler werden durchgereicht', () async {
    final repo = await _getroffen();
    repo.fehler = StateError('Speicher voll');

    await expectLater(
      _ablauf(
        repo,
      ).nimmZurueck(heroId: 'held', buchungId: 'treffer', vorgangId: 'gegen'),
      throwsA(isA<StateError>()),
    );
    repo.fehler = null;
    expect((await repo.loadHeroState('held'))!.buchungen, hasLength(1));
  });
}
