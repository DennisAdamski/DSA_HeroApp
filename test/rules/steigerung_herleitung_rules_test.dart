import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_ap_cost_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/lernkosten_faktor_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/steigerung_herleitung_rules.dart';

void main() {
  /// Die bisherige Kette des Steigerungsdialogs, unabhängig nachgebaut.
  int alteKette({
    required int von,
    required int auf,
    required LearnCost spalte,
    required int se,
    required bool episch,
    required bool haupt,
    required bool lehrmeister,
  }) {
    final basis = berechneSteigerungskosten(
      vonWert: von,
      aufWert: auf,
      effektiveKomplexitaet: spalte,
      seAnzahl: se,
    ).apKosten;
    final nachEpos = applyEpicApSurcharge(
      basis,
      ruleActive: true,
      isEpisch: episch,
      isMainAttribute: haupt,
      lehrmeisterHebtAuf: lehrmeister,
    );
    // Ein Lehrmeister hebt den epischen Aufschlag nur auf (Epische Stufen
    // S. 5); den 20-%-Nachlass gibt es nur, wo kein Aufschlag aufzuheben war.
    final aufschlagAufgehoben =
        lehrmeister &&
        applyEpicApSurcharge(
              basis,
              ruleActive: true,
              isEpisch: episch,
              isMainAttribute: haupt,
            ) >
            basis;
    return lehrmeister && !aufschlagAufgehoben
        ? apMitLehrmeister(nachEpos)
        : nachEpos;
  }

  test('Herleitung ergibt in allen Fällen die bisherigen AP-Kosten', () {
    var faelle = 0;
    for (final spalte in LearnCost.values) {
      for (final von in const [-1, 0, 3, 9]) {
        for (final delta in const [1, 2, 5]) {
          for (final se in const [0, 1, 4]) {
            for (final episch in const [false, true]) {
              for (final haupt in const [false, true]) {
                for (final lehrmeister in const [false, true]) {
                  final auf = von + delta;
                  final kosten = herleiteSteigerungskosten(
                    vonWert: von,
                    aufWert: auf,
                    komplexitaet: spalte,
                    seAnzahl: se,
                    episch: episch,
                    istHaupteigenschaft: haupt,
                    mitLehrmeister: lehrmeister,
                  );
                  final erwartet = alteKette(
                    von: von,
                    auf: auf,
                    spalte: spalte,
                    se: se,
                    episch: episch,
                    haupt: haupt,
                    lehrmeister: lehrmeister,
                  );
                  expect(
                    kosten.apKosten,
                    erwartet,
                    reason:
                        '$spalte $von→$auf se$se e$episch h$haupt l$lehrmeister',
                  );
                  faelle++;
                }
              }
            }
          }
        }
      }
    }
    expect(faelle, greaterThan(1000));
  });

  test(
    'Schritte nennen Grundkosten, Sondererfahrung, Aufschlag, Lehrmeister',
    () {
      final k = herleiteSteigerungskosten(
        vonWert: 4,
        aufWert: 7,
        komplexitaet: LearnCost.d,
        seAnzahl: 1,
        episch: true,
      );
      final namen = k.herleitung.sichtbareSchritte.map((s) => s.bezeichnung);
      expect(namen, [
        kSteigerungGrundkostenSchritt,
        kSteigerungSeSchritt,
        kSteigerungEposSchritt,
      ]);
      expect(k.seVerbraucht, 1);
      final grund = k.herleitung.schritte.first.betrag;
      final se = k.herleitung.schritte[1].betrag;
      expect(se, lessThan(0));
      expect(k.kostenVorAufschlag, grund + se);
      expect(k.aufschlag, greaterThan(0));
      expect(k.apKosten, k.kostenNachAufschlag);
    },
  );

  test('Lehrmeister hebt den epischen Aufschlag nur auf, ohne zu senken', () {
    final k = herleiteSteigerungskosten(
      vonWert: 4,
      aufWert: 7,
      komplexitaet: LearnCost.d,
      episch: true,
      mitLehrmeister: true,
    );
    expect(k.aufschlag, 0);
    final lm = k.herleitung.schritte.singleWhere(
      (s) => s.bezeichnung == kSteigerungLehrmeisterSchritt,
    );
    expect(lm.betrag, 0);
    expect(k.apKosten, k.kostenVorAufschlag);
  });

  test('Lehrmeister senkt um 20 %, wo kein epischer Aufschlag anfällt', () {
    final nichtEpisch = herleiteSteigerungskosten(
      vonWert: 4,
      aufWert: 7,
      komplexitaet: LearnCost.d,
      mitLehrmeister: true,
    );
    expect(
      nichtEpisch.apKosten,
      apMitLehrmeister(nichtEpisch.kostenVorAufschlag),
    );
    final haupt = herleiteSteigerungskosten(
      vonWert: 10,
      aufWert: 11,
      komplexitaet: LearnCost.h,
      episch: true,
      istHaupteigenschaft: true,
      mitLehrmeister: true,
    );
    expect(haupt.apKosten, apMitLehrmeister(haupt.kostenVorAufschlag));
  });

  test('Haupteigenschaft zahlt keinen Aufschlag', () {
    final k = herleiteSteigerungskosten(
      vonWert: 10,
      aufWert: 11,
      komplexitaet: LearnCost.h,
      episch: true,
      istHaupteigenschaft: true,
    );
    expect(k.aufschlag, 0);
    expect(k.herleitung.sichtbareSchritte.map((s) => s.bezeichnung), [
      kSteigerungGrundkostenSchritt,
    ]);
  });

  test('keine Steigerung kostet nichts', () {
    final k = herleiteSteigerungskosten(
      vonWert: 5,
      aufWert: 5,
      komplexitaet: LearnCost.c,
      episch: true,
    );
    expect(k.apKosten, 0);
  });

  group('Hexalogie und Gedächtnis', () {
    test('Hexalogie verbilligt nur Schritte bis zum Zielwert', () {
      final k = herleiteSteigerungskosten(
        vonWert: 2,
        aufWert: 6,
        komplexitaet: LearnCost.d,
        regeln: const Lernregeln(erleichterungBisWert: 4),
      );
      // Schritte 2→3 und 3→4 in Spalte C, 4→5 und 5→6 in Spalte D.
      expect(
        k.apKosten,
        LearnCost.c.costForStep(2) +
            LearnCost.c.costForStep(3) +
            LearnCost.d.costForStep(4) +
            LearnCost.d.costForStep(5),
      );
      final hex = k.herleitung.schritte.singleWhere(
        (s) => s.bezeichnung == kSteigerungHexalogieSchritt,
      );
      expect(hex.betrag, lessThan(0));
      expect(hex.formel, contains('ZfW 4'));
    });

    test(
      'die Aktivierung gehört zur Erleichterung, sobald der Wert >= 0 ist',
      () {
        final k = herleiteSteigerungskosten(
          vonWert: -1,
          aufWert: 1,
          komplexitaet: LearnCost.d,
          regeln: const Lernregeln(erleichterungBisWert: 0),
        );
        expect(
          k.apKosten,
          LearnCost.c.costForStep(-1) + LearnCost.d.costForStep(0),
        );
      },
    );

    test(
      'Hexalogie und Sondererfahrung verbilligen denselben Schritt doppelt',
      () {
        final k = herleiteSteigerungskosten(
          vonWert: 3,
          aufWert: 4,
          komplexitaet: LearnCost.d,
          seAnzahl: 1,
          regeln: const Lernregeln(erleichterungBisWert: 9),
        );
        expect(k.apKosten, LearnCost.b.costForStep(3));
        expect(k.seVerbraucht, 1);
      },
    );

    test('Gutes Gedächtnis nimmt ein Viertel der Kosten nach der Spalte', () {
      final ohne = herleiteSteigerungskosten(
        vonWert: 5,
        aufWert: 8,
        komplexitaet: LearnCost.d,
      );
      final mit = herleiteSteigerungskosten(
        vonWert: 5,
        aufWert: 8,
        komplexitaet: LearnCost.d,
        regeln: const Lernregeln(
          faktoren: [
            LernkostenFaktor(
              bezeichnung: 'Gutes Gedächtnis (¾)',
              zaehler: 3,
              nenner: 4,
              quelle: 'Vorteil',
            ),
          ],
        ),
      );
      expect(mit.apKosten, (ohne.apKosten * 3 / 4).round());
      expect(
        mit.herleitung.sichtbareSchritte.map((s) => s.bezeichnung),
        contains('Gutes Gedächtnis (¾)'),
      );
    });

    test('Begabung (Spalte) vor Gedächtnis: Dreiviertel der linken Spalte', () {
      // „Ein begabter Held mit Gutem Gedächtnis bezahlt drei Viertel der AP
      // der verbilligten (linken) Spalte.“ (Wege der Helden S. 253)
      final k = herleiteSteigerungskosten(
        vonWert: 5,
        aufWert: 6,
        komplexitaet: LearnCost.c,
        regeln: const Lernregeln(
          faktoren: [
            LernkostenFaktor(
              bezeichnung: 'Gutes Gedächtnis (¾)',
              zaehler: 3,
              nenner: 4,
              quelle: 'Vorteil',
            ),
          ],
        ),
      );
      expect(k.apKosten, (LearnCost.c.costForStep(5) * 3 / 4).round());
    });

    test('Faktor, epischer Aufschlag und Lehrmeister bleiben summentreu', () {
      for (final lehrmeister in const [false, true]) {
        final k = herleiteSteigerungskosten(
          vonWert: 5,
          aufWert: 9,
          komplexitaet: LearnCost.d,
          seAnzahl: 1,
          episch: true,
          mitLehrmeister: lehrmeister,
          regeln: const Lernregeln(
            erleichterungBisWert: 7,
            faktoren: [
              LernkostenFaktor(
                bezeichnung: 'Eidetisches Gedächtnis (½)',
                zaehler: 1,
                nenner: 2,
                quelle: 'Vorteil',
              ),
            ],
          ),
        );
        expect(
          k.herleitung.wert,
          k.herleitung.schritte.fold<int>(0, (a, s) => a + s.betrag),
        );
        expect(k.apKosten, greaterThan(0));
      }
    });
  });
}
