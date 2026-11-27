import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/nahrung_sammeln_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';

// Nahrung sammeln (Wege des Entdeckers S. 112 f.): MU/IN/FF, eine Stunde,
// jede weitere Viertelstunde −1, Region nach Tabelle; eine gelungene Probe
// bringt eine nicht haltbare Tagesration und je 3 TaP* eine weitere, oder je
// TaP* eine Haltbarkeitsstufe (S. 122). Ohne passende Geländekunde droht ein
// verdeckter Giftwurf (19–20, Dschungel 18–20, Maraskan 16–20).

const List<ProbeTargetValue> _eigenschaften = <ProbeTargetValue>[
  ProbeTargetValue(label: 'MU', value: 12),
  ProbeTargetValue(label: 'IN', value: 12),
  ProbeTargetValue(label: 'FF', value: 12),
];

NahrungSammelnEingabe _eingabe({
  Wildnisregion region = Wildnisregion.dichterWald,
  int taw = 10,
  int dauer = 60,
  Gelaendekunde gelaendekunde = Gelaendekunde.keine,
  Haltbarkeitsstufe ziel = Haltbarkeitsstufe.eins,
}) => NahrungSammelnEingabe(
  region: region,
  taw: taw,
  eigenschaften: _eigenschaften,
  dauerMinuten: dauer,
  gelaendekunde: gelaendekunde,
  haltbarkeitsziel: ziel,
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

void main() {
  group('Erschwernis', () {
    test('Region nach WdE S. 113', () {
      expect(nahrungSammelnRegionsErschwernis(Wildnisregion.lichterWald), -6);
      expect(nahrungSammelnRegionsErschwernis(Wildnisregion.graslandHeide), -4);
      expect(nahrungSammelnRegionsErschwernis(Wildnisregion.gebirge), -2);
      expect(nahrungSammelnRegionsErschwernis(Wildnisregion.dichterWald), 0);
      expect(nahrungSammelnRegionsErschwernis(Wildnisregion.tundra), 2);
      expect(nahrungSammelnRegionsErschwernis(Wildnisregion.suempfeNord), 4);
      expect(nahrungSammelnRegionsErschwernis(Wildnisregion.hochgebirge), 6);
      expect(nahrungSammelnRegionsErschwernis(Wildnisregion.ewigesEis), 12);
    });

    test('jede volle Viertelstunde über einer Stunde senkt um 1', () {
      expect(nahrungSammelnDauerErschwernis(60), 0);
      expect(nahrungSammelnDauerErschwernis(74), 0);
      expect(nahrungSammelnDauerErschwernis(75), -1);
      expect(nahrungSammelnDauerErschwernis(120), -4);
      expect(nahrungSammelnDauerErschwernis(240), -12);
      expect(() => nahrungSammelnDauerErschwernis(45), throwsArgumentError);
    });

    test('Region, Dauer und Geländekunde zusammen', () {
      expect(
        nahrungSammelnErschwernis(
          _eingabe(
            region: Wildnisregion.suempfeNord,
            dauer: 90,
            gelaendekunde: Gelaendekunde.passend,
          ),
        ),
        4 - 2 - 3,
      );
    });

    test('Probe auf MU/IN/FF mit dem TaW als Pool', () {
      final request = baueNahrungSammelnProbe(
        _eingabe(region: Wildnisregion.lichterWald, taw: 7),
      );
      expect(request.title, 'Nahrung sammeln');
      expect(request.subtitle, 'MU/IN/FF');
      expect(request.basePool, 7);
      expect(request.initialSituationalModifier, 6);
    });
  });

  group('Ausbeute', () {
    test('eine Ration bei Erfolg, je 3 TaP* eine weitere', () {
      expect(nahrungSammelnAusbeute(0).rationen, 0);
      expect(nahrungSammelnAusbeute(1).rationen, 1);
      expect(nahrungSammelnAusbeute(2).rationen, 1);
      expect(nahrungSammelnAusbeute(3).rationen, 2);
      expect(nahrungSammelnAusbeute(7).rationen, 3);
      expect(nahrungSammelnAusbeute(7).restpunkte, 1);
      expect(nahrungSammelnAusbeute(7).haltbarkeit, Haltbarkeitsstufe.eins);
    });

    test(
      'Haltbarkeit kostet je Stufe einen TaP*, der Rest geht in Rationen',
      () {
        final ausbeute = nahrungSammelnAusbeute(
          7,
          ziel: Haltbarkeitsstufe.drei,
        );
        // 2 TaP* heben auf Stufe 3, 5 bleiben: 1 + 1 Ration, 2 Restpunkte.
        expect(ausbeute.haltbarkeit, Haltbarkeitsstufe.drei);
        expect(ausbeute.rationen, 2);
        expect(ausbeute.restpunkte, 2);
      },
    );

    test('zu wenige TaP* erreichen nur einen Teil der Haltbarkeit', () {
      final ausbeute = nahrungSammelnAusbeute(2, ziel: Haltbarkeitsstufe.vier);
      expect(ausbeute.haltbarkeit, Haltbarkeitsstufe.drei);
      expect(ausbeute.rationen, 1);
      expect(ausbeute.restpunkte, 0);
    });

    test('Auswertung nennt Rationen, Haltbarkeit und den Giftwurf', () {
      final eingabe = _eingabe(region: Wildnisregion.dschungel, taw: 6);
      final probe = _wurf(baueNahrungSammelnProbe(eingabe), <int>[1, 1, 1]);
      final ergebnis = werteNahrungSammelnAus(eingabe, probe);
      expect(ergebnis.tapStern, 6);
      expect(ergebnis.zeilen.first.titel, '3 Tagesrationen');
      expect(ergebnis.zeilen.first.detail, startsWith('Haltbarkeit 1'));
      expect(ergebnis.hinweis, contains('18–20'));
      expect(ergebnis.hinweis, contains('halbiert'));
    });

    test('mit passender Geländekunde entfällt der Giftwurf', () {
      final eingabe = _eingabe(gelaendekunde: Gelaendekunde.passend);
      final probe = _wurf(baueNahrungSammelnProbe(eingabe), <int>[1, 1, 1]);
      expect(werteNahrungSammelnAus(eingabe, probe).hinweis, isEmpty);
    });

    test('Misserfolg bringt nichts und keinen Hinweis', () {
      final eingabe = _eingabe();
      final probe = _wurf(baueNahrungSammelnProbe(eingabe), <int>[20, 20, 20]);
      final ergebnis = werteNahrungSammelnAus(eingabe, probe);
      expect(ergebnis.erfolg, isFalse);
      expect(ergebnis.zeilen, isEmpty);
      expect(ergebnis.hinweis, isEmpty);
    });

    test('Giftwurf nach Region', () {
      expect(nahrungSammelnGiftwurf(Wildnisregion.lichterWald).von, 19);
      expect(nahrungSammelnGiftwurf(Wildnisregion.dschungel).von, 18);
      expect(nahrungSammelnGiftwurf(Wildnisregion.maraskanDschungel).von, 16);
    });

    test('Ackerbau ersetzt in Feldern die Pflanzenkunde', () {
      expect(nahrungSammelnTalente(), kNahrungSammelnTalente);
      expect(nahrungSammelnTalente(ackerbau: true), <String>[
        'tal_wildnisleben',
        'tal_sinnesschaerfe',
        'tal_ackerbau',
      ]);
    });
  });

  group('Regionen', () {
    test('teilen ihre Schlüssel mit den Kräuterlandschaften', () {
      for (final region in Wildnisregion.values) {
        if (region == Wildnisregion.ewigesEis) {
          expect(region.kraeuterlandschaft, isNull);
        } else {
          expect(region.kraeuterlandschaft?.name, region.name);
        }
      }
    });

    test('Ewiges Eis verlangt Eiskundig', () {
      expect(
        wildnisRegionAlsLandschaft(Wildnisregion.ewigesEis).gelaende,
        <Gelaendeart>{Gelaendeart.eis},
      );
      expect(
        wildnisRegionAlsLandschaft(Wildnisregion.dichterWald).gelaende,
        <Gelaendeart>{Gelaendeart.wald},
      );
    });

    test('Orte schlagen Regionen vor, Eiswüsten das Ewige Eis', () {
      OrtEintrag region(String unterart) =>
          OrtEintrag(name: 'X', art: OrtArt.region, unterart: unterart);
      expect(wildnisRegionenFuerOrt(region('Eiswüste')), <Wildnisregion>[
        Wildnisregion.ewigesEis,
      ]);
      expect(wildnisRegionenFuerOrt(region('Gletscher')), <Wildnisregion>[
        Wildnisregion.hochgebirge,
        Wildnisregion.ewigesEis,
      ]);
      expect(wildnisRegionenFuerOrt(region('Wald')), <Wildnisregion>[
        Wildnisregion.dichterWald,
        Wildnisregion.lichterWald,
      ]);
      expect(wildnisRegionenFuerOrt(region('See')), isEmpty);
    });
  });
}
