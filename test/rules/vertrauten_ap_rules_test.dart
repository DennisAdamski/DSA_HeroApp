import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/adventure_rewards_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_ap_rules.dart';
import 'package:flutter_test/flutter_test.dart';

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

HeroCompanion _vertrauter({int? erfasst, int apUebertragen = 0, int? lo}) =>
    HeroCompanion(
      id: 'v',
      typ: BegleiterTyp.vertrauter,
      loyalitaet: lo ?? 15,
      apGesamt: 10,
      vertrautenBindung: VertrautenBindung(
        artId: 'vart_katze',
        abenteuerApErfasst: erfasst,
        apUebertragen: apUebertragen,
      ),
    );

HeroSheet _hexe(
  List<HeroCompanion> begleiter, {
  List<HeroAdventureEntry> abenteuer = const [],
}) => HeroSheet(
  id: 'hexe',
  name: 'Hexe',
  level: 1,
  apTotal: 1000,
  apSpent: 500,
  apAvailable: 500,
  attributes: _attribute,
  companions: begleiter,
  adventures: abenteuer,
);

void main() {
  group('mitVertrautenApAnteil (¼ der Abenteuer-AP, WdZ S. 125)', () {
    test('schreibt exakt ab dem Einrichten gut, auch über Reste', () {
      var held = _hexe([_vertrauter(erfasst: 0)]);
      held = mitVertrautenApAnteil(held, 6);
      expect(held.companions.single.apGesamt, 11);
      held = mitVertrautenApAnteil(held, 6);
      expect(held.companions.single.apGesamt, 13, reason: '⌊12/4⌋ = 3');
      expect(held.companions.single.vertrautenBindung!.abenteuerApErfasst, 12);
    });

    test('eine Rücknahme zieht den Anteil wieder ab', () {
      var held = mitVertrautenApAnteil(_hexe([_vertrauter(erfasst: 0)]), 101);
      held = mitVertrautenApAnteil(held, -101);
      expect(held.companions.single.apGesamt, 10);
      expect(held.companions.single.vertrautenBindung!.abenteuerApErfasst, 0);
    });

    test('ohne eingerichteten Anteil bleibt alles unverändert', () {
      final held = _hexe([_vertrauter()]);
      expect(identical(mitVertrautenApAnteil(held, 100), held), isTrue);
    });

    test('Abenteuerabschluss und Rücknahme buchen den Anteil mit', () {
      final held = _hexe(
        [_vertrauter(erfasst: 0)],
        abenteuer: const [
          HeroAdventureEntry(id: 'a', title: 'Sumpf', apReward: 200),
        ],
      );
      final abgeschlossen = applyAdventureRewards(hero: held, adventureId: 'a');
      expect(abgeschlossen.apTotal, 1200);
      expect(abgeschlossen.companions.single.apGesamt, 60);

      final zurueck = revokeAdventureRewards(
        hero: abgeschlossen,
        adventureId: 'a',
      );
      expect(zurueck.companions.single.apGesamt, 10);
    });
  });

  group('richteVertrautenApAnteilEin', () {
    test('schreibt den Nachtrag einmalig gut', () {
      final held = richteVertrautenApAnteilEin(
        _hexe([_vertrauter()]),
        begleiterId: 'v',
        nachtragAp: 75,
      );
      final v = held.companions.single;
      expect(v.apGesamt, 85);
      expect(v.vertrautenBindung!.abenteuerApErfasst, 0);
      expect(
        () =>
            richteVertrautenApAnteilEin(held, begleiterId: 'v', nachtragAp: 1),
        throwsStateError,
      );
    });

    test('Vorschlag: ¼ der angewendeten Abenteuer- und Reisebericht-AP', () {
      final held = _hexe(
        const [],
        abenteuer: const [
          HeroAdventureEntry(id: 'a', apReward: 300, rewardsApplied: true),
          HeroAdventureEntry(id: 'b', apReward: 500),
        ],
      );
      expect(vertrautenNachtragsvorschlag(held, reiseberichtAp: 102), 100);
    });
  });

  group('uebertrageApAufVertrauten (WdZ S. 124 f.)', () {
    test('bucht bei der Hexe, schreibt gut und hebt LO je 50 AP', () {
      final held = uebertrageApAufVertrauten(
        _hexe([_vertrauter(apUebertragen: 30)]),
        begleiterId: 'v',
        ap: 80,
        erwartetUebertragen: 30,
      );
      final v = held.companions.single;
      expect(held.apSpent, 580);
      expect(v.apGesamt, 90);
      expect(v.vertrautenBindung!.apUebertragen, 110);
      expect(v.loyalitaet, 17, reason: '30 → 110: zwei volle 50er');
    });

    test('Loyalität höchstens 25, eine höhere sinkt nicht', () {
      expect(
        vertrautenLoyalitaetNachUebertragung(
          24,
          altUebertragen: 0,
          neuUebertragen: 500,
        ),
        25,
      );
      expect(
        vertrautenLoyalitaetNachUebertragung(
          27,
          altUebertragen: 0,
          neuUebertragen: 500,
        ),
        27,
      );
    });

    test('geänderter Stand und zu wenig AP werden abgewiesen', () {
      final held = _hexe([_vertrauter(apUebertragen: 30)]);
      expect(
        () => uebertrageApAufVertrauten(
          held,
          begleiterId: 'v',
          ap: 10,
          erwartetUebertragen: 0,
        ),
        throwsStateError,
      );
      expect(
        () => uebertrageApAufVertrauten(
          held,
          begleiterId: 'v',
          ap: 501,
          erwartetUebertragen: 30,
        ),
        throwsStateError,
      );
    });
  });
}
