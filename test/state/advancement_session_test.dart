import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

const _catalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  spells: [],
  weapons: [],
);
const _hero = HeroSheet(
  id: 'hero',
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
  apTotal: 2000,
  apAvailable: 2000,
);

HeroAdvancementEntry _entry(
  String sessionId, {
  String id = 'raise',
  String targetId = 'mu',
  int from = 12,
  int to = 13,
}) => HeroAdvancementEntry(
  id: id,
  sessionId: sessionId,
  createdAt: DateTime.utc(2026, 9, 5),
  kind: AdvancementKind.attribute,
  targetId: targetId,
  label: targetId,
  fromValue: from,
  toValue: to,
  apCost: 100,
);

class _RecordingRepository extends FakeRepository {
  _RecordingRepository() : super(heroes: [_hero]);
  int writes = 0;
  bool fail = false;

  @override
  Future<void> saveHero(HeroSheet hero) async {
    if (fail) throw StateError('Speichern fehlgeschlagen');
    writes++;
    await super.saveHero(hero);
  }
}

void main() {
  late _RecordingRepository repo;
  late ProviderContainer container;
  late AdvancementSessionController controller;

  setUp(() {
    repo = _RecordingRepository();
    container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => _catalog),
      ],
    );
    controller = container.read(advancementSessionProvider('hero').notifier);
    controller.start(hero: _hero, catalog: _catalog);
  });
  tearDown(() => container.dispose());

  AdvancementSession session() =>
      container.read(advancementSessionProvider('hero'))!;

  test(
    'planning never persists; commit saves values and history together',
    () async {
      controller.add(_entry(session().sessionId));
      expect(session().preview.attributes.mu, 13);
      expect((await repo.loadHeroById('hero'))!.attributes.mu, 12);
      expect(repo.writes, 0);
      await controller.commit();
      final saved = (await repo.loadHeroById('hero'))!;
      expect(saved.attributes.mu, 13);
      expect(saved.apSpent, 100);
      expect(saved.advancementHistory.single.id, 'raise');
      expect(repo.writes, 1);
      expect(container.read(advancementSessionProvider('hero')), isNull);
    },
  );

  test('removing an independent pending entry preserves the others', () async {
    controller.add(_entry(session().sessionId));
    controller.add(_entry(session().sessionId, id: 'kl', targetId: 'kl'));
    controller.remove('raise');
    expect(session().preview.attributes.mu, 12);
    expect(session().preview.attributes.kl, 13);
    expect(session().entries.single.id, 'kl');
    await controller.commit();
    expect(
      (await repo.loadHeroById('hero'))!.advancementHistory.single.id,
      'kl',
    );
  });

  test(
    'dependent entries stay visible and block commit after removal',
    () async {
      controller.add(_entry(session().sessionId));
      controller.add(
        _entry(session().sessionId, id: 'second', from: 13, to: 14),
      );
      controller.remove('raise');
      expect(session().entries.single.id, 'second');
      expect(session().errors, contains('second'));
      expect(session().canCommit, isFalse);
      await expectLater(controller.commit(), throwsStateError);
      expect(repo.writes, 0);
      controller.remove('second');
      expect(session().errors, isEmpty);
      expect(session().preview.attributes.mu, 12);
    },
  );

  test('old session entries cannot be removed or added again', () async {
    final oldSessionId = session().sessionId;
    controller.add(_entry(oldSessionId));
    await controller.commit();
    final saved = (await repo.loadHeroById('hero'))!;
    controller.start(hero: saved, catalog: _catalog);
    expect(() => controller.remove('raise'), throwsStateError);
    expect(() => controller.add(_entry(oldSessionId)), throwsStateError);
    expect(session().base.advancementHistory.single.id, 'raise');
  });

  test('discard leaves the persisted hero untouched', () async {
    controller.add(_entry(session().sessionId));
    controller.discard();
    expect(repo.writes, 0);
    expect(container.read(advancementSessionProvider('hero')), isNull);
    expect((await repo.loadHeroById('hero'))!.advancementHistory, isEmpty);
  });

  test(
    'concurrent hero change prevents stale overwrite and keeps draft',
    () async {
      controller.add(_entry(session().sessionId));
      await repo.saveHero(_hero.copyWith(name: 'Geändert'));
      await expectLater(controller.commit(), throwsStateError);
      expect(repo.writes, 1);
      expect((await repo.loadHeroById('hero'))!.name, 'Geändert');
      expect(session().entries, hasLength(1));
      expect(session().isSaving, isFalse);
    },
  );

  test('save failure keeps the session retryable', () async {
    controller.add(_entry(session().sessionId));
    repo.fail = true;
    await expectLater(controller.commit(), throwsStateError);
    expect(session().isSaving, isFalse);
    expect(session().entries, hasLength(1));
    repo.fail = false;
    await controller.commit();
    expect(repo.writes, 1);
  });

  test('duplicate entries are rejected before they can be booked twice', () {
    final entry = _entry(session().sessionId);
    controller.add(entry);
    expect(() => controller.add(entry), throwsStateError);
    expect(session().entries, hasLength(1));
  });

  test('switching the storage profile closes the old uncommitted round', () {
    controller.add(_entry(session().sessionId));
    container.updateOverrides([
      heroRepositoryProvider.overrideWithValue(FakeRepository(heroes: [_hero])),
      rulesCatalogProvider.overrideWith((ref) async => _catalog),
    ]);
    expect(container.read(advancementSessionProvider('hero')), isNull);
    expect(repo.writes, 0);
  });

  test('planning moves a target from the inactive to the active scope', () {
    const talentCatalog = RulesCatalog(
      version: 'test',
      source: 'test',
      spells: [],
      weapons: [],
      talents: [
        TalentDef(
          id: 'climb',
          name: 'Klettern',
          group: 'Körper',
          steigerung: 'B',
          attributes: ['MU', 'GE', 'KK'],
        ),
      ],
    );
    final talentContainer = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(heroes: [_hero]),
        ),
        rulesCatalogProvider.overrideWith((ref) async => talentCatalog),
      ],
    );
    addTearDown(talentContainer.dispose);
    final talentController = talentContainer.read(
      advancementSessionProvider('hero').notifier,
    );
    talentController.start(hero: _hero, catalog: talentCatalog);

    List<String> talentIds(AdvancementScope scope) => talentContainer
        .read(advancementOptionsProvider((heroId: 'hero', scope: scope)))
        .where((option) => option.kind == AdvancementKind.talent)
        .map((option) => option.targetId)
        .toList();

    expect(talentIds(AdvancementScope.active), isEmpty);
    expect(talentIds(AdvancementScope.inactive), ['climb']);

    talentController.add(
      HeroAdvancementEntry(
        id: 'activate',
        sessionId: talentContainer
            .read(advancementSessionProvider('hero'))!
            .sessionId,
        createdAt: DateTime.utc(2026, 9, 6),
        kind: AdvancementKind.talent,
        targetId: 'climb',
        label: 'Klettern',
        fromValue: -1,
        toValue: 0,
        apCost: 10,
      ),
    );

    // Die Memoisierung muss der Sitzung folgen, sonst zeigte das Erwerbsblatt
    // ein bereits vorgemerktes Ziel weiterhin als noch nicht vorhanden.
    expect(talentIds(AdvancementScope.active), ['climb']);
    expect(talentIds(AdvancementScope.inactive), isEmpty);
  });
}
