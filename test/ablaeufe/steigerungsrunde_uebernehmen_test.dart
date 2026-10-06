import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/steigerungsrunde_uebernehmen.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  spells: [],
  weapons: [],
);

const _held = HeroSheet(
  id: 'held',
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

HeroAdvancementEntry _mutSteigern({int von = 12, int auf = 13}) {
  return HeroAdvancementEntry(
    id: 'mut',
    sessionId: 'runde',
    createdAt: DateTime.utc(2026, 10, 5),
    kind: AdvancementKind.attribute,
    targetId: 'mu',
    label: 'mu',
    fromValue: von,
    toValue: auf,
    apCost: 100,
  );
}

/// Speichert wie `HeroActions.saveHero` (ohne Normalisierung) und merkt
/// sich, womit es aufgerufen wurde.
class _Speicherung {
  _Speicherung(this.repo);

  final FakeRepository repo;
  final List<HeroSheet> gespeichert = <HeroSheet>[];
  String? erwarteterHash;
  RulesCatalog? katalog;

  Future<HeroSheet> call(
    HeroSheet gebucht, {
    String? expectedContentHash,
    RulesCatalog? validationCatalog,
  }) async {
    erwarteterHash = expectedContentHash;
    katalog = validationCatalog;
    gespeichert.add(gebucht);
    await repo.saveHero(gebucht);
    return gebucht;
  }
}

void main() {
  group('uebernehmeRunde', () {
    test('bucht Werte, AP und Historie gemeinsam auf die Basis', () async {
      final repo = FakeRepository(heroes: [_held]);
      final speicherung = _Speicherung(repo);
      final ablauf = SteigerungsrundeUebernehmen(
        repository: repo,
        speichere: speicherung.call,
      );

      final ergebnis = await ablauf.uebernehmeRunde(
        basis: _held,
        eintraege: [_mutSteigern()],
        katalog: _katalog,
      );

      expect(ergebnis.attributes.mu, 13);
      expect(ergebnis.apSpent, 100);
      expect(ergebnis.advancementHistory.single.id, 'mut');
      expect(speicherung.gespeichert, hasLength(1));
      expect(speicherung.erwarteterHash, heroContentHash(_held));
      expect(speicherung.katalog, same(_katalog));
      expect((await repo.loadHeroById('held'))!.attributes.mu, 13);
    });

    test('ein inzwischen geänderter Held wird nicht überschrieben', () async {
      final repo = FakeRepository(heroes: [_held]);
      await repo.saveHero(_held.copyWith(name: 'Geändert'));
      final speicherung = _Speicherung(repo);
      final ablauf = SteigerungsrundeUebernehmen(
        repository: repo,
        speichere: speicherung.call,
      );

      await expectLater(
        ablauf.uebernehmeRunde(
          basis: _held,
          eintraege: [_mutSteigern()],
          katalog: _katalog,
        ),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            contains('plane mit dem aktuellen Helden erneut'),
          ),
        ),
      );
      expect(speicherung.gespeichert, isEmpty);
      final gespeichert = (await repo.loadHeroById('held'))!;
      expect(gespeichert.name, 'Geändert');
      expect(gespeichert.attributes.mu, 12);
    });

    test('ein fehlender Held wird gemeldet, gespeichert wird nichts', () async {
      final repo = FakeRepository();
      final speicherung = _Speicherung(repo);
      final ablauf = SteigerungsrundeUebernehmen(
        repository: repo,
        speichere: speicherung.call,
      );

      await expectLater(
        ablauf.uebernehmeRunde(
          basis: _held,
          eintraege: [_mutSteigern()],
          katalog: _katalog,
        ),
        throwsStateError,
      );
      expect(speicherung.gespeichert, isEmpty);
    });

    test('eine inzwischen geschlossene Runde speichert nichts', () async {
      final repo = FakeRepository(heroes: [_held]);
      final speicherung = _Speicherung(repo);
      final ablauf = SteigerungsrundeUebernehmen(
        repository: repo,
        speichere: speicherung.call,
      );

      await expectLater(
        ablauf.uebernehmeRunde(
          basis: _held,
          eintraege: [_mutSteigern()],
          katalog: _katalog,
          istGeschlossen: () => true,
        ),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            'Die Steigerungsrunde wurde inzwischen geschlossen.',
          ),
        ),
      );
      expect(speicherung.gespeichert, isEmpty);
    });

    test('ungültige Einträge werden nicht gebucht', () async {
      final repo = FakeRepository(heroes: [_held]);
      final speicherung = _Speicherung(repo);
      final ablauf = SteigerungsrundeUebernehmen(
        repository: repo,
        speichere: speicherung.call,
      );

      await expectLater(
        ablauf.uebernehmeRunde(
          basis: _held,
          // Der Ausgangswert passt nicht zum gespeicherten MU 12.
          eintraege: [_mutSteigern(von: 13, auf: 14)],
          katalog: _katalog,
        ),
        throwsStateError,
      );
      expect(speicherung.gespeichert, isEmpty);
    });

    test('Speicherfehler erreichen den Aufrufer unverändert', () async {
      final repo = FakeRepository(heroes: [_held]);
      final ablauf = SteigerungsrundeUebernehmen(
        repository: repo,
        speichere: (_, {expectedContentHash, validationCatalog}) async =>
            throw StateError('Schreibfehler'),
      );

      await expectLater(
        ablauf.uebernehmeRunde(
          basis: _held,
          eintraege: [_mutSteigern()],
          katalog: _katalog,
        ),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            'Schreibfehler',
          ),
        ),
      );
      expect((await repo.loadHeroById('held'))!.attributes.mu, 12);
    });
  });

  group('speichereSfAnzeige', () {
    SteigerungsrundeUebernehmen ablaufFuer(FakeRepository repo) {
      return SteigerungsrundeUebernehmen(
        repository: repo,
        speichere: (_, {expectedContentHash, validationCatalog}) =>
            throw StateError('Die Anzeige wird nie normalisiert.'),
      );
    }

    test('ändert nur die Präferenz am frisch geladenen Helden', () async {
      final repo = FakeRepository(heroes: [_held]);
      await repo.saveHero(_held.copyWith(name: 'Geändert'));

      final ergebnis = await ablaufFuer(repo)
          .speichereSfAnzeige(heroId: 'held', anzeigen: true);

      expect(ergebnis.showInapplicableSpecialAbilities, isTrue);
      final gespeichert = (await repo.loadHeroById('held'))!;
      expect(gespeichert.showInapplicableSpecialAbilities, isTrue);
      expect(gespeichert.name, 'Geändert');
    });

    test('mit offener Runde nur auf unveränderter Basis', () async {
      final repo = FakeRepository(heroes: [_held]);
      final ablauf = ablaufFuer(repo);

      await ablauf.speichereSfAnzeige(
        heroId: 'held',
        anzeigen: true,
        basis: _held,
      );
      expect(
        (await repo.loadHeroById('held'))!.showInapplicableSpecialAbilities,
        isTrue,
      );

      await repo.saveHero(_held.copyWith(name: 'Geändert'));
      await expectLater(
        ablauf.speichereSfAnzeige(
          heroId: 'held',
          anzeigen: false,
          basis: _held,
        ),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            'Der Held wurde inzwischen geändert.',
          ),
        ),
      );
      final gespeichert = (await repo.loadHeroById('held'))!;
      expect(gespeichert.name, 'Geändert');
      expect(gespeichert.showInapplicableSpecialAbilities, isFalse);
    });

    test('fehlender Held und geschlossene Runde speichern nichts', () async {
      final leer = FakeRepository();
      await expectLater(
        ablaufFuer(leer).speichereSfAnzeige(heroId: 'held', anzeigen: true),
        throwsStateError,
      );

      final repo = FakeRepository(heroes: [_held]);
      await expectLater(
        ablaufFuer(repo).speichereSfAnzeige(
          heroId: 'held',
          anzeigen: true,
          istGeschlossen: () => true,
        ),
        throwsStateError,
      );
      expect(
        (await repo.loadHeroById('held'))!.showInapplicableSpecialAbilities,
        isFalse,
      );
    });

    test('wartet auf eine laufende Bogenänderung und überschreibt sie '
        'nicht', () async {
      final repo = FakeRepository(heroes: [_held]);
      final schreibFreigabe = Completer<void>();

      // Eine frische Änderung hat schon geladen, ihr Speichern hängt noch.
      final laufend = aendereGespeichertenHelden(
        repository: repo,
        heroId: 'held',
        aenderung: (held) => held.copyWith(name: 'Rondra die Kühne'),
        speichere: (geaendert) async {
          await schreibFreigabe.future;
          await repo.saveHero(geaendert);
          return geaendert;
        },
      );
      final anzeige = ablaufFuer(repo)
          .speichereSfAnzeige(heroId: 'held', anzeigen: true);

      await Future<void>.delayed(Duration.zero);
      expect(
        (await repo.loadHeroById('held'))!.showInapplicableSpecialAbilities,
        isFalse,
      );
      schreibFreigabe.complete();
      await Future.wait([laufend, anzeige]);

      final gespeichert = (await repo.loadHeroById('held'))!;
      expect(gespeichert.name, 'Rondra die Kühne');
      expect(gespeichert.showInapplicableSpecialAbilities, isTrue);
    });
  });
}
