import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kraeutersuche_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';

/// Würfler mit festgelegter Wurffolge; die Wurfseiten werden mitgeschrieben.
class _Folge implements DiceRoller {
  _Folge(this._werte);

  final List<int> _werte;
  final List<int> seiten = <int>[];
  int _naechster = 0;

  @override
  int rollDie(int sides) {
    seiten.add(sides);
    final wert = _werte[_naechster++];
    expect(wert, inInclusiveRange(1, sides), reason: 'Wurf $_naechster');
    return wert;
  }
}

const List<ProbeTargetValue> _eigenschaften = <ProbeTargetValue>[
  ProbeTargetValue(label: 'KL', value: 12),
  ProbeTargetValue(label: 'IN', value: 12),
  ProbeTargetValue(label: 'FF', value: 12),
];

KraeuterSucheEingabe _eingabe({
  Kraeuterlandschaft landschaft = Kraeuterlandschaft.dichterWald,
  Jahreszeit jahreszeit = Jahreszeit.sommer,
  int taw = 10,
  int dauerStunden = 1,
  Gelaendekunde gelaendekunde = Gelaendekunde.keine,
  bool ortskenntnis = false,
  int asp = 0,
  int situativ = 0,
  KraeuterSuchmodus modus = KraeuterSuchmodus.beliebig,
  String ziel = '',
  Set<String> ausgeschlossen = const <String>{},
  List<ProbeTargetValue> eigenschaften = _eigenschaften,
  String monat = '',
  ErntezeitModus erntezeit = ErntezeitModus.nurErntezeit,
}) => KraeuterSucheEingabe(
  landschaft: landschaft,
  jahreszeit: jahreszeit,
  taw: taw,
  eigenschaften: eigenschaften,
  dauerStunden: dauerStunden,
  gelaendekunde: gelaendekunde,
  ortskenntnis: ortskenntnis,
  eingesetzteAsp: asp,
  situativeErschwernis: situativ,
  modus: modus,
  zielKraut: ziel,
  ausgeschlosseneKraeuter: ausgeschlossen,
  monat: monat,
  erntezeitModus: erntezeit,
);

KrautEintrag _kraut(
  String name,
  int bestimmung,
  Kraeuterhaeufigkeit haeufigkeit, {
  Kraeuterlandschaft landschaft = Kraeuterlandschaft.dichterWald,
}) => KrautEintrag(
  name: name,
  bestimmung: bestimmung,
  vorkommen: <KrautVorkommen>[
    KrautVorkommen(landschaft: landschaft, haeufigkeit: haeufigkeit),
  ],
);

/// A: Suchschwierigkeit 3 (häufig), B: Suchschwierigkeit 9 (selten).
final KraeuterKatalog _katalog = KraeuterKatalog(
  kraeuter: <KrautEintrag>[
    _kraut('A', 1, Kraeuterhaeufigkeit.haeufig),
    _kraut('B', 1, Kraeuterhaeufigkeit.selten),
    _kraut(
      'Fern',
      1,
      Kraeuterhaeufigkeit.haeufig,
      landschaft: Kraeuterlandschaft.wueste,
    ),
  ],
);

