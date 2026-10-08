// Voraussetzungen der Vertrautenbindung und Aurapanzer des Vertrauten
// (WdZ S. 123, S. 125).
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_aurapanzer_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_bindung_voraussetzung_rules.dart';
import 'package:flutter_test/flutter_test.dart';

HeroSheet _hexe({
  List<MagicSpecialAbility> sf = const [],
  List<HeroMerkmal> nachteile = const [],
  List<HeroCompanion> begleiter = const [],
}) => HeroSheet(
  id: 'h',
  name: 'Hexe',
  level: 1,
  apTotal: 1000,
  apSpent: 0,
  apAvailable: 1000,
  attributes: const Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
  magicSpecialAbilities: sf,
  nachteilEintraege: nachteile,
  companions: begleiter,
);

const _kein = HeroMerkmal(
  katalogId: 'dis_kein_vertrauter',
  text: 'Kein Vertrauter',
);

RulesCatalog _katalog({List<String> alias = const []}) => RulesCatalog(
  version: 'test',
  source: 'test',
  talents: const <TalentDef>[],
  spells: const <SpellDef>[],
  weapons: const <WeaponDef>[],
  magicSpecialAbilities: <SpecialAbilityDef>[
    SpecialAbilityDef(
      id: 'magsf_vertrautenbindung',
      name: 'Vertrautenbindung',
      aliasNamen: alias,
    ),
  ],
);

HeroCompanion _vertrauter({
  int maxAsp = 20,
  int apGesamt = 300,
  int apAusgegeben = 0,
  List<HeroCompanionSonderfertigkeit> sf = const [],
  BegleiterTyp typ = BegleiterTyp.vertrauter,
}) => HeroCompanion(
  id: 'v',
  typ: typ,
  maxAsp: maxAsp,
  startAsp: maxAsp,
  apGesamt: apGesamt,
  apAusgegeben: apAusgegeben,
  sonderfertigkeiten: sf,
);

void main() {
  group('Voraussetzungen der Bindung (A1)', () {
    test('mit SF und ohne Nachteil gibt es keine Hinweise', () {
      final held = _hexe(
        sf: const [MagicSpecialAbility(name: 'Vertrautenbindung')],
      );
      expect(vertrautenBindungHinweise(held), isEmpty);
    });

    test('fehlende SF und der Nachteil werden gemeldet', () {
      final hinweise = vertrautenBindungHinweise(
        _hexe(nachteile: const [_kein]),
      );
      expect(hinweise, [
        'Die Sonderfertigkeit Vertrautenbindung fehlt.',
        'Die Hexe hat den Nachteil „Kein Vertrauter“.',
      ]);
    });

    test('mit Katalog zählen auch die alias_namen', () {
      final held = _hexe(
        sf: const [MagicSpecialAbility(name: 'Bindung eines Vertrauten')],
      );
      expect(hatVertrautenbindungSf(held, catalog: _katalog()), isFalse);
      expect(
        hatVertrautenbindungSf(
          held,
          catalog: _katalog(alias: const ['Bindung eines Vertrauten']),
        ),
        isTrue,
      );
    });

    test('Schreibweise und Großschreibung sind egal', () {
      final held = _hexe(
        sf: const [MagicSpecialAbility(name: ' vertrautenbindung ')],
      );
      expect(hatVertrautenbindungSf(held), isTrue);
      expect(hatVertrautenbindungSf(held, catalog: _katalog()), isTrue);
    });
  });

  group('Aurapanzer des Vertrauten (A2)', () {
    test('AE 19 oder zu wenig AP sind offene Voraussetzungen', () {
      expect(vertrautenAurapanzerVoraussetzungen(_vertrauter(maxAsp: 19)), [
        'AE 19, nötig sind 20.',
      ]);
      expect(
        vertrautenAurapanzerVoraussetzungen(
          _vertrauter(apGesamt: 200, apAusgegeben: 100),
        ),
        ['Der Vertraute hat nur 100 AP frei, nötig sind 125 AP.'],
      );
      expect(vertrautenAurapanzerVoraussetzungen(_vertrauter()), isEmpty);
    });

    test('bucht 125 AP des Vertrauten und die Sonderfertigkeit', () {
      final held = bucheVertrautenAurapanzer(
        _hexe(begleiter: [_vertrauter()]),
        begleiterId: 'v',
        erwarteteApAusgegeben: 0,
      );
      final v = held.companions.single;
      expect(v.apAusgegeben, 125);
      expect(v.sonderfertigkeiten.single.katalogId, 'magsf_aurapanzer');
      expect(vertrautenHatAurapanzer(v), isTrue);
      expect(held.apSpent, 0, reason: 'die Hexe zahlt nichts');
    });

    test('ohne Meisterentscheid wirft eine offene Voraussetzung', () {
      final held = _hexe(begleiter: [_vertrauter(maxAsp: 19)]);
      expect(
        () => bucheVertrautenAurapanzer(
          held,
          begleiterId: 'v',
          erwarteteApAusgegeben: 0,
        ),
        throwsStateError,
      );
      final gebucht = bucheVertrautenAurapanzer(
        held,
        begleiterId: 'v',
        erwarteteApAusgegeben: 0,
        meisterentscheid: true,
      );
      expect(gebucht.companions.single.apAusgegeben, 125);
    });

    test('doppelt, Nicht-Vertrauter und geänderter Stand brechen ab', () {
      final schon = _hexe(
        begleiter: [
          _vertrauter(
            sf: const [
              HeroCompanionSonderfertigkeit(
                name: 'Aurapanzer',
                katalogId: 'magsf_aurapanzer',
              ),
            ],
          ),
        ],
      );
      expect(
        () => bucheVertrautenAurapanzer(
          schon,
          begleiterId: 'v',
          erwarteteApAusgegeben: 0,
          meisterentscheid: true,
        ),
        throwsStateError,
      );
      expect(
        vertrautenAurapanzerSperrgrund(_vertrauter(typ: BegleiterTyp.reittier)),
        isNotNull,
      );
      expect(
        () => bucheVertrautenAurapanzer(
          _hexe(begleiter: [_vertrauter()]),
          begleiterId: 'v',
          erwarteteApAusgegeben: 10,
        ),
        throwsStateError,
      );
    });
  });
}
