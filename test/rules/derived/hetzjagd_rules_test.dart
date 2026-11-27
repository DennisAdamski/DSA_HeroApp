import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hetzjagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/jagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_ausbeute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';

import '../../ui2/shell/karto_test_support.dart';

// Hetzjagd nach Wege des Entdeckers S. 109 f.: TaW mit doppeltem Reiten,
// eigene Waffen- und Regionstabellen, Grenze der Schützen-SF, Verbrauch nach
// der Hetzjagd-Tabelle und Nichtwiederholbarkeit.

class _FesteWuerfel implements DiceRoller {
  _FesteWuerfel(this.werte);

  final List<int> werte;
  var _naechster = 0;

  @override
  int rollDie(int sides) => werte[_naechster++];
}

const List<ProbeTargetValue> _eigenschaften = <ProbeTargetValue>[
  ProbeTargetValue(label: 'MU', value: 12),
  ProbeTargetValue(label: 'IN', value: 12),
  ProbeTargetValue(label: 'GE', value: 12),
];

HetzjagdEingabe _eingabe({
  Wildnisregion region = Wildnisregion.graslandHeide,
  String waffe = 'hetz:kurzbogen',
  Schuetzenstufe schuetze = Schuetzenstufe.keine,
  bool schnellladen = false,
  Jagdwetter wetter = Jagdwetter.ruhig,
  int reitenTaw = 0,
  bool zuPferd = false,
  int jagdtier = 0,
  Reitersonderfertigkeit reiter = Reitersonderfertigkeit.keine,
}) => HetzjagdEingabe(
  region: region,
  taw: 10,
  eigenschaften: _eigenschaften,
  waffe: hetzjagdWaffeAusTabelle(waffe)!,
  schuetze: schuetze,
  schnellladen: schnellladen,
  wetter: wetter,
  reitenTaw: reitenTaw,
  zuPferd: zuPferd,
  jagdtier: jagdtier,
  reiter: reiter,
);

