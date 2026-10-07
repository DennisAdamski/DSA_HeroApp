import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/startup_hero_importer.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

const _attribute = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

final _held = HeroSheet(
  id: 'start',
  name: 'Startheld',
  level: 1,
  attributes: _attribute,
);

const _zustand = HeroState(
  currentLep: 30,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 31,
);

final _jetzt = DateTime.utc(2026, 10, 7, 12);

void main() {
  test(
    'ein neuer Startheld wird mit gestempeltem Zustand geschrieben',
    () async {
      final repo = FakeRepository.empty();

      await uebernimmStartheld(
        repo,
        _held,
        _zustand,
        existiert: false,
        uhr: () => _jetzt,
      );

      expect(await repo.loadHeroById('start'), isNotNull);
      final zustand = (await repo.loadHeroState('start'))!;
      expect(zustand.currentLep, 30);
      expect(zustand.lastModified, _jetzt);
    },
  );

  test('fehlt einem vorhandenen Starthelden der Zustand, wird nur er '
      'nachgetragen (ARCH-06)', () async {
    final vorhanden = _held.copyWith(name: 'Umbenannt');
    final repo = FakeRepository(heroes: [vorhanden]);

    await uebernimmStartheld(
      repo,
      _held,
      _zustand,
      existiert: true,
      uhr: () => _jetzt,
    );

    expect((await repo.loadHeroById('start'))!.name, 'Umbenannt');
    expect((await repo.loadHeroState('start'))!.currentLep, 30);
  });

  test('ein vorhandener Zustand bleibt unangetastet', () async {
    const gespielt = HeroState(
      currentLep: 4,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 2,
    );
    final repo = FakeRepository(heroes: [_held], states: {'start': gespielt});

    await uebernimmStartheld(
      repo,
      _held,
      _zustand,
      existiert: true,
      uhr: () => _jetzt,
    );

    expect(identical(await repo.loadHeroState('start'), gespielt), isTrue);
  });
}
