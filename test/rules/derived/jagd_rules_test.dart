import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/jagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';

import '../../ui2/shell/karto_test_support.dart';

// Pirsch- und Ansitzjagd (Wege des Entdeckers S. 107 f.): MU/IN/GE, TaP* =
// Tagesrationen. Modifikatoren nach Waffe (Tabelle oder Reichweite), Region,
// Wetter, Beute, Geländekunde, Ortskenntnis, AsP und Jagdglück; Scharf- und
// Meisterschütze gleichen nur die übrigen Zuschläge aus, nie die Waffe
// (Beispiel S. 108: Meisterschütze mit Kurzbogen höchstens TaW − 2 TaP*, auch
// bei Sturm).

const List<ProbeTargetValue> _eigenschaften = <ProbeTargetValue>[
  ProbeTargetValue(label: 'MU', value: 12),
  ProbeTargetValue(label: 'IN', value: 12),
  ProbeTargetValue(label: 'GE', value: 12),
];

JagdWaffe get _kurzbogen => jagdWaffeAusTabelle('tabelle:kurzbogen')!;

JagdEingabe _eingabe({
  Jagdart art = Jagdart.pirsch,
  Wildnisregion region = Wildnisregion.dschungel,
  int taw = 10,
  JagdWaffe? waffe,
  Jagdwetter wetter = Jagdwetter.ruhig,
  bool schmackhaft = false,
  Schuetzenstufe schuetze = Schuetzenstufe.keine,
  Gelaendekunde gelaendekunde = Gelaendekunde.keine,
  bool ortskenntnis = false,
  int asp = 0,
  bool jagdglueck = false,
  int situativ = 0,
}) => JagdEingabe(
  art: art,
  region: region,
  taw: taw,
  eigenschaften: _eigenschaften,
  waffe: waffe ?? _kurzbogen,
  wetter: wetter,
  nurSchmackhaft: schmackhaft,
  schuetze: schuetze,
  gelaendekunde: gelaendekunde,
  ortskenntnis: ortskenntnis,
  eingesetzteAsp: asp,
  jagdglueck: jagdglueck,
  situativeErschwernis: situativ,
);

ProbeResult _wurf(ResolvedProbeRequest request, List<int> augen) =>
    evaluateProbe(
      request,
      ProbeRollInput(
        mode: ProbeRollMode.manual,
        diceValues: augen,
        situationalModifier: request.initialSituationalModifier,
        specializationApplied: false,
      ),
    );

MainWeaponSlot _fernwaffe({
  String id = 'w1',
  String name = 'Kurzbogen',
  String weaponType = '',
  String talentId = 'tal_bogen',
  List<String> reichweiten = const <String>['5', '15', '25', '40', '60'],
}) => MainWeaponSlot(
  id: id,
  name: name,
  weaponType: weaponType,
  talentId: talentId,
  combatType: WeaponCombatType.ranged,
  rangedProfile: RangedWeaponProfile(
    distanceBands: <RangedDistanceBand>[
      for (final r in reichweiten) RangedDistanceBand(label: r),
    ],
  ),
);