void main() {
  group('TaW und Voraussetzung', () {
    test('Reiten zählt doppelt, der Deckel nimmt das niedrigste Talent', () {
      Map<String, HeroTalentEntry> talente(int reiten) => {
        'tal_wildnisleben': const HeroTalentEntry(talentValue: 8),
        'tal_tierkunde': const HeroTalentEntry(talentValue: 6),
        'tal_reiten': HeroTalentEntry(talentValue: reiten),
        'tal_bogen': const HeroTalentEntry(talentValue: 9),
      };
      // (8 + 6 + 2 × 9 + 9) / 5 = 8,2 → 8.
      expect(
        computeMetaTalentBaseTaw(
          talentEntries: talente(9),
          componentTalentIds: hetzjagdTalente('tal_bogen'),
        ),
        8,
      );
      // (8 + 6 + 2 × 2 + 9) / 5 = 5,4 → 5, Deckel 2 × 2 = 4.
      expect(
        computeMetaTalentBaseTaw(
          talentEntries: talente(2),
          componentTalentIds: hetzjagdTalente('tal_bogen'),
        ),
        4,
      );
    });

    test('Tierkunde und Reiten müssen aktiviert sein', () {
      final ohne = testHero('h');
      expect(hetzjagdVoraussetzung(ohne), contains('Tierkunde und Reiten'));
      final mit = ohne.copyWith(
        talents: const <String, HeroTalentEntry>{
          'tal_tierkunde': HeroTalentEntry(talentValue: 0),
          'tal_reiten': HeroTalentEntry(talentValue: 0),
        },
      );
      expect(hetzjagdVoraussetzung(mit), isNull);
      final nurReiten = ohne.copyWith(
        talents: const <String, HeroTalentEntry>{
          'tal_reiten': HeroTalentEntry(talentValue: 5),
        },
      );
      expect(hetzjagdVoraussetzung(nurReiten), contains('Tierkunde'));
      expect(hetzjagdVoraussetzung(nurReiten), isNot(contains('Reiten')));
    });
  });

  group('Tabellen', () {
    test('Region nach der Hetzjagd-Tabelle', () {
      expect(hetzjagdRegionsErschwernis(Wildnisregion.lichterWald), -4);
      expect(hetzjagdRegionsErschwernis(Wildnisregion.tundra), 2);
      expect(hetzjagdRegionsErschwernis(Wildnisregion.dschungel), 4);
      expect(hetzjagdRegionsErschwernis(Wildnisregion.maraskanDschungel), 6);
      expect(hetzjagdRegionsErschwernis(Wildnisregion.suempfeSued), 8);
      expect(hetzjagdRegionsErschwernis(Wildnisregion.ewigesEis), 12);
    });

    test('Waffen der Tabelle', () {
      int mod(String s) => hetzjagdWaffeAusTabelle('hetz:$s')!.modifikator;
      expect(mod('efferdbart'), 10);
      expect(mod('speer'), 8);
      expect(mod('balestrina'), 8);
      expect(mod('kurzbogen'), 2);
      expect(mod('elfenbogen'), 1);
      // Langbogen und Wurfmesser stehen nicht in der Hetz-Tabelle.
      expect(hetzjagdWaffeAusTabelle('hetz:langbogen'), isNull);
      expect(hetzjagdWaffeAusTabelle('hetz:wurfmesser'), isNull);
    });

    test('persönliche Waffe: Reichweite plus Ladezeit oder +6', () {
      expect(hetzjagdReichweitenModifikator(15), 6);
      expect(hetzjagdReichweitenModifikator(40), 2);
      expect(hetzjagdReichweitenModifikator(60), 0);
      expect(hetzjagdReichweitenModifikator(80), -1);
      expect(hetzjagdReichweitenModifikator(81), -2);

      MainWeaponSlot slot(String talent, {int ladezeit = 0}) => MainWeaponSlot(
        id: 'w',
        name: 'Eigene Waffe',
        talentId: talent,
        combatType: WeaponCombatType.ranged,
        rangedProfile: RangedWeaponProfile(
          reloadTime: ladezeit,
          distanceBands: const <RangedDistanceBand>[
            RangedDistanceBand(label: '30 Schritt'),
          ],
        ),
      );
      // Armbrust, 30 Schritt (+3), Ladezeit 4.
      final armbrust = hetzjagdWaffeAusSlot(slot('tal_armbrust', ladezeit: 4))!;
      expect(armbrust.modifikator, 7);
      expect(armbrust.verbrauch, JagdVerbrauch.pfeileHetz);
      // Wurfspeer-Talent: +6 fürs Aufheben, Speerverlust 3–6.
      final speer = hetzjagdWaffeAusSlot(slot('tal_wurfspeere'))!;
      expect(speer.modifikator, 9);
      expect(speer.verbrauch, JagdVerbrauch.speereHetz);
      // Dolche gehen zu leicht verloren.
      expect(hetzjagdWaffeAusSlot(slot('tal_wurfmesser')), isNull);
    });
  });

  group('Erschwernis', () {
    test('Waffe, Region und Wetter addieren sich', () {
      // Kurzbogen +2, Grasland −4, Sturm +6.
      final e = berechneHetzjagdErschwernis(_eingabe(wetter: Jagdwetter.sturm));
      expect(e.gesamt, 4);
    });

    test('Scharf- und Meisterschütze gleichen nur Zuschläge aus', () {
      // Dschungel +4, Meisterschütze −3, Kurzbogen +2 bleibt.
      expect(
        berechneHetzjagdErschwernis(
          _eingabe(
            region: Wildnisregion.dschungel,
            schuetze: Schuetzenstufe.meisterschuetze,
          ),
        ).gesamt,
        3,
      );
      // Grasland −4 liefert keinen Zuschlag: die SF verfällt ganz.
      final verfall = berechneHetzjagdErschwernis(
        _eingabe(schuetze: Schuetzenstufe.meisterschuetze, schnellladen: true),
      );
      expect(verfall.schuetze, 0);
      expect(verfall.schuetzeVerfallen, 5);
      expect(verfall.gesamt, -2);
    });

    test('Schnellladen zählt mit den Schützen-SF', () {
      // Dschungel +4, Scharfschütze −1, Schnellladen −2: wirksam −3.
      final e = berechneHetzjagdErschwernis(
        _eingabe(
          region: Wildnisregion.dschungel,
          schuetze: Schuetzenstufe.scharfschuetze,
          schnellladen: true,
        ),
      );
      expect(e.schuetze, -3);
      expect(e.gesamt, 3);
    });

    test(
      'Jagd zu Pferde zählt nur mit Reiten 7 im Grasland und Verwandten',
      () {
        int gesamt(Wildnisregion r, int reiten) => berechneHetzjagdErschwernis(
          _eingabe(region: r, reitenTaw: reiten, zuPferd: true),
        ).gesamt;
        // Kurzbogen +2, Grasland −4, zu Pferde −3.
        expect(gesamt(Wildnisregion.graslandHeide, 7), -5);
        expect(gesamt(Wildnisregion.graslandHeide, 6), -2);
        // Dichter Wald: Kurzbogen +2, Region +2, kein Abzug.
        expect(gesamt(Wildnisregion.dichterWald, 12), 4);
      },
    );

    test('Reiter-SF, Jagdtier und Jagdglück', () {
      // Kurzbogen +2, Grasland −4, Reiter-SF −7, Jagdtier −5.
      expect(
        berechneHetzjagdErschwernis(
          _eingabe(
            reiter: Reitersonderfertigkeit.berittenerSchuetze,
            jagdtier: 5,
          ),
        ).gesamt,
        -14,
      );
      // Ein Jagdtier wirkt höchstens mit −7.
      expect(
        berechneHetzjagdErschwernis(_eingabe(jagdtier: 20)).gesamt,
        2 - 4 - 7,
      );
    });
  });

  group('Auswertung', () {
    test(
      'Hetzjagd meldet Wildbret, Verlust nach Hetztabelle, keine Wiederholung',
      () {
        final eingabe = _eingabe();
        final probe = evaluateProbe(
          baueHetzjagdProbe(eingabe),
          ProbeRollInput(
            mode: ProbeRollMode.manual,
            diceValues: const <int>[1, 1, 1],
            situationalModifier: baueHetzjagdProbe(eingabe)
                .initialSituationalModifier,
            specializationApplied: false,
          ),
        );
        final ergebnis = werteHetzjagdAus(eingabe, probe);
        expect(ergebnis.rationen!.gegenstand, 'Wildbret (frisch)');
        expect(ergebnis.rationen!.taetigkeit, 'Hetzjagd');
        expect(ergebnis.rationen!.anzahl, ergebnis.tapStern);
        expect(ergebnis.munition!.verbrauch, JagdVerbrauch.pfeileHetz);
        expect(ergebnis.hinweis, contains('nicht wiederholen'));
        expect(ergebnis.hinweis, contains('1 auf 1W20'));
      },
    );

    test('Pfeile gehen bei der Hetzjagd nur bei einer 1 auf 1W20 verloren', () {
      final verlust = wuerfleGeschossverlust(
        JagdVerbrauch.pfeileHetz,
        schuesse: 4,
        roller: _FesteWuerfel(<int>[1, 2, 20, 1]),
      );
      expect(verlust.wuerfe, <int>[1, 2, 20, 1]);
      expect(verlust.verloren, 2);
      expect(JagdVerbrauch.pfeileHetz.verlustBereich, '1');
    });

    test('Speere und Wurfwaffen nach Hetztabelle (3–6, 3–8)', () {
      final speere = wuerfleGeschossverlust(
        JagdVerbrauch.speereHetz,
        schuesse: 3,
        // 2 + 4 = 6 (verloren), 3 + 4 = 7 (bleibt), 1 + 1 = 2 (bleibt).
        roller: _FesteWuerfel(<int>[2, 4, 3, 4, 1, 1]),
      );
      expect(speere.verloren, 1);
      final wurf = wuerfleGeschossverlust(
        JagdVerbrauch.wurfwaffenHetz,
        schuesse: 2,
        // 4 + 4 = 8 (verloren), 5 + 4 = 9 (bleibt).
        roller: _FesteWuerfel(<int>[4, 4, 5, 4]),
      );
      expect(wurf.verloren, 1);
      expect(JagdVerbrauch.speereHetz.verlustBereich, '3–6');
    });

    test('die Pirschtabelle bleibt unverändert', () {
      expect(JagdVerbrauch.pfeile.verlustBereich, '3–5');
      expect(JagdVerbrauch.pfeile.beiHetzjagd, JagdVerbrauch.pfeileHetz);
      expect(JagdVerbrauch.kugeln.beiHetzjagd, JagdVerbrauch.kugeln);
    });
  });
}
