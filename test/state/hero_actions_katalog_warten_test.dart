import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
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
  vorteileText: 'Gutes Gedächtnis; Seltsamer Tick',
);

const _katalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
  advantages: <HeroTraitDef>[
    HeroTraitDef(
      id: 'v_gutes_gedaechtnis',
      name: 'Gutes Gedächtnis',
      traitType: 'advantage',
    ),
  ],
);

/// Obergrenze, nach der ein Speichern als hängend gilt.
const _haenger = Duration(seconds: 5);

void main() {
  late FakeRepository repo;

  ProviderContainer container(Future<RulesCatalog> Function() katalog) {
    repo = FakeRepository(heroes: [_held]);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) => katalog()),
        heroActionsProvider.overrideWith(
          (ref) => HeroActions(
            ref,
            katalogWartezeit: const Duration(milliseconds: 200),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<List<String>> gespeicherteFragmente() async {
    return (await repo.loadHeroById('demo'))!.unknownModifierFragments;
  }

  test('ein scheiternder Katalog speichert ungefiltert', () async {
    final c = container(() async => throw StateError('Katalog defekt'));

    await c.read(heroActionsProvider).saveHero(_held).timeout(_haenger);

    expect(await gespeicherteFragmente(), [
      'Gutes Gedächtnis',
      'Seltsamer Tick',
    ]);
  });

  test('ein noch ladender Katalog wird abgewartet und filtert', () async {
    final laden = Completer<RulesCatalog>();
    final c = container(() => laden.future);

    final speichern = c.read(heroActionsProvider).saveHero(_held);
    laden.complete(_katalog);
    await speichern.timeout(_haenger);

    expect(await gespeicherteFragmente(), ['Seltsamer Tick']);
  });

  test('ein nie fertiger Katalog endet nach der Wartezeit', () async {
    final c = container(() => Completer<RulesCatalog>().future);

    await c.read(heroActionsProvider).saveHero(_held).timeout(_haenger);

    expect(await gespeicherteFragmente(), [
      'Gutes Gedächtnis',
      'Seltsamer Tick',
    ]);
  });
}
