import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/jagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/nahrung_sammeln_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_ausbeute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';

import '../../ui2/shell/karto_test_support.dart';

// Ausbeute der Wildnisproben: Tagesrationen fürs Inventar (eine Ration etwa
// ein Stein, WdE S. 123) und Geschossverlust der Jagd (WdE S. 108: Pfeile bei
// 3–5 auf 2W20, Speere 3–7, Wurfwaffen 3–9, Schleudersteine 1W6+1).

/// Würfel mit festen Ergebnissen in der angegebenen Reihenfolge.
class _FesteWuerfel implements DiceRoller {
  _FesteWuerfel(this.werte);

  final List<int> werte;
  var _naechster = 0;

  @override
  int rollDie(int sides) => werte[_naechster++];
}

const WildnisPosten _wildbret = WildnisPosten(
  gegenstand: 'Wildbret (frisch)',
  anzahl: 3,
  taetigkeit: 'Pirschjagd',
  beschreibung: 'Frisch und unbehandelt.',
);

const List<ProbeTargetValue> _eigenschaften = <ProbeTargetValue>[
  ProbeTargetValue(label: 'MU', value: 12),
  ProbeTargetValue(label: 'IN', value: 12),
  ProbeTargetValue(label: 'GE', value: 12),
];

ProbeResult _gelungen(ResolvedProbeRequest request) => evaluateProbe(
  request,
  ProbeRollInput(
    mode: ProbeRollMode.manual,
    diceValues: const <int>[1, 1, 1],
    situationalModifier: request.initialSituationalModifier,
    specializationApplied: false,
  ),
);

MainWeaponSlot _bogen({int pfeile = 10}) => MainWeaponSlot(
  id: 'w1',
  name: 'Kurzbogen',
  talentId: 'tal_bogen',
  combatType: WeaponCombatType.ranged,
  rangedProfile: RangedWeaponProfile(
    projectiles: <RangedProjectile>[
      RangedProjectile(id: 'p1', name: 'Jagdpfeile', count: pfeile),
    ],
    selectedProjectileIndex: 0,
  ),
);

