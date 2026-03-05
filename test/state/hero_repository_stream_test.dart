import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

void main() {
  HeroSheet buildHero(String id, String name) {
    return HeroSheet(
      id: id,
      name: name,
      level: 1,
      attributes: const Attributes(
        mu: 8,
        kl: 8,
        inn: 8,
        ch: 8,
        ff: 8,
        ge: 8,
        ko: 8,
        kk: 8,
      ),
    );
  }

  test('watchHeroIndex emits incremental updates on save/delete', () async {
    final repo = FakeRepository.empty();
    final snapshots = <Map<String, HeroSheet>>[];
    final subscription = repo.watchHeroIndex().listen(snapshots.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    await repo.saveHero(buildHero('h-1', 'Alpha'));
    await repo.saveHero(buildHero('h-2', 'Beta'));
    await repo.deleteHero('h-1');
    await Future<void>.delayed(Duration.zero);

    expect(snapshots, isNotEmpty);
    final last = snapshots.last;
    expect(last.containsKey('h-1'), isFalse);
    expect(last.containsKey('h-2'), isTrue);
    expect(last['h-2']!.name, 'Beta');
  });

  test('watchHeroState emits default and updates', () async {
    final repo = FakeRepository.empty();
    final states = <HeroState>[];
    final subscription = repo.watchHeroState('h-1').listen(states.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    await repo.saveHeroState(
      'h-1',
      const HeroState(
        currentLep: 20,
        currentAsp: 5,
        currentKap: 0,
        currentAu: 15,
      ),
    );
    await repo.deleteHero('h-1');
    await Future<void>.delayed(Duration.zero);

    expect(states.first.currentLep, 0);
    expect(states.any((state) => state.currentLep == 20), isTrue);
    expect(states.last.currentLep, 0);
  });
}