void main() {
  group('Talente und Arten', () {
    test('Pirsch mit Schleichen, Ansitz mit Sich Verstecken', () {
      expect(jagdTalente(Jagdart.pirsch, 'tal_bogen'), <String>[
        'tal_wildnisleben',
        'tal_tierkunde',
        'tal_faehrtensuchen',
        'tal_schleichen',
        'tal_bogen',
      ]);
      expect(
        jagdTalente(Jagdart.ansitz, 'tal_armbrust')[3],
        'tal_sich_verstecken',
      );
      expect(Jagdart.pirsch.dauerMinuten, 60);
      expect(Jagdart.ansitz.dauerMinuten, 90);
    });
  });

  group('Waffen', () {
    test('Tabelle nach WdE S. 107 f.', () {
      int mod(String s) => jagdWaffeAusTabelle('tabelle:$s')!.modifikator;
      expect(mod('wurfmesser'), 10);
      expect(mod('wurfbeil'), 8);
      expect(mod('schleuder'), 4);
      expect(mod('kurzbogen'), 2);
      expect(mod('kompositbogen'), 1);
      expect(mod('langbogen'), -2);
      expect(mod('elfenbogen'), -3);
      expect(jagdWaffeAusTabelle('tabelle:kurzbogen')!.talentId, 'tal_bogen');
    });

    test('Reichweite persönlicher Waffen, Wurfwaffen +2', () {
      expect(jagdWaffenModifikatorNachReichweite(15, 'tal_bogen'), 8);
      expect(jagdWaffenModifikatorNachReichweite(60, 'tal_bogen'), 2);
      expect(jagdWaffenModifikatorNachReichweite(100, 'tal_bogen'), 0);
      expect(jagdWaffenModifikatorNachReichweite(200, 'tal_bogen'), -2);
      expect(jagdWaffenModifikatorNachReichweite(250, 'tal_bogen'), -3);
      expect(jagdWaffenModifikatorNachReichweite(15, 'tal_wurfmesser'), 10);
    });

    test('eine Waffe des Helden übernimmt den Tabellenwert ihres Namens', () {
      final waffe = jagdWaffeAusSlot(_fernwaffe())!;
      expect(waffe.schluessel, 'held:w1');
      expect(waffe.modifikator, 2);
      expect(waffe.herkunft, 'wie Kurzbogen');
      expect(waffe.verbrauch, JagdVerbrauch.pfeile);
    });

    test('die Waffenart zählt vor dem Namen', () {
      final waffe = jagdWaffeAusSlot(
        _fernwaffe(name: 'Vaters Bogen', weaponType: 'Langbogen'),
      )!;
      expect(waffe.name, 'Vaters Bogen');
      expect(waffe.modifikator, -2);
    });

    test('Katalogname „Schwere Armbrust“ ist die Windenarmbrust', () {
      final waffe = jagdWaffeAusSlot(
        _fernwaffe(name: 'Schwere Armbrust', talentId: 'tal_armbrust'),
      )!;
      expect(waffe.modifikator, -2);
    });

    test('unbekannte Waffen rechnen nach der letzten Reichweite', () {
      final waffe = jagdWaffeAusSlot(
        _fernwaffe(
          name: 'Selbstbau',
          reichweiten: const <String>['10', '20', '30', '50', '80'],
        ),
      )!;
      expect(jagdWaffenReichweite(_fernwaffe()), 60);
      expect(waffe.modifikator, 1);
      expect(waffe.herkunft, 'Reichweite 80 Schritt');
    });

    test(
      'ohne Reichweite und Tabelle, ohne Talent oder im Nahkampf nichts',
      () {
        expect(
          jagdWaffeAusSlot(
            _fernwaffe(
              name: 'Selbstbau',
              reichweiten: const <String>['Distanz 1', 'Distanz 2'],
            ),
          ),
          isNull,
        );
        expect(jagdWaffeAusSlot(_fernwaffe(talentId: '')), isNull);
        expect(
          jagdWaffeAusSlot(
            const MainWeaponSlot(name: 'Kurzbogen', talentId: 'tal_bogen'),
          ),
          isNull,
        );
      },
    );

    test('der Held liefert seine Fernkampfwaffen', () {
      final held = testHero().copyWith(
        combatConfig: CombatConfig(
          weapons: <MainWeaponSlot>[
            const MainWeaponSlot(id: 'n', name: 'Schwert', talentId: 'tal_x'),
            _fernwaffe(),
          ],
        ),
      );
      expect(jagdWaffenDesHelden(held).map((w) => w.schluessel), <String>[
        'held:w1',
      ]);
    });
  });

  group('Schützen-Sonderfertigkeiten', () {
    test('werden je Fernkampftalent erkannt', () {
      final held = testHero().copyWith(
        combatConfig: const CombatConfig(
          specialRules: CombatSpecialRules(
            activeManeuvers: <String>['man_scharfschuetze::tal_bogen'],
          ),
        ),
      );
      expect(
        schuetzenstufeDesHelden(held, talentId: 'tal_bogen', catalog: null),
        Schuetzenstufe.scharfschuetze,
      );
      expect(
        schuetzenstufeDesHelden(held, talentId: 'tal_armbrust', catalog: null),
        Schuetzenstufe.keine,
      );
    });

    test('Meisterschütze zählt als beide', () {
      final held = testHero().copyWith(
        combatConfig: const CombatConfig(
          specialRules: CombatSpecialRules(
            activeManeuvers: <String>[
              'man_scharfschuetze::tal_bogen',
              'man_meisterschuetze::tal_bogen',
            ],
          ),
        ),
      );
      expect(
        schuetzenstufeDesHelden(held, talentId: 'tal_bogen', catalog: null),
        Schuetzenstufe.meisterschuetze,
      );
      expect(Schuetzenstufe.meisterschuetze.jagdErleichterung, -7);
    });
  });

  group('Erschwernis', () {
    test('Region nach WdE S. 108', () {
      expect(jagdRegionsErschwernis(Wildnisregion.lichterWald), -4);
      expect(jagdRegionsErschwernis(Wildnisregion.dichterWald), -2);
      expect(jagdRegionsErschwernis(Wildnisregion.maraskanDschungel), 0);
      expect(jagdRegionsErschwernis(Wildnisregion.tundra), 2);
      expect(jagdRegionsErschwernis(Wildnisregion.hochgebirge), 4);
      expect(jagdRegionsErschwernis(Wildnisregion.ewigesEis), 12);
    });

    test('ohne Schützen-SF wird linear summiert', () {
      final e = berechneJagdErschwernis(
        _eingabe(
          region: Wildnisregion.lichterWald,
          wetter: Jagdwetter.starkerWind,
          schmackhaft: true,
          gelaendekunde: Gelaendekunde.passend,
          ortskenntnis: true,
          asp: 6,
          jagdglueck: true,
          situativ: 1,
        ),
      );
      // Kurzbogen +2, Wald −4, Wind +4, schmackhaft +2, GK −3, OK −7,
      // AsP −2, Jagdglück −5, situativ +1.
      expect(e.gesamt, 2 - 4 + 4 + 2 - 3 - 7 - 2 - 5 + 1);
    });

    test('Beispiel WdE: Meisterschütze, Kurzbogen, Sturm', () {
      final ruhig = berechneJagdErschwernis(
        _eingabe(schuetze: Schuetzenstufe.meisterschuetze),
      );
      expect(ruhig.gesamt, 2);
      expect(ruhig.schuetze, 0);
      expect(ruhig.schuetzeVerfallen, 7);

      final sturm = berechneJagdErschwernis(
        _eingabe(
          schuetze: Schuetzenstufe.meisterschuetze,
          wetter: Jagdwetter.sturm,
        ),
      );
      expect(sturm.gesamt, 2);
      expect(sturm.schuetze, -6);
      expect(sturm.schuetzeVerfallen, 1);

      // Höchstens TaW − 2 TaP*: TaW 10, Pool 10 − 2.
      final probe = _wurf(
        baueJagdProbe(
          _eingabe(
            schuetze: Schuetzenstufe.meisterschuetze,
            wetter: Jagdwetter.sturm,
          ),
        ),
        <int>[1, 1, 1],
      );
      expect(wildnisTapStern(probe), 8);
    });

    test('Schützen-SF gleichen keine Erleichterung aus', () {
      final e = berechneJagdErschwernis(
        _eingabe(
          region: Wildnisregion.lichterWald,
          wetter: Jagdwetter.sturm,
          schuetze: Schuetzenstufe.scharfschuetze,
        ),
      );
      // Sturm +6 wird um 3 gesenkt, der Wald (−4) bleibt Erleichterung.
      expect(e.zuschlaege, 6);
      expect(e.erleichterungen, -4);
      expect(e.schuetze, -3);
      expect(e.gesamt, 2 + 6 - 4 - 3);
    });

    test('eine Erleichterung der Waffe bleibt erhalten', () {
      final e = berechneJagdErschwernis(
        _eingabe(waffe: jagdWaffeAusTabelle('tabelle:elfenbogen')),
      );
      expect(e.gesamt, -3);
    });
  });

  group('Auswertung', () {
    test('TaP* sind Tagesrationen, dazu der Verbrauch', () {
      final eingabe = _eingabe(art: Jagdart.ansitz, taw: 6);
      final request = baueJagdProbe(eingabe);
      expect(request.title, 'Ansitzjagd');
      expect(request.subtitle, 'MU/IN/GE');
      expect(request.initialSituationalModifier, -2);
      final ergebnis = werteJagdAus(eingabe, _wurf(request, <int>[1, 1, 1]));
      expect(ergebnis.tapStern, 4);
      expect(ergebnis.zeilen.single.titel, '4 Tagesrationen');
      expect(ergebnis.hinweis, contains('3–5 auf 2W20'));
    });

    test('Misserfolg bringt keine Ration', () {
      final eingabe = _eingabe();
      final ergebnis = werteJagdAus(
        eingabe,
        _wurf(baueJagdProbe(eingabe), <int>[20, 20, 20]),
      );
      expect(ergebnis.erfolg, isFalse);
      expect(ergebnis.zeilen, isEmpty);
    });
  });
}
