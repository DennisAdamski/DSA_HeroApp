import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/heilung_erhalten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_healing_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/hero_fixtures.dart';

final _jetzt = DateTime.utc(2026, 10, 15, 20);

final _start = const HeroState(
  currentLep: 12,
  currentAsp: 20,
  currentKap: 0,
  currentAu: 25,
).copyWith(wpiZustand: const WundZustand(wundenProZone: {WundZone.brust: 2}));

const _balsam = HeilEingabe(
  zauberId: kBalsamZauberId,
  asp: 14,
  zfw: 9,
  wundheilungAngesagt: true,
  zone: WundZone.brust,
  wunden: 2,
  selbstGewirkt: true,
);

HeilungErhalten _ablauf(FakeRepository repo) =>
    HeilungErhalten(repository: repo, uhr: () => _jetzt);

class _ZaehlendesRepo extends FakeRepository {
  _ZaehlendesRepo() : super(states: {'held': _start});

  int speichervorgaenge = 0;

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    speichervorgaenge++;
    await super.saveHeroState(heroId, state);
  }
}

void main() {
  test(
    'bucht LeP, AsP, Wunden, Buchung und Protokoll in einem Dokument',
    () async {
      final repo = _ZaehlendesRepo();

      final a = await _ablauf(repo).uebernehmeHeilung(
        heroId: 'held',
        eingabe: _balsam,
        zauberName: 'Balsam Salabunde',
        maxLep: 40,
        vorgangId: 'v1',
      );

      final z = (await repo.loadHeroState('held'))!;
      expect(a.lep, 14);
      expect(z.currentLep, 26);
      expect(z.currentAsp, 6);
      expect(z.wpiZustand.wundenInZone(WundZone.brust), 0);
      expect(z.lastModified, _jetzt);
      expect(repo.speichervorgaenge, 1);
      final buchung = z.buchungen.single;
      expect(buchung.art, ZustandsBuchungsArt.heilung);
      expect(buchung.lepDelta, 14);
      expect(buchung.aspDelta, -14);
      expect(buchung.wundenDelta, -2);
      expect(z.diceLog.single.title, heilungProtokollTitel);
      expect(z.diceLog.single.buchungId, 'v1');
      expectNurGeaendert(_start.toJson(), z.toJson(), {
        'currentLep',
        'currentAsp',
        'wpiZustand',
        'diceLog',
        'buchungen',
        'lastModified',
      });
    },
  );

  test(
    'dieselbe Vorgangs-ID bucht nichts doppelt und schreibt nichts',
    () async {
      final repo = _ZaehlendesRepo();
      final ablauf = _ablauf(repo);
      await ablauf.uebernehmeHeilung(
        heroId: 'held',
        eingabe: _balsam,
        zauberName: 'Balsam Salabunde',
        maxLep: 40,
        vorgangId: 'v1',
      );

      final wiederholt = await ablauf.uebernehmeHeilung(
        heroId: 'held',
        eingabe: _balsam,
        zauberName: 'Balsam Salabunde',
        maxLep: 40,
        vorgangId: 'v1',
      );

      final z = (await repo.loadHeroState('held'))!;
      expect(wiederholt.istWiederholung, isTrue);
      expect(wiederholt.lep, 14);
      expect(z.currentLep, 26);
      expect(z.currentAsp, 6);
      expect(z.buchungen, hasLength(1));
      expect(repo.speichervorgaenge, 1);
    },
  );

  test('eine inzwischen unzulässige Heilung wird nicht gebucht', () async {
    final repo = FakeRepository(
      states: {'held': _start.copyWith(currentAsp: 5)},
    );

    await expectLater(
      _ablauf(repo).uebernehmeHeilung(
        heroId: 'held',
        eingabe: _balsam,
        zauberName: 'Balsam Salabunde',
        maxLep: 40,
        vorgangId: 'v2',
      ),
      throwsA(isA<StateError>()),
    );

    final z = (await repo.loadHeroState('held'))!;
    expect(z.currentLep, 12);
    expect(z.buchungen, isEmpty);
  });

  test('Fremdzauber lässt die AsP des Helden unberührt', () async {
    final repo = FakeRepository(states: {'held': _start});

    await _ablauf(repo).uebernehmeHeilung(
      heroId: 'held',
      eingabe: const HeilEingabe(
        zauberId: kHexenspeichelZauberId,
        asp: 8,
        zfw: 10,
      ),
      zauberName: 'Hexenspeichel',
      maxLep: 40,
      vorgangId: 'v3',
    );

    final z = (await repo.loadHeroState('held'))!;
    expect(z.currentLep, 16);
    expect(z.currentAsp, 20);
    expect(z.buchungen.single.aspDelta, 0);
  });
}
