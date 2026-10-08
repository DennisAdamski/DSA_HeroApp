import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/vertrauten_vereinigung.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

final _jetzt = DateTime.utc(2026, 10, 8, 22);

const _mira = HeroCompanion(
  id: 'mira',
  name: 'Mira',
  typ: BegleiterTyp.vertrauter,
  maxAsp: 6,
  startAsp: 6,
  maxLep: 11,
  startLep: 11,
);

const _hexe = HeroSheet(
  id: 'hexe',
  name: 'Hexe',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
  companions: <HeroCompanion>[_mira],
);

const _start = HeroState(
  currentLep: 30,
  currentAsp: 20,
  currentKap: 0,
  currentAu: 30,
);

VertrautenVereinigung _ablauf(FakeRepository repo) =>
    VertrautenVereinigung(repository: repo, uhr: () => _jetzt);

void main() {
  test('beide verlieren ihren Wurf an AsP, zwei Protokolleinträge', () async {
    final repo = FakeRepository(
      heroes: const [_hexe],
      states: {'hexe': _start},
    );

    final ergebnis = await _ablauf(repo).vereinige(
      heroId: 'hexe',
      begleiterId: 'mira',
      wurfHexe: 4,
      wurfVertrauter: 2,
    );

    final z = (await repo.loadHeroState('hexe'))!;
    expect((ergebnis.verlustHexe, ergebnis.verlustVertrauter), (4, 2));
    expect(z.currentAsp, 16);
    expect(z.begleiterZustaende['mira']!.currentAsp, 4);
    expect(z.currentLep, 30, reason: 'LeP bleiben unberührt');
    expect(z.lastModified, _jetzt);
    expect(z.diceLog.map((e) => e.title), [
      'Vereinigung: Hexe',
      'Vereinigung: Mira',
    ]);
    expect(z.diceLog.map((e) => e.diceValues.single), [4, 2]);
  });

  test('der Verlust endet am vorhandenen Vorrat', () async {
    final repo = FakeRepository(
      heroes: const [_hexe],
      states: {
        'hexe': _start
            .copyWith(currentAsp: 2)
            .withBegleiterZustand(
              'mira',
              const BegleiterZustand(currentAsp: 1),
            ),
      },
    );

    final ergebnis = await _ablauf(repo).vereinige(
      heroId: 'hexe',
      begleiterId: 'mira',
      wurfHexe: 6,
      wurfVertrauter: 5,
    );

    final z = (await repo.loadHeroState('hexe'))!;
    expect((ergebnis.verlustHexe, ergebnis.verlustVertrauter), (2, 1));
    expect(z.currentAsp, 0);
    expect(z.begleiterZustaende['mira']!.currentAsp, 0);
  });

  test('erhält Zwischenänderungen anderer Schreibwege', () async {
    final repo = FakeRepository(
      heroes: const [_hexe],
      states: {'hexe': _start},
    );
    await repo.saveHeroState(
      'hexe',
      _start
          .copyWith(
            currentKap: 9,
            wpiZustand: const WundZustand(
              wundenProZone: <WundZone, int>{WundZone.brust: 1},
            ),
          )
          .withBegleiterZustand('mira', const BegleiterZustand(currentLep: 3)),
    );

    await _ablauf(repo).vereinige(
      heroId: 'hexe',
      begleiterId: 'mira',
      wurfHexe: 1,
      wurfVertrauter: 1,
    );

    final z = (await repo.loadHeroState('hexe'))!;
    expect(z.currentKap, 9);
    expect(z.wpiZustand.wundenInZone(WundZone.brust), 1);
    expect(z.begleiterZustaende['mira']!.currentLep, 3);
    expect(z.begleiterZustaende['mira']!.currentAsp, 5);
  });

  test('ungültige Würfe, fehlende und fremde Begleiter brechen ab', () async {
    final repo = FakeRepository(
      heroes: const [
        _hexe,
        HeroSheet(
          id: 'reiter',
          name: 'Reiter',
          level: 1,
          attributes: Attributes(
            mu: 12,
            kl: 12,
            inn: 12,
            ch: 12,
            ff: 12,
            ge: 12,
            ko: 12,
            kk: 12,
          ),
          companions: <HeroCompanion>[
            HeroCompanion(id: 'rosse', typ: BegleiterTyp.reittier),
          ],
        ),
      ],
      states: {'hexe': _start, 'reiter': _start},
    );
    final ablauf = _ablauf(repo);

    expect(
      () => ablauf.vereinige(
        heroId: 'hexe',
        begleiterId: 'mira',
        wurfHexe: 0,
        wurfVertrauter: 3,
      ),
      throwsStateError,
    );
    expect(
      () => ablauf.vereinige(
        heroId: 'hexe',
        begleiterId: 'weg',
        wurfHexe: 3,
        wurfVertrauter: 3,
      ),
      throwsStateError,
    );
    expect(
      () => ablauf.vereinige(
        heroId: 'reiter',
        begleiterId: 'rosse',
        wurfHexe: 3,
        wurfVertrauter: 3,
      ),
      throwsStateError,
    );
    expect((await repo.loadHeroState('hexe'))!.currentAsp, 20);
  });
}
