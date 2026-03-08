import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

void main() {
  ProviderContainer buildContainer(FakeRepository repo) {
    final container = ProviderContainer(
      overrides: [heroRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('buildExportJson includes required envelope fields', () async {
    final repo = FakeRepository(
      heroes: [
        const HeroSheet(
          id: 'h1',
          name: 'Test',
          level: 1,
          attributes: Attributes(
            mu: 8,
            kl: 8,
            inn: 8,
            ch: 8,
            ff: 8,
            ge: 8,
            ko: 8,
            kk: 8,
          ),
        ),
      ],
      states: {
        'h1': const HeroState(
          currentLep: 20,
          currentAsp: 5,
          currentKap: 0,
          currentAu: 30,
        ),
      },
    );
    final container = buildContainer(repo);
    final actions = container.read(heroActionsProvider);

    final raw = await actions.buildExportJson('h1');
    final map = jsonDecode(raw) as Map<String, dynamic>;

    expect(map['kind'], HeroTransferBundle.kind);
    expect(
      map['transferSchemaVersion'],
      HeroTransferBundle.transferSchemaVersion,
    );
    expect(map['exportedAt'], isA<String>());
    expect(map['hero'], isA<Map>());
    expect(map['state'], isA<Map>());
  });

  test('createHero stores raw and effective start attributes', () async {
    final repo = FakeRepository.empty();
    final container = buildContainer(repo);
    final actions = container.read(heroActionsProvider);

    final heroId = await actions.createHero(
      name: 'Startheld',
      rawStartAttributes: const Attributes(
        mu: 12,
        kl: 13,
        inn: 11,
        ch: 10,
        ff: 9,
        ge: 8,
        ko: 7,
        kk: 6,
      ),
    );

    final hero = await repo.loadHeroById(heroId);
    expect(hero, isNotNull);
    expect(hero!.name, 'Startheld');
    expect(hero.rawStartAttributes.kl, 13);
    expect(hero.startAttributes.kl, 13);
    expect(hero.attributes.kl, 13);
  });

  test('import non-conflicting hero creates hero and state', () async {
    final repo = FakeRepository.empty();
    final container = buildContainer(repo);
    final actions = container.read(heroActionsProvider);

    final bundle = HeroTransferBundle(
      exportedAt: DateTime.utc(2026, 2, 22),
      hero: const HeroSheet(
        id: 'new-id',
        name: 'Importiert',
        level: 1,
        attributes: Attributes(
          mu: 8,
          kl: 8,
          inn: 8,
          ch: 8,
          ff: 8,
          ge: 8,
          ko: 8,
          kk: 8,
        ),
      ),
      state: const HeroState(
        currentLep: 12,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 18,
        tempAttributeMods: AttributeModifiers(mu: 3),
      ),
    );

    final importedId = await actions.importHeroBundle(
      bundle,
      resolution: ImportConflictResolution.overwriteExisting,
    );

    expect(importedId, 'new-id');
    final heroes = await repo.listHeroes();
    expect(heroes.length, 1);
    expect(heroes.single.id, 'new-id');
    final state = await repo.loadHeroState('new-id');
    expect(state?.currentLep, 12);
    expect(state?.tempAttributeMods.mu, 3);
  });

  test('conflict overwrite replaces existing hero and state', () async {
    final repo = FakeRepository(
      heroes: [
        const HeroSheet(
          id: 'same-id',
          name: 'Alt',
          level: 1,
          attributes: Attributes(
            mu: 8,
            kl: 8,
            inn: 8,
            ch: 8,
            ff: 8,
            ge: 8,
            ko: 8,
            kk: 8,
          ),
        ),
      ],
      states: {
        'same-id': const HeroState(
          currentLep: 5,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    final container = buildContainer(repo);
    final actions = container.read(heroActionsProvider);

    final bundle = HeroTransferBundle(
      exportedAt: DateTime.utc(2026, 2, 22),
      hero: const HeroSheet(
        id: 'same-id',
        name: 'Neu',
        level: 1,
        attributes: Attributes(
          mu: 10,
          kl: 8,
          inn: 8,
          ch: 8,
          ff: 8,
          ge: 8,
          ko: 8,
          kk: 8,
        ),
      ),
      state: const HeroState(
        currentLep: 33,
        currentAsp: 1,
        currentKap: 0,
        currentAu: 40,
      ),
    );

    final importedId = await actions.importHeroBundle(
      bundle,
      resolution: ImportConflictResolution.overwriteExisting,
    );

    expect(importedId, 'same-id');
    final heroes = await repo.listHeroes();
    expect(heroes.length, 1);
    expect(heroes.single.name, 'Neu');
    final state = await repo.loadHeroState('same-id');
    expect(state?.currentLep, 33);
  });

  test('conflict createNewHero generates a new id', () async {
    final repo = FakeRepository(
      heroes: [
        const HeroSheet(
          id: 'same-id',
          name: 'Alt',
          level: 1,
          attributes: Attributes(
            mu: 8,
            kl: 8,
            inn: 8,
            ch: 8,
            ff: 8,
            ge: 8,
            ko: 8,
            kk: 8,
          ),
        ),
      ],
      states: {
        'same-id': const HeroState(
          currentLep: 5,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    final container = buildContainer(repo);
    final actions = container.read(heroActionsProvider);

    final bundle = HeroTransferBundle(
      exportedAt: DateTime.utc(2026, 2, 22),
      hero: const HeroSheet(
        id: 'same-id',
        name: 'Neu',
        level: 1,
        attributes: Attributes(
          mu: 10,
          kl: 8,
          inn: 8,
          ch: 8,
          ff: 8,
          ge: 8,
          ko: 8,
          kk: 8,
        ),
      ),
      state: const HeroState(
        currentLep: 33,
        currentAsp: 1,
        currentKap: 0,
        currentAu: 40,
      ),
    );

    final importedId = await actions.importHeroBundle(
      bundle,
      resolution: ImportConflictResolution.createNewHero,
    );

    expect(importedId, isNot('same-id'));
    final heroes = await repo.listHeroes();
    expect(heroes.length, 2);
    expect(heroes.any((hero) => hero.id == 'same-id'), isTrue);
    expect(heroes.any((hero) => hero.id == importedId), isTrue);
    final state = await repo.loadHeroState(importedId);
    expect(state?.currentLep, 33);
  });
}
