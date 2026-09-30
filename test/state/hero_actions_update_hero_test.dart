import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  apTotal: 1000,
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
  late _Repository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _Repository(heroes: [_held]);
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

  test('updateHero und saveHero liefern den normalisierten Helden', () async {
    final aktionen = container.read(heroActionsProvider);

    final aktualisiert = await aktionen.updateHero(
      'demo',
      (held) => held.copyWith(apSpent: 300),
    );
    // Frei verfuegbare AP rechnet erst die Normalisierung aus.
    expect(aktualisiert.apAvailable, 700);
    expect(aktualisiert.lastModified, isNotNull);

    final gespeichert = await aktionen.saveHero(
      aktualisiert.copyWith(apTotal: 1100),
    );
    expect(gespeichert.apAvailable, 800);
    expect((await repo.loadHeroById('demo'))!.apAvailable, 800);
  });

  test('zwei nicht abgewartete Schritte zaehlen beide', () async {
    final aktionen = container.read(heroActionsProvider);

    await Future.wait([
      aktionen.updateHero('demo', (h) => h.copyWith(apTotal: h.apTotal + 5)),
      aktionen.updateHero('demo', (h) => h.copyWith(apTotal: h.apTotal + 5)),
    ]);

    expect((await repo.loadHeroById('demo'))!.apTotal, 1010);
  });

  test('saveHero ueberholt keine laufende Aenderung', () async {
    final aktionen = container.read(heroActionsProvider);
    repo.haltErstesSpeichern = true;

    // Die frische Aenderung hat schon geladen und haengt beim Schreiben.
    final aenderung = aktionen.updateHero(
      'demo',
      (held) => held.copyWith(apTotal: held.apTotal + 10),
    );
    await pumpEventQueue();
    // Ein Editor speichert seinen Entwurf mit einer Notiz.
    final entwurf = aktionen.saveHero(
      _held.copyWith(notes: const [HeroNoteEntry(title: 'Entwurf')]),
    );
    await pumpEventQueue();
    repo.gibSpeichernFrei();
    await Future.wait([aenderung, entwurf]);

    // Ohne Reihenfolge schriebe die Aenderung ihren alten Stand ueber den
    // Entwurf; so gewinnt der zuletzt ausgeloeste Schreibvorgang.
    final gespeichert = await repo.loadHeroById('demo');
    expect(gespeichert!.notes.single.title, 'Entwurf');
  });

  test('die Hash-Pruefung sieht eine eingereihte Aenderung', () async {
    final aktionen = container.read(heroActionsProvider);
    final hashVorher = heroContentHash(_held);

    final aenderung = aktionen.updateHero(
      'demo',
      (held) => held.copyWith(apTotal: held.apTotal + 10),
    );
    final uebernahme = aktionen.saveHero(
      _held.copyWith(apSpent: 50),
      expectedContentHash: hashVorher,
    );

    await aenderung;
    await expectLater(uebernahme, throwsStateError);
    expect((await repo.loadHeroById('demo'))!.apTotal, 1010);
  });
}

/// Repository, dessen erstes Heldenspeichern bis [gibSpeichernFrei] haengt.
class _Repository extends FakeRepository {
  _Repository({super.heroes});

  bool haltErstesSpeichern = false;
  final Completer<void> _freigabe = Completer<void>();

  /// Laesst das angehaltene Speichern weiterlaufen.
  void gibSpeichernFrei() => _freigabe.complete();

  @override
  Future<void> saveHero(HeroSheet hero) async {
    if (haltErstesSpeichern) {
      haltErstesSpeichern = false;
      await _freigabe.future;
    }
    await super.saveHero(hero);
  }
}
