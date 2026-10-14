import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_ap_cost_rules.dart';
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
    return lehrmeister ? apMitLehrmeister(nachEpos) : nachEpos;
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

  test('Lehrmeister hebt den epischen Aufschlag auf und senkt um 20 %', () {
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
    expect(lm.betrag, lessThan(0));
    expect(k.apKosten, apMitLehrmeister(k.kostenVorAufschlag));
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
}