void main() {
  group('Rationen ins Inventar', () {
    test(
      'legen einen Verbrauchseintrag mit Menge, Gewicht und Herkunft an',
      () {
        final held = mitWildnisPosten(
          testHero(),
          _wildbret,
          datum: '5. Praios 1043 BF',
        );
        final eintrag = held.inventoryEntries.single;
        expect(eintrag.gegenstand, 'Wildbret (frisch)');
        expect(eintrag.menge, 3);
        expect(eintrag.anzahl, '3');
        expect(eintrag.itemType, InventoryItemType.verbrauchsgegenstand);
        expect(eintrag.source, InventoryItemSource.manuell);
        expect(eintrag.gewichtGramm, kWildnisRationGewichtGramm);
        expect(eintrag.herkunft, 'Pirschjagd am 5. Praios 1043 BF');
        expect(eintrag.beschreibung, 'Frisch und unbehandelt.');
      },
    );

    test(
      'derselbe Tag und dieselbe Tätigkeit stapeln, ein anderer Tag nicht',
      () {
        var held = mitWildnisPosten(testHero(), _wildbret, datum: '5. Praios');
        held = mitWildnisPosten(held, _wildbret, datum: '5. Praios');
        expect(held.inventoryEntries.single.menge, 6);
        held = mitWildnisPosten(held, _wildbret, datum: '6. Praios');
        expect(held.inventoryEntries, hasLength(2));
      },
    );

    test('ein Eintrag ohne klare Menge wird nicht erweitert', () {
      final held = testHero().copyWith(
        inventoryEntries: const <HeroInventoryEntry>[
          HeroInventoryEntry(
            gegenstand: 'Wildbret (frisch)',
            anzahl: 'einige',
            itemType: InventoryItemType.verbrauchsgegenstand,
            herkunft: 'Pirschjagd',
            beschreibung: 'Frisch und unbehandelt.',
            gewichtGramm: kWildnisRationGewichtGramm,
          ),
        ],
      );
      final neu = mitWildnisPosten(held, _wildbret);
      expect(neu.inventoryEntries, hasLength(2));
      expect(neu.inventoryEntries.first.anzahl, 'einige');
    });

    test('ohne Rationen bleibt der Held derselbe', () {
      final held = testHero();
      const keine = WildnisPosten(
        gegenstand: 'Fisch (frisch)',
        anzahl: 0,
        taetigkeit: 'Angeln',
      );
      expect(identical(mitWildnisPosten(held, keine), held), isTrue);
    });

    test('ohne Datum nennt die Herkunft nur die Tätigkeit', () {
      expect(wildnisRationenHerkunft(_wildbret), 'Pirschjagd');
    });
  });

  group('Ergebnisse tragen die Buchung', () {
    test('Jagd: Wildbret je TaP*, Munition mit Slot der eigenen Waffe', () {
      final waffe = jagdWaffeAusSlot(
        _bogen().copyWith(
          rangedProfile: const RangedWeaponProfile(
            distanceBands: <RangedDistanceBand>[
              RangedDistanceBand(label: '60'),
            ],
          ),
        ),
      )!;
      final eingabe = JagdEingabe(
        art: Jagdart.pirsch,
        region: Wildnisregion.dschungel,
        taw: 6,
        eigenschaften: _eigenschaften,
        waffe: waffe,
      );
      final ergebnis = werteJagdAus(eingabe, _gelungen(baueJagdProbe(eingabe)));
      expect(ergebnis.rationen!.gegenstand, kWildbretGegenstand);
      expect(ergebnis.rationen!.anzahl, 4);
      expect(ergebnis.rationen!.taetigkeit, 'Pirschjagd');
      expect(ergebnis.rationen!.beschreibung, contains('2 Stunden'));
      expect(ergebnis.munition!.waffenSlotId, 'w1');
      expect(ergebnis.munition!.verbrauch, JagdVerbrauch.pfeile);
    });

    test('Jagd mit Tabellenwaffe kennt keinen Slot', () {
      final eingabe = JagdEingabe(
        art: Jagdart.ansitz,
        region: Wildnisregion.dichterWald,
        taw: 6,
        eigenschaften: _eigenschaften,
        waffe: jagdWaffeAusTabelle('tabelle:schleuder')!,
      );
      final ergebnis = werteJagdAus(eingabe, _gelungen(baueJagdProbe(eingabe)));
      expect(ergebnis.munition!.waffenSlotId, isNull);
      expect(ergebnis.munition!.verbrauch, JagdVerbrauch.kugeln);
    });

    test('Misserfolg bringt keine Rationen, aber Munition', () {
      final eingabe = JagdEingabe(
        art: Jagdart.pirsch,
        region: Wildnisregion.dschungel,
        taw: 6,
        eigenschaften: _eigenschaften,
        waffe: jagdWaffeAusTabelle('tabelle:kurzbogen')!,
      );
      final request = baueJagdProbe(eingabe);
      final ergebnis = werteJagdAus(
        eingabe,
        evaluateProbe(
          request,
          ProbeRollInput(
            mode: ProbeRollMode.manual,
            diceValues: const <int>[20, 20, 20],
            situationalModifier: request.initialSituationalModifier,
            specializationApplied: false,
          ),
        ),
      );
      expect(ergebnis.rationen, isNull);
      expect(ergebnis.munition, isNotNull);
    });

    test('Nahrung sammeln bucht nach Haltbarkeit', () {
      const eingabe = NahrungSammelnEingabe(
        region: Wildnisregion.dschungel,
        taw: 7,
        eigenschaften: _eigenschaften,
        haltbarkeitsziel: Haltbarkeitsstufe.zwei,
      );
      final ergebnis = werteNahrungSammelnAus(
        eingabe,
        _gelungen(baueNahrungSammelnProbe(eingabe)),
      );
      // 7 TaP*: 1 für Stufe 2, 6 bleiben: 1 + 2 = 3 Rationen.
      expect(ergebnis.rationen!.anzahl, 3);
      expect(
        ergebnis.rationen!.gegenstand,
        'Gesammelte Nahrung (Haltbarkeit 2)',
      );
      expect(ergebnis.rationen!.beschreibung, contains('halbiert'));
      expect(ergebnis.rationen!.beschreibung, contains('Giftwurf'));
      expect(ergebnis.munition, isNull);
    });

    test('Haltbarkeit von Fleisch und Fisch nach Klima', () {
      expect(
        frischfleischHaltbarkeit(Wildnisregion.suempfeNord),
        contains('2 Stunden'),
      );
      expect(
        frischfleischHaltbarkeit(Wildnisregion.wueste),
        contains('4 Stunden'),
      );
      expect(
        frischfleischHaltbarkeit(Wildnisregion.tundra),
        contains('9 Stunden'),
      );
      expect(
        frischfleischHaltbarkeit(Wildnisregion.dichterWald),
        contains('6 Stunden'),
      );
      expect(
        frischfleischHaltbarkeit(Wildnisregion.ewigesEis),
        contains('Woche'),
      );
    });
  });

  group('Geschossverlust', () {
    test('Pfeile: je Schuss 2W20, verloren bei 3 bis 5', () {
      final v = wuerfleGeschossverlust(
        JagdVerbrauch.pfeile,
        schuesse: 3,
        roller: _FesteWuerfel(<int>[1, 2, 1, 1, 3, 3]),
      );
      // 3 (verloren), 2 (Doppel-1 zählt nicht), 6 (bleibt).
      expect(v.wuerfe, <int>[3, 2, 6]);
      expect(v.verloren, 1);
    });

    test('Speere bis 7, Wurfwaffen bis 9', () {
      expect(
        wuerfleGeschossverlust(
          JagdVerbrauch.speere,
          schuesse: 1,
          roller: _FesteWuerfel(<int>[3, 4]),
        ).verloren,
        1,
      );
      expect(
        wuerfleGeschossverlust(
          JagdVerbrauch.wurfwaffen,
          schuesse: 2,
          roller: _FesteWuerfel(<int>[4, 5, 5, 5]),
        ).verloren,
        1,
      );
    });

    test('Schleudersteine: 1W6+1 unabhängig von den Schüssen', () {
      final v = wuerfleGeschossverlust(
        JagdVerbrauch.kugeln,
        schuesse: 5,
        roller: _FesteWuerfel(<int>[4]),
      );
      expect(v.wuerfe, <int>[4]);
      expect(v.verloren, 5);
      expect(JagdVerbrauch.kugeln.jeSchuss, isFalse);
    });

    test('Abbuchen zählt vom gespeicherten Bestand und endet bei 0', () {
      final angezeigt = _bogen();
      final geschoss = angezeigt.rangedProfile.projectiles.single;
      final gespeichert = CombatConfig(
        weapons: <MainWeaponSlot>[_bogen(pfeile: 2)],
      );
      final neu = mitJagdGeschossverlust(
        gespeichert,
        waffe: angezeigt,
        geschoss: geschoss,
        verloren: 5,
      );
      expect(neu.weaponSlots.single.rangedProfile.projectiles.single.count, 0);
      final eins = mitJagdGeschossverlust(
        CombatConfig(weapons: <MainWeaponSlot>[angezeigt]),
        waffe: angezeigt,
        geschoss: geschoss,
        verloren: 1,
      );
      expect(eins.weaponSlots.single.rangedProfile.projectiles.single.count, 9);
    });

    test('ohne Verlust oder ohne Bestand bleibt die Konfiguration', () {
      final config = CombatConfig(weapons: <MainWeaponSlot>[_bogen(pfeile: 0)]);
      final waffe = _bogen();
      final geschoss = waffe.rangedProfile.projectiles.single;
      expect(
        identical(
          mitJagdGeschossverlust(
            config,
            waffe: waffe,
            geschoss: geschoss,
            verloren: 0,
          ),
          config,
        ),
        isTrue,
      );
      expect(
        identical(
          mitJagdGeschossverlust(
            config,
            waffe: waffe,
            geschoss: geschoss,
            verloren: 2,
          ),
          config,
        ),
        isTrue,
      );
    });

    test('Waffe und gewähltes Geschoss des Helden', () {
      final held = testHero().copyWith(
        combatConfig: CombatConfig(weapons: <MainWeaponSlot>[_bogen()]),
      );
      final treffer = jagdWaffeUndGeschoss(held, 'w1')!;
      expect(treffer.geschoss!.name, 'Jagdpfeile');
      expect(jagdWaffeUndGeschoss(held, null), isNull);
      expect(jagdWaffeUndGeschoss(held, 'fehlt'), isNull);
    });
  });
  group('Mehrere Funde', () {
    test('mitWildnisFunden bucht alle Posten in einem Bogen und stapelt', () {
      const donf = WildnisPosten(
        gegenstand: 'Donf',
        anzahl: 2,
        taetigkeit: 'Kräutersuche',
        gewichtGramm: 0,
      );
      const wurz = WildnisPosten(
        gegenstand: 'Würzkräuter',
        anzahl: 3,
        taetigkeit: 'Kräutersuche',
        gewichtGramm: 0,
      );
      final held = mitWildnisFunden(testHero(), <WildnisPosten>[
        donf,
        wurz,
      ], datum: '5. Praios 1043 BF');
      expect(held.inventoryEntries, hasLength(2));
      final eintrag = held.inventoryEntries.firstWhere(
        (e) => e.gegenstand == 'Donf',
      );
      expect(eintrag.menge, 2);
      expect(eintrag.herkunft, 'Kräutersuche am 5. Praios 1043 BF');
      expect(eintrag.gewichtGramm, 0);

      // Zweiter Fund desselben Krauts am selben Tag wächst die Menge.
      final mehr = mitWildnisFunden(held, <WildnisPosten>[
        donf,
      ], datum: '5. Praios 1043 BF');
      expect(mehr.inventoryEntries, hasLength(2));
      expect(
        mehr.inventoryEntries.firstWhere((e) => e.gegenstand == 'Donf').menge,
        4,
      );
    });

    test('ohne Posten bleibt der Held unverändert', () {
      final held = testHero();
      expect(
        identical(mitWildnisFunden(held, const <WildnisPosten>[]), held),
        isTrue,
      );
    });
  });
}
