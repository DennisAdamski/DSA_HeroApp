import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/companion_steigerung_rules.dart';

// Sofortsteigerung eines Vertrauten auf dem gespeicherten Helden (ARCH-05).

const _vertrauter = HeroCompanion(
  id: 'rabe',
  name: 'Krah',
  typ: BegleiterTyp.vertrauter,
  mu: 10,
  maxLep: 12,
  apGesamt: 200,
  apAusgegeben: 20,
  steigerungen: {'mu': 1},
  angriffe: [HeroCompanionAttack(id: 'schnabel', at: 8, pa: 2)],
);

const _hund = HeroCompanion(id: 'hund', name: 'Wuff');

const _held = HeroSheet(
  id: 'held',
  name: 'Rondra',
  level: 1,
  companions: [_vertrauter, _hund],
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

const _vertrautenmagie = HeroRitualCategory(
  id: kVertrautenmagieKategorieId,
  name: 'Vertrautenmagie',
  knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
);

void main() {
  group('steigereBegleiter', () {
    test('setzt den Stand und bucht AP relativ', () {
      final ergebnis = steigereBegleiter(
        _vertrauter,
        ziel: const BegleiterSteigerungsziel.wert('mu'),
        erwarteterStand: 1,
        neuerStand: 3,
        apKosten: 15,
      );

      expect(ergebnis.steigerungen['mu'], 3);
      expect(ergebnis.apAusgegeben, 35);
    });

    test('ein inzwischen geänderter Stand wird abgewiesen', () {
      expect(
        () => steigereBegleiter(
          _vertrauter,
          ziel: const BegleiterSteigerungsziel.wert('mu'),
          erwarteterStand: 0,
          neuerStand: 2,
          apKosten: 10,
        ),
        throwsStateError,
      );
    });

    test('Angriffswerte steigen einzeln', () {
      final at = steigereBegleiter(
        _vertrauter,
        ziel: const BegleiterSteigerungsziel.angriff('schnabel', parade: false),
        erwarteterStand: 0,
        neuerStand: 2,
        apKosten: 8,
      );
      expect(at.angriffe.single.steigerungAt, 2);
      expect(at.angriffe.single.steigerungPa, 0);

      expect(
        () => steigereBegleiter(
          _vertrauter,
          ziel: const BegleiterSteigerungsziel.angriff('fehlt', parade: true),
          erwarteterStand: 0,
          neuerStand: 1,
          apKosten: 4,
        ),
        throwsStateError,
      );
    });
  });

  group('bucheBegleiterSteigerung', () {
    test('ändert nur den Begleiter und hält Startwerte fest', () {
      // Ein anderer Weg hat den Hund umbenannt.
      final gespeichert = _held.copyWith(
        name: 'Fremd',
        companions: [
          _vertrauter,
          _hund.copyWith(name: 'Bello'),
        ],
      );

      final ergebnis = bucheBegleiterSteigerung(
        gespeichert,
        begleiterId: 'rabe',
        ziel: const BegleiterSteigerungsziel.wert('lep'),
        erwarteterStand: 0,
        neuerStand: 2,
        apKosten: 12,
      );

      final rabe = ergebnis.companions.first;
      expect(rabe.steigerungen['lep'], 2);
      expect(rabe.steigerungen['mu'], 1);
      expect(rabe.startLep, 12);
      expect(rabe.apAusgegeben, 32);
      expect(ergebnis.companions.last.name, 'Bello');
      expect(ergebnis.name, 'Fremd');
    });

    test('überträgt die alte Vertrautenmagie wie bisher', () {
      final gespeichert = _held.copyWith(
        ritualCategories: const [_vertrautenmagie],
      );

      final ergebnis = bucheBegleiterSteigerung(
        gespeichert,
        begleiterId: 'rabe',
        ziel: const BegleiterSteigerungsziel.wert('rk'),
        erwarteterStand: 0,
        neuerStand: 1,
        apKosten: 5,
      );

      expect(ergebnis.ritualCategories, isEmpty);
      expect(
        ergebnis.companions.first.ritualCategories.single.id,
        kVertrautenmagieKategorieId,
      );
      expect(ergebnis.companions.last.ritualCategories, isEmpty);
    });

    test('ein entfernter Begleiter wird gemeldet', () {
      expect(
        () => bucheBegleiterSteigerung(
          _held.copyWith(companions: const [_hund]),
          begleiterId: 'rabe',
          ziel: const BegleiterSteigerungsziel.wert('mu'),
          erwarteterStand: 1,
          neuerStand: 2,
          apKosten: 5,
        ),
        throwsStateError,
      );
    });
  });

  test('mitVertrautenmagieAmBegleiter ohne alte Kategorie ändert nichts', () {
    expect(identical(mitVertrautenmagieAmBegleiter(_held), _held), isTrue);
  });
}
