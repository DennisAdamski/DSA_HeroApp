import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kraeutersuche_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';

// Wildnisproben (Wege des Entdeckers S. 112 f., Zoo Botanica Aventurica
// S. 58–61): gemeinsamer Kern von Kräuter suchen, Nahrung sammeln und Jagd.
// Geländekunde −3 (ähnlich −1), Ortskenntnis −7 und je 3 eingesetzte AsP −1
// verringern die Erschwernis; die TaP* einer gelungenen Probe sind mindestens 1
// und höchstens der TaW. Die Erschwernis geht negiert als Poolmodifikator in
// die Probe.

const List<ProbeTargetValue> _eigenschaften = <ProbeTargetValue>[
  ProbeTargetValue(label: 'KL', value: 12),
  ProbeTargetValue(label: 'IN', value: 12),
  ProbeTargetValue(label: 'FF', value: 12),
];

WildnisProbeEingabe _eingabe({
  int taw = 10,
  int basis = 0,
  Gelaendekunde gelaendekunde = Gelaendekunde.keine,
  bool ortskenntnis = false,
  int asp = 0,
  int situativ = 0,
  List<ProbeTargetValue> eigenschaften = _eigenschaften,
}) => WildnisProbeEingabe(
  taw: taw,
  eigenschaften: eigenschaften,
  basisErschwernis: basis,
  gelaendekunde: gelaendekunde,
  ortskenntnis: ortskenntnis,
  eingesetzteAsp: asp,
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

ResolvedProbeRequest _probe(WildnisProbeEingabe eingabe) =>
    baueWildnisProbe(eingabe, titel: 'Test', regelHinweis: 'Hinweis');

void main() {
  group('wildnisProbenErschwernis', () {
    test('ohne Zu- und Abschläge gilt die Basiserschwernis', () {
      expect(wildnisProbenErschwernis(_eingabe(basis: 4)), 4);
    });

    test('Geländekunde −3 (passend) und −1 (ähnlich)', () {
      expect(
        wildnisProbenErschwernis(
          _eingabe(basis: 4, gelaendekunde: Gelaendekunde.passend),
        ),
        1,
      );
      expect(
        wildnisProbenErschwernis(
          _eingabe(basis: 4, gelaendekunde: Gelaendekunde.aehnlich),
        ),
        3,
      );
    });

    test('Ortskenntnis −7', () {
      expect(
        wildnisProbenErschwernis(_eingabe(basis: 4, ortskenntnis: true)),
        -3,
      );
      expect(kOrtskenntnisErschwernis, -7);
    });

    test('je 3 AsP −1, angebrochene 3 zählen nicht', () {
      expect(wildnisProbenErschwernis(_eingabe(basis: 4, asp: 8)), 2);
      expect(wildnisProbenErschwernis(_eingabe(basis: 4, asp: 2)), 4);
    });

    test('negative AsP erleichtern nichts', () {
      expect(wildnisProbenErschwernis(_eingabe(basis: 4, asp: -6)), 4);
    });

    test('alles zusammen', () {
      expect(
        wildnisProbenErschwernis(
          _eingabe(
            basis: 4,
            gelaendekunde: Gelaendekunde.passend,
            ortskenntnis: true,
            asp: 7,
            situativ: 1,
          ),
        ),
        4 - 3 - 7 - 2 + 1,
      );
    });
  });

  group('baueWildnisProbe', () {
    test('Talentprobe 3W20 mit TaW als Pool und negierter Erschwernis', () {
      final request = _probe(
        _eingabe(taw: 7, basis: 4, gelaendekunde: Gelaendekunde.passend),
      );
      expect(request.type, ProbeType.talent);
      expect(request.title, 'Test');
      expect(request.ruleHint, 'Hinweis');
      expect(request.subtitle, 'KL/IN/FF');
      expect(request.diceSpec.count, 3);
      expect(request.diceSpec.sides, 20);
      expect(request.basePool, 7);
      expect(request.initialSituationalModifier, -1);
    });

    test('verlangt genau drei Eigenschaften', () {
      expect(
        () => _probe(_eingabe(eigenschaften: _eigenschaften.sublist(0, 2))),
        throwsArgumentError,
      );
    });
  });

  group('wildnisTapStern', () {
    test('Misserfolg ergibt 0', () {
      final probe = _wurf(_probe(_eingabe()), <int>[20, 20, 20]);
      expect(probe.success, isFalse);
      expect(wildnisTapStern(probe), 0);
    });

    test('gelungene Probe zählt die übrigen Punkte', () {
      final probe = _wurf(_probe(_eingabe(taw: 10)), <int>[1, 1, 1]);
      expect(probe.success, isTrue);
      expect(wildnisTapStern(probe), 10);
    });

    test('eine Erleichterung hebt die TaP* nicht über den TaW', () {
      final probe = _wurf(_probe(_eingabe(taw: 4, situativ: -10)), <int>[
        1,
        1,
        1,
      ]);
      expect(probe.success, isTrue);
      expect(wildnisTapStern(probe), 4);
    });

    test('eine gelungene Probe zählt mindestens 1 TaP*', () {
      final probe = _wurf(_probe(_eingabe(taw: 0)), <int>[1, 1, 1]);
      expect(probe.success, isTrue);
      expect(wildnisTapStern(probe), 1);
    });
  });

  group('Kräutersuche als Wildnisprobe', () {
    test('Gelände- und Ortskenntnis wirken wie im Kern', () {
      const eingabe = KraeuterSucheEingabe(
        landschaft: Kraeuterlandschaft.dichterWald,
        jahreszeit: Jahreszeit.fruehling,
        taw: 10,
        eigenschaften: _eigenschaften,
        gelaendekunde: Gelaendekunde.passend,
        ortskenntnis: true,
        eingesetzteAsp: 6,
      );
      // Dichter Wald im Frühling +4, Geländekunde −3, Ortskenntnis −7, AsP −2.
      expect(kraeuterProbenErschwernis(eingabe), 4 - 3 - 7 - 2);
      expect(kKraeuterOrtskenntnisErschwernis, kOrtskenntnisErschwernis);
    });

    test('Landschaften kennen ihre Geländekunden', () {
      WildnisLandschaft von(Kraeuterlandschaft l) =>
          kraeuterLandschaftAlsWildnis(l);

      expect(von(Kraeuterlandschaft.dichterWald).gelaende, <Gelaendeart>{
        Gelaendeart.wald,
      });
      expect(von(Kraeuterlandschaft.lichterWald).gelaende, <Gelaendeart>{
        Gelaendeart.wald,
      });
      expect(von(Kraeuterlandschaft.hochgebirge).gelaende, <Gelaendeart>{
        Gelaendeart.gebirge,
      });
      expect(von(Kraeuterlandschaft.dschungel).aehnlicheGelaende, <Gelaendeart>{
        Gelaendeart.maraskan,
      });
      expect(
        von(Kraeuterlandschaft.graslandHeide).aehnlicheGelaende,
        <Gelaendeart>{Gelaendeart.steppe},
      );
      expect(von(Kraeuterlandschaft.graslandHeide).gelaende, isEmpty);
      expect(
        von(Kraeuterlandschaft.suempfeNord).schluessel,
        Kraeuterlandschaft.suempfeNord.name,
      );
      expect(
        von(Kraeuterlandschaft.suempfeSued).bezeichnung,
        'Südliche Sümpfe und Marschen',
      );
    });

    test('jede Landschaft der Kräutertabellen ist abgebildet', () {
      for (final landschaft in Kraeuterlandschaft.values) {
        final wildnis = kraeuterLandschaftAlsWildnis(landschaft);
        expect(wildnis.schluessel, landschaft.name);
      }
    });

    test('das Ergebnis erscheint als Zeilen der Wildnisanzeige', () {
      final probe = _wurf(_probe(_eingabe(taw: 10)), <int>[1, 1, 1]);
      final ergebnis = kraeuterErgebnisAlsWildnis(
        KraeuterSucheErgebnis(
          probe: probe,
          erschwernis: 3,
          tawBeiDauer: 10,
          tapStern: 10,
          funde: const <KraeuterFund>[
            KraeuterFund(
              bezeichnung: 'Donf',
              grundmengen: 2,
              suchschwierigkeit: 6,
            ),
          ],
          restpunkte: 1,
          hinweis: 'Hinweis',
        ),
      );
      expect(ergebnis.erfolg, isTrue);
      expect(ergebnis.erschwernis, 3);
      expect(ergebnis.tapStern, 10);
      expect(ergebnis.hinweis, 'Hinweis');
      expect(ergebnis.zeilen.map((z) => z.titel), <String>[
        'Donf',
        'Restpunkte',
      ]);
      expect(
        ergebnis.zeilen.first.detail,
        '2 Grundmengen · Suchschwierigkeit 6',
      );
    });

    test('Würz- und Konservierungssuche haben eigene Zeilen', () {
      final probe = _wurf(_probe(_eingabe(taw: 10)), <int>[1, 1, 1]);
      final wuerz = kraeuterErgebnisAlsWildnis(
        KraeuterSucheErgebnis(
          probe: probe,
          erschwernis: 0,
          tawBeiDauer: 10,
          tapStern: 10,
          wuerzPunkte: 5,
        ),
      );
      expect(wuerz.zeilen.single.titel, 'Würzkräuter');
      final haltbar = kraeuterErgebnisAlsWildnis(
        KraeuterSucheErgebnis(
          probe: probe,
          erschwernis: 0,
          tawBeiDauer: 10,
          tapStern: 10,
          haltbarkeitTage: 4,
        ),
      );
      expect(haltbar.zeilen.single.detail, '4 Tage zusätzliche Haltbarkeit');
    });
  });
}
