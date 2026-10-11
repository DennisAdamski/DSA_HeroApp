import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';

MatrixAusgang _ausgang(
  MatrixStabilitaet stabilitaet,
  MatrixRegelfassung fassung,
  int w20, {
  int zusatz = 1,
}) => wertMatrixStabilitaet(
  stabilitaet: stabilitaet,
  regelfassung: fassung,
  wuerfe: MatrixWuerfe(w20: w20, w20Zusatz: zusatz, w6Hemmung: 4),
).ausgang;

void main() {
  group('Stabilitätswurf, Wege der Alchimie 2012', () {
    const f = MatrixRegelfassung.alchimie2012;

    test('labil: 12–18 gehemmt, 19–20 beschädigt', () {
      expect(_ausgang(MatrixStabilitaet.labil, f, 11), MatrixAusgang.ok);
      expect(_ausgang(MatrixStabilitaet.labil, f, 12), MatrixAusgang.gehemmt);
      expect(_ausgang(MatrixStabilitaet.labil, f, 18), MatrixAusgang.gehemmt);
      expect(
        _ausgang(MatrixStabilitaet.labil, f, 19),
        MatrixAusgang.irreparabel,
      );
      expect(
        _ausgang(MatrixStabilitaet.labil, f, 20),
        MatrixAusgang.irreparabel,
      );
    });

    test('stabil: 17–19 gehemmt, 20 beschädigt', () {
      expect(_ausgang(MatrixStabilitaet.stabil, f, 16), MatrixAusgang.ok);
      expect(_ausgang(MatrixStabilitaet.stabil, f, 17), MatrixAusgang.gehemmt);
      expect(_ausgang(MatrixStabilitaet.stabil, f, 19), MatrixAusgang.gehemmt);
      expect(
        _ausgang(MatrixStabilitaet.stabil, f, 20),
        MatrixAusgang.irreparabel,
      );
    });

    test('sehr stabil: 18–19 gehemmt, 20 beschädigt', () {
      expect(_ausgang(MatrixStabilitaet.sehrStabil, f, 17), MatrixAusgang.ok);
      expect(
        _ausgang(MatrixStabilitaet.sehrStabil, f, 18),
        MatrixAusgang.gehemmt,
      );
      expect(
        _ausgang(MatrixStabilitaet.sehrStabil, f, 20),
        MatrixAusgang.irreparabel,
      );
    });
  });

  group('Stabilitätswurf, Stäbe, Ringe, Dschinnenlampen 2011', () {
    const f = MatrixRegelfassung.staebeRinge2011;

    test('labil hemmt schon ab 10, stabil ab 16', () {
      expect(_ausgang(MatrixStabilitaet.labil, f, 9), MatrixAusgang.ok);
      expect(_ausgang(MatrixStabilitaet.labil, f, 10), MatrixAusgang.gehemmt);
      expect(_ausgang(MatrixStabilitaet.stabil, f, 15), MatrixAusgang.ok);
      expect(_ausgang(MatrixStabilitaet.stabil, f, 16), MatrixAusgang.gehemmt);
    });
  });

  group('unempfindliche Matrix', () {
    test('nur eine 20 wirkt; beschädigt erst mit Zusatzwurf 15–20', () {
      for (final f in MatrixRegelfassung.values) {
        const s = MatrixStabilitaet.unempfindlich;
        expect(_ausgang(s, f, 19), MatrixAusgang.ok);
        expect(_ausgang(s, f, 20, zusatz: 14), MatrixAusgang.gehemmt);
        expect(_ausgang(s, f, 20, zusatz: 15), MatrixAusgang.irreparabel);
        expect(_ausgang(s, f, 20, zusatz: 20), MatrixAusgang.irreparabel);
      }
    });

    test('der Zusatzwurf wird nur bei einer 20 gebraucht', () {
      expect(
        matrixBrauchtZusatzwurf(MatrixStabilitaet.unempfindlich, 20),
        true,
      );
      expect(
        matrixBrauchtZusatzwurf(MatrixStabilitaet.unempfindlich, 19),
        false,
      );
      expect(matrixBrauchtZusatzwurf(MatrixStabilitaet.labil, 20), false);
    });
  });

  test('eine Hemmung nennt die gewürfelten Spielrunden', () {
    final ergebnis = wertMatrixStabilitaet(
      stabilitaet: MatrixStabilitaet.labil,
      regelfassung: MatrixRegelfassung.alchimie2012,
      wuerfe: const MatrixWuerfe(w20: 15, w6Hemmung: 5),
    );

    expect(ergebnis.ausgang, MatrixAusgang.gehemmt);
    expect(ergebnis.hemmungSr, 5);
  });

  group('Kosten', () {
    const zauber = <ArtefaktZauber>[
      ArtefaktZauber(name: 'Gardianum', kostenAsp: 9),
      ArtefaktZauber(name: 'Armatrutz', kostenAsp: 6),
    ];

    test('die Fassung 2012 verlangt die Summe der Zauberkosten', () {
      const daten = ArtefaktDaten(zauber: zauber);

      expect(matrixGrundkosten(daten), 15);
      expect(matrixAusloeseKosten(daten, w6Kosten: 5), 15);
      expect(matrixKostenMitDifferenz(daten), isFalse);
    });

    test(
      'die Fassung 2011 verschiebt um W6: gerade mehr, ungerade weniger',
      () {
        const daten = ArtefaktDaten(
          regelfassung: MatrixRegelfassung.staebeRinge2011,
          zauber: zauber,
        );

        expect(matrixAusloeseKosten(daten, w6Kosten: 4), 19);
        expect(matrixAusloeseKosten(daten, w6Kosten: 3), 12);
      },
    );

    test('die Kosten fallen nie unter 0', () {
      const daten = ArtefaktDaten(
        regelfassung: MatrixRegelfassung.staebeRinge2011,
        zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'x', kostenAsp: 2)],
      );

      expect(matrixAusloeseKosten(daten, w6Kosten: 5), 0);
    });

    test('fehlende Kosten werden erkannt', () {
      expect(matrixKostenOffen(const ArtefaktDaten()), isTrue);
      expect(
        matrixKostenOffen(
          const ArtefaktDaten(zauber: <ArtefaktZauber>[ArtefaktZauber()]),
        ),
        isTrue,
      );
      expect(matrixKostenOffen(const ArtefaktDaten(zauber: zauber)), isFalse);
    });
  });

  group('Prüfung', () {
    const zauber = <ArtefaktZauber>[ArtefaktZauber(name: 'x', kostenAsp: 3)];

    test('ein beschädigtes Artefakt sperrt', () {
      final p = pruefeMatrixAusloesung(
        daten: const ArtefaktDaten(zauber: zauber, defekt: true),
        maxAsp: 20,
      );

      expect(p.moeglich, isFalse);
      expect(p.sperrgrund, contains('beschädigt'));
    });

    test('ein Träger ohne AsP-Vorrat bekommt nur einen Hinweis', () {
      final p = pruefeMatrixAusloesung(
        daten: const ArtefaktDaten(zauber: zauber),
        maxAsp: 0,
      );

      expect(p.moeglich, isTrue);
      expect(p.hinweise.single, contains('zauberkundigen'));
    });

    test('ein vollständiger Matrixgeber hat keine Hinweise', () {
      final p = pruefeMatrixAusloesung(
        daten: const ArtefaktDaten(zauber: zauber),
        maxAsp: 20,
      );

      expect(p.moeglich, isTrue);
      expect(p.hinweise, isEmpty);
    });

    test('AsP reichen genau bei Gleichstand', () {
      expect(matrixAspReichen(8, 8), isTrue);
      expect(matrixAspReichen(7, 8), isFalse);
    });
  });
}
