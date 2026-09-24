import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
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
);

void main() {
  late FakeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeRepository(heroes: [_held]);
    container = ProviderContainer(
      overrides: [heroRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('arbeitet auf dem frisch geladenen Helden', () async {
    // Ein anderer Schreibweg aendert den Helden nach dem UI-Aufbau.
    await repo.saveHero(_held.copyWith(name: 'Rondra die Kuehne'));

    await container
        .read(heroActionsProvider)
        .updateHero(
          'demo',
          (held) => held.copyWith(
            notes: const [HeroNoteEntry(title: 'Spur im Nebel')],
          ),
        );

    final gespeichert = await repo.loadHeroById('demo');
    expect(gespeichert!.notes.single.title, 'Spur im Nebel');
    expect(gespeichert.name, 'Rondra die Kuehne');
  });

  test('ein fehlender Held wird als Fehler gemeldet', () async {
    await expectLater(
      container.read(heroActionsProvider).updateHero('fehlt', (held) => held),
      throwsStateError,
    );
  });
}