void main() {
  group('jahreszeitFuerMonat', () {
    test('ordnet je drei Monate ab Sonnenwende und Tagundnachtgleiche zu', () {
      const erwartet = <String, Jahreszeit>{
        'praios': Jahreszeit.sommer,
        'rondra': Jahreszeit.sommer,
        'efferd': Jahreszeit.sommer,
        'travia': Jahreszeit.herbst,
        'boron': Jahreszeit.herbst,
        'hesinde': Jahreszeit.herbst,
        'firun': Jahreszeit.winter,
        'tsa': Jahreszeit.winter,
        'phex': Jahreszeit.winter,
        'peraine': Jahreszeit.fruehling,
        'ingerimm': Jahreszeit.fruehling,
        'rahja': Jahreszeit.fruehling,
        'namenlose_tage': Jahreszeit.fruehling,
      };
      erwartet.forEach((monat, jahreszeit) {
        expect(jahreszeitFuerMonat(monat), jahreszeit, reason: monat);
      });
    });

    test('versteht Anzeigenamen und lehnt Unbekanntes ab', () {
      expect(jahreszeitFuerMonat('Firun'), Jahreszeit.winter);
      expect(jahreszeitFuerMonat(''), isNull);
      expect(jahreszeitFuerMonat('Januar'), isNull);
    });
  });

  group('Landschaft und Jahreszeit', () {
    test('Erschwernis entspricht den Tabellen der Landschaften', () {
      int e(Kraeuterlandschaft l, Jahreszeit j) =>
          kraeuterLandschaftsErschwernis(l, j);
      expect(e(Kraeuterlandschaft.dichterWald, Jahreszeit.sommer), 0);
      expect(e(Kraeuterlandschaft.dichterWald, Jahreszeit.herbst), 0);
      expect(e(Kraeuterlandschaft.dichterWald, Jahreszeit.winter), 6);
      expect(e(Kraeuterlandschaft.dichterWald, Jahreszeit.fruehling), 4);
      expect(e(Kraeuterlandschaft.lichterWald, Jahreszeit.sommer), -6);
      expect(e(Kraeuterlandschaft.lichterWald, Jahreszeit.winter), 0);
      expect(e(Kraeuterlandschaft.lichterWald, Jahreszeit.fruehling), -2);
      expect(e(Kraeuterlandschaft.dschungel, Jahreszeit.winter), -2);
      expect(e(Kraeuterlandschaft.suempfeNord, Jahreszeit.sommer), 4);
      expect(e(Kraeuterlandschaft.suempfeNord, Jahreszeit.winter), 8);
      expect(e(Kraeuterlandschaft.suempfeNord, Jahreszeit.fruehling), 6);
      expect(e(Kraeuterlandschaft.tundra, Jahreszeit.herbst), 2);
      expect(e(Kraeuterlandschaft.graslandHeide, Jahreszeit.sommer), -4);
      expect(e(Kraeuterlandschaft.graslandHeide, Jahreszeit.winter), 2);
      expect(e(Kraeuterlandschaft.gebirge, Jahreszeit.fruehling), 2);
      expect(e(Kraeuterlandschaft.hochgebirge, Jahreszeit.winter), 12);
      expect(e(Kraeuterlandschaft.hochgebirge, Jahreszeit.fruehling), 10);
      expect(e(Kraeuterlandschaft.wueste, Jahreszeit.sommer), 12);
    });

    test('Jede Landschaft und Jahreszeit hat einen Wert', () {
      for (final l in Kraeuterlandschaft.values) {
        for (final j in Jahreszeit.values) {
          expect(() => kraeuterLandschaftsErschwernis(l, j), returnsNormally);
        }
      }
    });

    test('Pauschale Suchschwierigkeit je Landschaft', () {
      expect(
        kraeuterPauschalSuchschwierigkeit(Kraeuterlandschaft.dichterWald),
        6,
      );
      expect(
        kraeuterPauschalSuchschwierigkeit(Kraeuterlandschaft.lichterWald),
        2,
      );
      expect(
        kraeuterPauschalSuchschwierigkeit(Kraeuterlandschaft.dschungel),
        8,
      );
      expect(kraeuterPauschalSuchschwierigkeit(Kraeuterlandschaft.wueste), 6);
    });
  });

  group('Suchschwierigkeit', () {
    test('ist Bestimmung plus Häufigkeitsaufschlag', () {
      final kraut = _kraut('X', 6, Kraeuterhaeufigkeit.gelegentlich);
      expect(kraeuterSuchschwierigkeit(kraut, kraut.vorkommen.single), 10);
      final satuarien = _kraut('Y', -2, Kraeuterhaeufigkeit.selten);
      expect(
        kraeuterSuchschwierigkeit(satuarien, satuarien.vorkommen.single),
        6,
      );
    });

    test('Aufschläge nach WdE S. 113', () {
      expect(
        <int>[for (final h in Kraeuterhaeufigkeit.values) h.aufschlag],
        <int>[1, 2, 4, 8, 16],
      );
    });

    test(
      'Grundmengen: TaP* durch die halbe Suchschwierigkeit, aufgerundet',
      () {
        expect(kraeuterGrundmengen(10, 14), 2); // 10 / 7 = 1,43
        expect(kraeuterGrundmengen(7, 14), 1);
        expect(kraeuterGrundmengen(8, 14), 2); // 8 / 7 = 1,14
        expect(kraeuterGrundmengen(10, 6), 4); // 10 / 3 = 3,33
        expect(kraeuterGrundmengen(1, 20), 1);
      },
    );

    test('Suchschwierigkeit unter 1 zählt als 1', () {
      expect(kraeuterGrundmengen(4, -2), 8);
      expect(kraeuterGrundmengen(4, 0), 8);
    });
  });

  group('TaW nach Suchdauer', () {
    test('eine Stunde lässt den TaW, zwei Stunden steigern um die Hälfte', () {
      expect(kraeuterSuchenTawBeiDauer(10, 1), 10);
      expect(kraeuterSuchenTawBeiDauer(10, 2), 15);
      expect(kraeuterSuchenTawBeiDauer(7, 2), 11); // 10,5 nach oben
      expect(kraeuterSuchenTawBeiDauer(0, 2), 0);
    });

    test('andere Dauern sind ein Fehler', () {
      expect(() => kraeuterSuchenTawBeiDauer(10, 3), throwsArgumentError);
      expect(() => kraeuterSuchenTawBeiDauer(10, 0), throwsArgumentError);
    });
  });

  group('Probenerschwernis', () {
    test('summiert Landschaft, Geländekunde, Ortskenntnis, AsP, Meister', () {
      final eingabe = _eingabe(
        landschaft: Kraeuterlandschaft.lichterWald,
        gelaendekunde: Gelaendekunde.passend,
        ortskenntnis: true,
        asp: 6,
        situativ: 2,
      );
      // -6 (Lichter Wald, Sommer) -3 -7 -2 +2
      expect(kraeuterProbenErschwernis(eingabe), -16);
    });

    test('ähnliche Geländekunde und AsP unter 3 zählen nach Regel', () {
      expect(
        kraeuterProbenErschwernis(
          _eingabe(gelaendekunde: Gelaendekunde.aehnlich, asp: 2),
        ),
        -1,
      );
      expect(kraeuterProbenErschwernis(_eingabe(asp: 8)), -2);
    });

    test(
      'die Probe erhält das Negativ der Erschwernis als Poolmodifikator',
      () {
        final request = baueKraeutersucheProbe(
          _eingabe(jahreszeit: Jahreszeit.winter, dauerStunden: 2),
        );
        expect(request.type, ProbeType.talent);
        expect(request.diceSpec.label, '3W20');
        expect(request.basePool, 15);
        expect(request.initialSituationalModifier, -6);
        expect(request.subtitle, 'KL/IN/FF');
      },
    );

    test('verlangt genau drei Eigenschaften', () {
      expect(
        () => baueKraeutersucheProbe(
          _eingabe(eigenschaften: _eigenschaften.take(2).toList()),
        ),
        throwsArgumentError,
      );
    });
  });

  group('TaP*', () {
    ProbeResult wurf(KraeuterSucheEingabe eingabe, List<int> w) {
      final request = baueKraeutersucheProbe(eingabe);
      return evaluateProbe(
        request,
        createDigitalProbeRollInput(request, roller: _Folge(w)),
      );
    }

    test('übrige Punkte der gelungenen Probe', () {
      expect(kraeuterTapStern(wurf(_eingabe(), <int>[5, 5, 5])), 10);
      // 14 gegen 12 ist 2 drüber: 10 - 2 = 8
      expect(kraeuterTapStern(wurf(_eingabe(), <int>[14, 5, 5])), 8);
    });

    test('Erschwernis senkt den Pool', () {
      expect(
        kraeuterTapStern(
          wurf(_eingabe(jahreszeit: Jahreszeit.winter), <int>[5, 5, 5]),
        ),
        4,
      );
    });

    test('Misserfolg ergibt 0 TaP*', () {
      expect(kraeuterTapStern(wurf(_eingabe(), <int>[20, 20, 5])), 0);
      expect(kraeuterTapStern(wurf(_eingabe(taw: 2), <int>[20, 17, 5])), 0);
    });

    test('Gelungene Probe ergibt mindestens 1 TaP*', () {
      // Pool 10, Überschreitung genau 10 -> 0 übrig, aber gelungen.
      expect(kraeuterTapStern(wurf(_eingabe(), <int>[12, 12, 12])), 10);
      expect(kraeuterTapStern(wurf(_eingabe(taw: 3), <int>[15, 12, 12])), 1);
      // Doppel-1 gelingt immer, auch ohne Rest.
      expect(kraeuterTapStern(wurf(_eingabe(taw: 2), <int>[1, 1, 20])), 1);
    });

    test('negativer Pool senkt die Eigenschaften, Erfolg bleibt möglich', () {
      final eingabe = _eingabe(taw: 2, jahreszeit: Jahreszeit.winter);
      final probe = wurf(eingabe, <int>[5, 5, 5]);
      expect(probe.appliedAttributePenalty, -4);
      expect(kraeuterTapStern(probe), 1);
    });
  });

  group('moeglicheKraeuter', () {
    test('liefert nur die Landschaft, häufigste zuerst', () {
      final kandidaten = moeglicheKraeuter(
        _katalog,
        Kraeuterlandschaft.dichterWald,
      );
      expect(kandidaten.map((k) => k.kraut.name), <String>['A', 'B']);
      expect(kandidaten.map((k) => k.suchschwierigkeit), <int>[3, 9]);
    });

    test('lässt ausgeschlossene Kräuter weg', () {
      final kandidaten = moeglicheKraeuter(
        _katalog,
        Kraeuterlandschaft.dichterWald,
        ausgeschlossen: <String>{'A'},
      );
      expect(kandidaten.map((k) => k.kraut.name), <String>['B']);
    });

    test('mehrere Vorkommen derselben Landschaft erscheinen mehrfach', () {
      const donf = KrautEintrag(
        name: 'Donf',
        bestimmung: 6,
        vorkommen: <KrautVorkommen>[
          KrautVorkommen(
            landschaft: Kraeuterlandschaft.dschungel,
            haeufigkeit: Kraeuterhaeufigkeit.sehrSelten,
          ),
          KrautVorkommen(
            landschaft: Kraeuterlandschaft.dschungel,
            haeufigkeit: Kraeuterhaeufigkeit.selten,
          ),
        ],
      );
      final kandidaten = moeglicheKraeuter(
        const KraeuterKatalog(kraeuter: <KrautEintrag>[donf]),
        Kraeuterlandschaft.dschungel,
      );
      expect(kandidaten.map((k) => k.suchschwierigkeit), <int>[14, 22]);
    });
  });

  group('kraeuterSuchziel', () {
    test('liefert Kraut, Vorkommen und Suchschwierigkeit', () {
      final ziel = kraeuterSuchziel(
        _eingabe(modus: KraeuterSuchmodus.gezielt, ziel: 'B'),
        _katalog,
      )!;
      expect(ziel.bezeichnung, 'B');
      expect(ziel.suchschwierigkeit, 9);
      expect(ziel.kandidat!.vorkommen.haeufigkeit, Kraeuterhaeufigkeit.selten);
    });

    test('ohne Kraut gilt die Pauschale, ohne Vorkommen nichts', () {
      final pauschal = kraeuterSuchziel(
        _eingabe(modus: KraeuterSuchmodus.gezielt),
        _katalog,
      )!;
      expect(pauschal.suchschwierigkeit, 6);
      expect(pauschal.kandidat, isNull);
      expect(
        kraeuterSuchziel(
          _eingabe(modus: KraeuterSuchmodus.gezielt, ziel: 'Fern'),
          _katalog,
        ),
        isNull,
      );
    });

    test('andere Suchziele haben keine Suchschwierigkeit', () {
      for (final modus in <KraeuterSuchmodus>[
        KraeuterSuchmodus.beliebig,
        KraeuterSuchmodus.wuerz,
        KraeuterSuchmodus.konservierung,
      ]) {
        expect(kraeuterSuchziel(_eingabe(modus: modus), _katalog), isNull);
      }
    });

    test('mehrere Vorkommen: das leichteste zählt', () {
      const katalog = KraeuterKatalog(
        kraeuter: <KrautEintrag>[
          KrautEintrag(
            name: 'Donf',
            bestimmung: 6,
            vorkommen: <KrautVorkommen>[
              KrautVorkommen(
                landschaft: Kraeuterlandschaft.dichterWald,
                haeufigkeit: Kraeuterhaeufigkeit.sehrSelten,
              ),
              KrautVorkommen(
                landschaft: Kraeuterlandschaft.dichterWald,
                haeufigkeit: Kraeuterhaeufigkeit.selten,
              ),
            ],
          ),
        ],
      );
      final eingabe = kraeuterEingabeMitZiel(
        _eingabe(modus: KraeuterSuchmodus.gezielt, ziel: 'Donf'),
        katalog,
      );
      expect(eingabe.zielSuchschwierigkeit, 14);
      expect(kraeuterProbenErschwernis(eingabe), 14);
    });
  });

  group('fuehreKraeutersucheDurch', () {
    test('würfelt 3W20 und liefert Probe, Erschwernis und TaW', () {
      final roller = _Folge(<int>[5, 5, 5]);
      final ergebnis = fuehreKraeutersucheDurch(
        _eingabe(modus: KraeuterSuchmodus.wuerz, jahreszeit: Jahreszeit.winter),
        _katalog,
        roller: roller,
      );
      expect(roller.seiten, <int>[20, 20, 20]);
      expect(ergebnis.probe.diceValues, <int>[5, 5, 5]);
      expect(ergebnis.erschwernis, 6);
      expect(ergebnis.tawBeiDauer, 10);
      expect(ergebnis.tapStern, 4);
      expect(ergebnis.erfolg, isTrue);
    });

    group('beliebig', () {
      test('zieht die Suchschwierigkeit ab, bis nichts mehr passt', () {
        // TaP* 10: A (3) passt (2*3 <= 10) -> Rest 7; wieder -> Rest 4; Ende.
        final ergebnis = fuehreKraeutersucheDurch(
          _eingabe(),
          _katalog,
          roller: _Folge(<int>[5, 5, 5, 1, 1]),
        );
        expect(ergebnis.tapStern, 10);
        expect(ergebnis.funde.map((f) => f.bezeichnung), <String>['A']);
        expect(ergebnis.funde.single.grundmengen, 2);
        expect(ergebnis.funde.single.suchschwierigkeit, 3);
        expect(ergebnis.restpunkte, 4);
      });

      test('wählt gewichtet nach Häufigkeit über den Würfler', () {
        // TaP* 20: A (Gewicht 8) und B (Gewicht 2, 2*9 <= 20) stehen zur Wahl.
        // Wurf 9 von 10 fällt auf B (Rest 11). Dann passt nur noch A (B: 18).
        final roller = _Folge(<int>[5, 5, 5, 9, 1, 1]);
        final ergebnis = fuehreKraeutersucheDurch(
          _eingabe(taw: 20),
          _katalog,
          roller: roller,
        );
        expect(roller.seiten, <int>[20, 20, 20, 10, 8, 8]);
        expect(ergebnis.funde.map((f) => f.bezeichnung), <String>['B', 'A']);
        expect(ergebnis.funde.map((f) => f.grundmengen), <int>[1, 2]);
        expect(ergebnis.restpunkte, 5);
      });

      test('ohne passendes Kraut bleiben alle Punkte übrig', () {
        final ergebnis = fuehreKraeutersucheDurch(
          _eingabe(taw: 4),
          _katalog,
          roller: _Folge(<int>[5, 5, 5]),
        );
        expect(ergebnis.funde, isEmpty);
        expect(ergebnis.restpunkte, 4);
      });

      test('Misserfolg findet nichts', () {
        final ergebnis = fuehreKraeutersucheDurch(
          _eingabe(),
          _katalog,
          roller: _Folge(<int>[20, 20, 5]),
        );
        expect(ergebnis.erfolg, isFalse);
        expect(ergebnis.tapStern, 0);
        expect(ergebnis.funde, isEmpty);
      });

      test('berücksichtigt ausgeschlossene Kräuter', () {
        final ergebnis = fuehreKraeutersucheDurch(
          _eingabe(ausgeschlossen: <String>{'A'}),
          _katalog,
          roller: _Folge(<int>[5, 5, 5]),
        );
        // Nur B (Suchschwierigkeit 9, braucht 18 TaP*): bei 10 nichts.
        expect(ergebnis.funde, isEmpty);
      });
    });

    group('gezielt', () {
      test('rechnet Grundmengen aus der Suchschwierigkeit des Krauts', () {
        final ergebnis = fuehreKraeutersucheDurch(
          _eingabe(modus: KraeuterSuchmodus.gezielt, ziel: 'B', taw: 19),
          _katalog,
          roller: _Folge(<int>[5, 5, 5]),
        );
        // Erschwernis 9 (Suchschwierigkeit), TaP* 19 - 9 = 10:
        // ceil(10 / 4,5) = 3
        expect(ergebnis.erschwernis, 9);
        expect(ergebnis.tapStern, 10);
        expect(ergebnis.funde.single.bezeichnung, 'B');
        expect(ergebnis.funde.single.grundmengen, 3);
        expect(ergebnis.funde.single.suchschwierigkeit, 9);
      });

      test('Heilwirkung ohne Pflanze nutzt die Pauschale der Landschaft', () {
        final ergebnis = fuehreKraeutersucheDurch(
          _eingabe(modus: KraeuterSuchmodus.gezielt, taw: 16),
          _katalog,
          roller: _Folge(<int>[5, 5, 5]),
        );
        // Dichter Wald: 6 erschwert die Probe, TaP* 10 -> ceil(10 / 3) = 4
        expect(ergebnis.erschwernis, 6);
        expect(ergebnis.funde.single.grundmengen, 4);
        expect(ergebnis.funde.single.kraut, isNull);
      });

      test('Kraut außerhalb der Landschaft ergibt Hinweis statt Fund', () {
        final ergebnis = fuehreKraeutersucheDurch(
          _eingabe(modus: KraeuterSuchmodus.gezielt, ziel: 'Fern'),
          _katalog,
          roller: _Folge(<int>[5, 5, 5]),
        );
        expect(ergebnis.funde, isEmpty);
        expect(ergebnis.hinweis, contains('Fern'));
        expect(ergebnis.erschwernis, 0);
      });

      test('Misserfolg ergibt keine Grundmengen', () {
        final ergebnis = fuehreKraeutersucheDurch(
          _eingabe(modus: KraeuterSuchmodus.gezielt, ziel: 'A'),
          _katalog,
          roller: _Folge(<int>[20, 20, 20]),
        );
        expect(ergebnis.funde, isEmpty);
        expect(ergebnis.hinweis, isEmpty);
      });
    });

    test('Würzkräuter: halbe TaP* als Erleichterung', () {
      final ergebnis = fuehreKraeutersucheDurch(
        _eingabe(modus: KraeuterSuchmodus.wuerz),
        _katalog,
        roller: _Folge(<int>[5, 5, 5]),
      );
      expect(ergebnis.wuerzPunkte, 5);
      expect(kWuerzkraeuterMaxErleichterungProKochenProbe, 3);
      final ungerade = fuehreKraeutersucheDurch(
        _eingabe(modus: KraeuterSuchmodus.wuerz, taw: 3),
        _katalog,
        roller: _Folge(<int>[5, 5, 5]),
      );
      expect(ungerade.wuerzPunkte, 2);
    });

    test('Konservierung: je TaP* ein Tag', () {
      final ergebnis = fuehreKraeutersucheDurch(
        _eingabe(modus: KraeuterSuchmodus.konservierung),
        _katalog,
        roller: _Folge(<int>[5, 5, 5]),
      );
      expect(ergebnis.haltbarkeitTage, 10);
    });

    test('zwei Stunden steigern den Pool um die Hälfte', () {
      final ergebnis = fuehreKraeutersucheDurch(
        _eingabe(dauerStunden: 2, modus: KraeuterSuchmodus.konservierung),
        _katalog,
        roller: _Folge(<int>[5, 5, 5]),
      );
      expect(ergebnis.tawBeiDauer, 15);
      expect(ergebnis.haltbarkeitTage, 15);
    });
  });

  group('Vorschau', () {
    test('Verteilung summiert sich zu 1', () {
      final verteilung = kraeuterTapVerteilung(_eingabe());
      final summe = verteilung.values.fold<double>(0, (a, b) => a + b);
      expect(summe, closeTo(1, 1e-9));
      expect(verteilung.keys.every((tap) => tap >= 0), isTrue);
    });

    test('Bei sehr hohen Werten bleibt nur der Doppel-20-Patzer', () {
      final verteilung = kraeuterTapVerteilung(
        _eingabe(
          taw: 30,
          eigenschaften: const <ProbeTargetValue>[
            ProbeTargetValue(label: 'KL', value: 20),
            ProbeTargetValue(label: 'IN', value: 20),
            ProbeTargetValue(label: 'FF', value: 20),
          ],
        ),
      );
      // Mindestens zwei 20er unter drei Würfen: 3 * 19 + 1 von 8000.
      expect(verteilung[0], closeTo(58 / 8000, 1e-12));
      expect(verteilung[30], closeTo(7942 / 8000, 1e-12));
    });

    test('Zeilen enthalten nötige TaP*, Fundchance und erwartete Mengen', () {
      final zeilen = kraeuterVorschau(_eingabe(taw: 30), _katalog);
      expect(zeilen.map((z) => z.kandidat.kraut.name), <String>['A', 'B']);
      expect(zeilen.map((z) => z.benoetigteTapFuerFund), <int>[6, 18]);
      for (final zeile in zeilen) {
        expect(zeile.wahrscheinlichkeitFund, inInclusiveRange(0, 1));
        expect(zeile.erwarteteGrundmengenGezielt, greaterThan(0));
      }
      // Schwierigere Kräuter sind seltener zu finden, aber nie wahrscheinlicher.
      expect(
        zeilen[1].wahrscheinlichkeitFund,
        lessThanOrEqualTo(zeilen[0].wahrscheinlichkeitFund),
      );
    });

    test('ohne Erfolgsaussicht sinkt die Fundchance', () {
      final leicht = kraeuterVorschau(_eingabe(taw: 20), _katalog);
      final schwer = kraeuterVorschau(
        _eingabe(taw: 20, jahreszeit: Jahreszeit.winter, situativ: 8),
        _katalog,
      );
      expect(
        schwer.first.wahrscheinlichkeitFund,
        lessThan(leicht.first.wahrscheinlichkeitFund),
      );
    });
  });

  group('TaP* sind durch den TaW gedeckelt', () {
    test('Erleichterung hebt die TaP* nicht über den TaW', () {
      // Lichter Wald im Sommer: Erschwernis -6, Pool 16, TaW 10.
      final eingabe = _eingabe(landschaft: Kraeuterlandschaft.lichterWald);
      final request = baueKraeutersucheProbe(eingabe);
      final probe = evaluateProbe(
        request,
        createDigitalProbeRollInput(request, roller: _Folge(<int>[5, 5, 5])),
      );
      expect(probe.remainingPool, 16);
      expect(kraeuterTapStern(probe), 10);
    });

    test('bei zwei Stunden gilt der erhöhte TaW als Deckel', () {
      final eingabe = _eingabe(
        landschaft: Kraeuterlandschaft.lichterWald,
        dauerStunden: 2,
        modus: KraeuterSuchmodus.konservierung,
      );
      final ergebnis = fuehreKraeutersucheDurch(
        eingabe,
        _katalog,
        roller: _Folge(<int>[5, 5, 5]),
      );
      expect(ergebnis.tawBeiDauer, 15);
      expect(ergebnis.tapStern, 15);
    });
  });

  group('Erntezeit', () {
    final katalogMitErnte = KraeuterKatalog(
      kraeuter: <KrautEintrag>[
        const KrautEintrag(
          name: 'Immer',
          bestimmung: 1,
          vorkommen: <KrautVorkommen>[
            KrautVorkommen(
              landschaft: Kraeuterlandschaft.dichterWald,
              haeufigkeit: Kraeuterhaeufigkeit.haeufig,
            ),
          ],
        ),
        const KrautEintrag(
          name: 'Spaet',
          bestimmung: 1,
          erntezeit: 'Hesinde bis Firun',
          erntemonate: <String>['hesinde', 'firun'],
          vorkommen: <KrautVorkommen>[
            KrautVorkommen(
              landschaft: Kraeuterlandschaft.dichterWald,
              haeufigkeit: Kraeuterhaeufigkeit.haeufig,
            ),
          ],
        ),
      ],
    );

    test('krautInErntezeit: ganzjährig, im Monat, außerhalb, ohne Monat', () {
      final spaet = katalogMitErnte.kraeuter.last;
      expect(krautInErntezeit(katalogMitErnte.kraeuter.first, 'praios'), true);
      expect(krautInErntezeit(spaet, 'hesinde'), isTrue);
      expect(krautInErntezeit(spaet, 'Firun'), isTrue);
      expect(krautInErntezeit(spaet, 'praios'), isFalse);
      expect(krautInErntezeit(spaet, ''), isTrue);
      expect(krautInErntezeit(spaet, 'kein Monat'), isTrue);
    });

    test('moeglicheKraeuter kennzeichnet Kräuter außerhalb der Erntezeit', () {
      final kandidaten = moeglicheKraeuter(
        katalogMitErnte,
        Kraeuterlandschaft.dichterWald,
        monat: 'praios',
      );
      expect(kandidaten.map((k) => (k.kraut.name, k.inErntezeit)), <Object>[
        ('Immer', true),
        ('Spaet', false),
      ]);
    });

    test('beliebige Suche blendet Kräuter außerhalb der Erntezeit aus', () {
      // TaP* 10, beide Kräuter Suchschwierigkeit 3: nur "Immer" bleibt übrig.
      final ergebnis = fuehreKraeutersucheDurch(
        _eingabe(monat: 'praios'),
        katalogMitErnte,
        roller: _Folge(<int>[5, 5, 5, 1, 1]),
      );
      expect(ergebnis.funde.map((f) => f.bezeichnung), <String>['Immer']);
      expect(ergebnis.funde.single.grundmengen, 2);
    });

    test('Modus alle ignoriert die Erntezeit', () {
      final ergebnis = fuehreKraeutersucheDurch(
        _eingabe(monat: 'praios', erntezeit: ErntezeitModus.alle, taw: 3),
        katalogMitErnte,
        roller: _Folge(<int>[5, 5, 5, 8, 1]),
      );
      // Pool 3: Suchschwierigkeit 3 braucht 6 TaP*, also nichts - aber beide
      // Kräuter stehen zur Wahl, sobald genug TaP* da sind.
      expect(ergebnis.funde, isEmpty);
      final reich = fuehreKraeutersucheDurch(
        _eingabe(monat: 'praios', erntezeit: ErntezeitModus.alle, taw: 6),
        katalogMitErnte,
        roller: _Folge(<int>[5, 5, 5, 9]),
      );
      // Gewichte je 8: Wurf 9 von 16 fällt auf "Spaet".
      expect(reich.funde.map((f) => f.bezeichnung), <String>['Spaet']);
    });

    test('ohne Monat gelten alle Kräuter', () {
      final ergebnis = fuehreKraeutersucheDurch(
        _eingabe(taw: 6),
        katalogMitErnte,
        roller: _Folge(<int>[5, 5, 5, 9]),
      );
      expect(ergebnis.funde.map((f) => f.bezeichnung), <String>['Spaet']);
    });

    test('gezielte Suche außerhalb der Erntezeit gibt einen Hinweis', () {
      final ergebnis = fuehreKraeutersucheDurch(
        _eingabe(
          modus: KraeuterSuchmodus.gezielt,
          ziel: 'Spaet',
          monat: 'praios',
        ),
        katalogMitErnte,
        roller: _Folge(<int>[5, 5, 5]),
      );
      expect(ergebnis.funde, isEmpty);
      expect(ergebnis.hinweis, contains('Praios'));
      expect(ergebnis.hinweis, contains('Hesinde bis Firun'));
    });

    test('Vorschau: Kräuter außerhalb der Erntezeit haben Chance 0', () {
      final zeilen = kraeuterVorschau(
        _eingabe(taw: 30, monat: 'praios'),
        katalogMitErnte,
      );
      final spaet = zeilen.firstWhere((z) => z.kandidat.kraut.name == 'Spaet');
      final immer = zeilen.firstWhere((z) => z.kandidat.kraut.name == 'Immer');
      expect(spaet.kandidat.inErntezeit, isFalse);
      expect(spaet.wahrscheinlichkeitFund, 0);
      expect(spaet.erwarteteGrundmengenGezielt, 0);
      expect(immer.wahrscheinlichkeitFund, greaterThan(0));
    });
  });

  group('kraeuterLandschaftenFuerOrt', () {
    List<Kraeuterlandschaft> fuer(
      String unterart, {
      OrtArt art = OrtArt.region,
    }) => kraeuterLandschaftenFuerOrt(
      OrtEintrag(name: 'X', art: art, unterart: unterart),
    );

    test('Wald und Sumpf sind mehrdeutig', () {
      expect(fuer('Wald'), <Kraeuterlandschaft>[
        Kraeuterlandschaft.dichterWald,
        Kraeuterlandschaft.lichterWald,
      ]);
      expect(fuer('Sumpf'), <Kraeuterlandschaft>[
        Kraeuterlandschaft.suempfeNord,
        Kraeuterlandschaft.suempfeSued,
      ]);
    });

    test('eindeutige Arten', () {
      expect(fuer('Gebirge'), <Kraeuterlandschaft>[Kraeuterlandschaft.gebirge]);
      expect(fuer('Wüste'), <Kraeuterlandschaft>[Kraeuterlandschaft.wueste]);
      expect(fuer('Regenwald'), <Kraeuterlandschaft>[
        Kraeuterlandschaft.dschungel,
      ]);
      expect(fuer('Gletscher'), <Kraeuterlandschaft>[
        Kraeuterlandschaft.hochgebirge,
      ]);
    });

    test('ignoriert Zusätze in Klammern und die Schreibweise', () {
      expect(fuer('Hügelland (vermutlich)'), <Kraeuterlandschaft>[
        Kraeuterlandschaft.graslandHeide,
      ]);
      expect(fuer('  WALD '), hasLength(2));
    });

    test('Siedlungen, Gewässer und Unbekanntes ergeben nichts', () {
      expect(fuer('Wald', art: OrtArt.siedlung), isEmpty);
      expect(fuer('Insel'), isEmpty);
      expect(fuer('Eiswüste'), isEmpty);
      expect(fuer(''), isEmpty);
    });
  });
}
