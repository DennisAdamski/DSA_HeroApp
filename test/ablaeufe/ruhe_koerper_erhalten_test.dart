import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/ruhe_koerper_erhalten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_rest_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/hero_fixtures.dart';

final _jetzt = DateTime.utc(2026, 10, 15, 22);

final _start = const HeroState(
  currentLep: 10,
  currentAsp: 5,
  currentKap: 0,
  currentAu: 25,
  erschoepfung: 20,
  ueberanstrengung: 6,
).copyWith(wpiZustand: const WundZustand(wundenProZone: {WundZone.brust: 1}));

const _schlaf = RuheKoerperEingabe(
  zfpStern: 8,
  stunden: 6,
  aspRegeneration: 2,
  geschlosseneWunden: {WundZone.brust: 1},
);

class _ZaehlendesRepo extends FakeRepository {
  _ZaehlendesRepo() : super(states: {'held': _start});

  int speichervorgaenge = 0;

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    speichervorgaenge++;
    await super.saveHeroState(heroId, state);
  }
}

RuheKoerperErhalten _ablauf(FakeRepository repo) =>
    RuheKoerperErhalten(repository: repo, uhr: () => _jetzt);

void main() {
  test(
    'bucht alle Änderungen in einem Dokument mit Buchung und Protokoll',
    () async {
      final repo = _ZaehlendesRepo();

      final a = await _ablauf(repo).uebernehmeSchlaf(
        heroId: 'held',
        eingabe: _schlaf,
        maxLep: 40,
        maxAsp: 20,
        vorgangId: 'r1',
      );

      final z = (await repo.loadHeroState('held'))!;
      expect(a.lep, 12);
      expect(z.currentLep, 22);
      expect(z.currentAsp, 7);
      expect(z.ueberanstrengung, 0);
      expect(z.erschoepfung, 0);
      expect(z.wpiZustand.wundenInZone(WundZone.brust), 0);
      expect(z.buchungen.single.id, 'r1');
      expect(z.diceLog.single.title, ruheKoerperProtokollTitel);
      expect(z.diceLog.single.subtitle, contains('6 Std. Schlaf'));
      expect(repo.speichervorgaenge, 1);
      expectNurGeaendert(_start.toJson(), z.toJson(), {
        'currentLep',
        'currentAsp',
        'erschoepfung',
        'ueberanstrengung',
        'wpiZustand',
        'diceLog',
        'buchungen',
        'lastModified',
      });
    },
  );

  test('dieselbe Vorgangs-ID bucht nichts doppelt', () async {
    final repo = _ZaehlendesRepo();
    final ablauf = _ablauf(repo);
    await ablauf.uebernehmeSchlaf(
      heroId: 'held',
      eingabe: _schlaf,
      maxLep: 40,
      maxAsp: 20,
      vorgangId: 'r1',
    );

    final wiederholt = await ablauf.uebernehmeSchlaf(
      heroId: 'held',
      eingabe: _schlaf,
      maxLep: 40,
      maxAsp: 20,
      vorgangId: 'r1',
    );

    final z = (await repo.loadHeroState('held'))!;
    expect(wiederholt.istWiederholung, isTrue);
    expect(z.currentLep, 22);
    expect(z.buchungen, hasLength(1));
    expect(repo.speichervorgaenge, 1);
  });

  test('eine inzwischen unzulässige Eingabe wird nicht geschrieben', () async {
    // Die Wunde wurde zwischenzeitlich bereits geheilt.
    final repo = FakeRepository(
      states: {'held': _start.copyWith(wpiZustand: const WundZustand())},
    );

    await expectLater(
      _ablauf(repo).uebernehmeSchlaf(
        heroId: 'held',
        eingabe: _schlaf,
        maxLep: 40,
        maxAsp: 20,
        vorgangId: 'r2',
      ),
      throwsA(isA<StateError>()),
    );

    final z = (await repo.loadHeroState('held'))!;
    expect(z.currentLep, 10);
    expect(z.buchungen, isEmpty);
  });
}
