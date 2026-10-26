import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_ap_cost_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/erwerb_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/steigerung_herleitung_rules.dart';

/// Die bisherige Kette aus `erwerb_dialog.dart`, unverändert nachgebaut.
int _bisher({
  required int basis,
  required bool episch,
  required bool epischerInhalt,
  required bool keinAufschlag,
  required bool mitLehrmeister,
  required bool verdoppelt,
}) {
  final kosten = applyEpicApSurcharge(
    basis,
    ruleActive: true,
    isEpisch: episch,
    isEpicContent: epischerInhalt,
    isBegabung: keinAufschlag,
    lehrmeisterHebtAuf: mitLehrmeister,
  );
  if (verdoppelt) {
    return mitLehrmeister ? kosten : kosten * 2;
  }
  // Ein Lehrmeister hebt den epischen Aufschlag nur auf (Epische Stufen
  // S. 5); den 20-%-Nachlass gibt es nur, wo kein Aufschlag aufzuheben war.
  final aufschlagAufgehoben =
      mitLehrmeister &&
      applyEpicApSurcharge(
            basis,
            ruleActive: true,
            isEpisch: episch,
            isEpicContent: epischerInhalt,
            isBegabung: keinAufschlag,
          ) >
          basis;
  return mitLehrmeister && !aufschlagAufgehoben
      ? apMitLehrmeister(kosten)
      : kosten;
}

void main() {
  group('herleiteErwerbskosten', () {
    test('liefert in allen Kombinationen die bisherigen AP', () {
      const bools = <bool>[false, true];
      for (final basis in <int>[0, 1, 3, 7, 10, 25, 40, 95, 150]) {
        for (final episch in bools) {
          for (final inhalt in bools) {
            for (final keiner in bools) {
              for (final lm in bools) {
                for (final verdoppelt in bools) {
                  final kosten = herleiteErwerbskosten(
                    basiskosten: basis,
                    episch: episch,
                    epischerInhalt: inhalt,
                    keinAufschlag: keiner,
                    mitLehrmeister: lm,
                    lehrmeisterVerdoppeltOhneIhn: verdoppelt,
                  );
                  expect(
                    kosten.apKosten,
                    _bisher(
                      basis: basis,
                      episch: episch,
                      epischerInhalt: inhalt,
                      keinAufschlag: keiner,
                      mitLehrmeister: lm,
                      verdoppelt: verdoppelt,
                    ),
                    reason:
                        'basis $basis episch $episch inhalt $inhalt '
                        'keiner $keiner lm $lm verdoppelt $verdoppelt',
                  );
                }
              }
            }
          }
        }
      }
    });

    test('episch: 25 % Aufschlag als eigener Schritt', () {
      final kosten = herleiteErwerbskosten(basiskosten: 40, episch: true);
      expect(kosten.aufschlag, 10);
      expect(kosten.kostenNachAufschlag, 50);
      expect(kosten.apKosten, 50);
      final schritte = kosten.herleitung.schritte;
      expect(schritte.first.bezeichnung, kErwerbBasiskostenSchritt);
      expect(schritte.first.betrag, 40);
      expect(
        schritte.where((s) => s.bezeichnung == kSteigerungEposSchritt).single,
        isA<Object>(),
      );
    });

    test('Begabung/Sondererfahrung und epischer Inhalt: kein Aufschlag', () {
      expect(
        herleiteErwerbskosten(
          basiskosten: 40,
          episch: true,
          keinAufschlag: true,
        ).aufschlag,
        0,
      );
      expect(
        herleiteErwerbskosten(
          basiskosten: 40,
          episch: true,
          epischerInhalt: true,
        ).apKosten,
        40,
      );
    });

    test('Lehrmeister hebt den epischen Aufschlag nur auf, ohne zu senken', () {
      final kosten = herleiteErwerbskosten(
        basiskosten: 40,
        episch: true,
        mitLehrmeister: true,
      );
      expect(kosten.aufschlag, 0);
      expect(kosten.apKosten, 40);
    });

    test('Lehrmeister senkt um 20 %, wo kein epischer Aufschlag anfällt', () {
      expect(
        herleiteErwerbskosten(basiskosten: 40, mitLehrmeister: true).apKosten,
        apMitLehrmeister(40),
      );
      expect(
        herleiteErwerbskosten(
          basiskosten: 40,
          episch: true,
          keinAufschlag: true,
          mitLehrmeister: true,
        ).apKosten,
        apMitLehrmeister(40),
      );
    });

    test(
      'Spezialisierung: ohne Lehrmeister das Doppelte, mit ihm der Preis',
      () {
        final ohne = herleiteErwerbskosten(
          basiskosten: 30,
          lehrmeisterVerdoppeltOhneIhn: true,
        );
        expect(ohne.apKosten, 60);
        expect(
          ohne.herleitung.schritte.any(
            (s) =>
                s.bezeichnung == kErwerbOhneLehrmeisterSchritt &&
                s.betrag == 30,
          ),
          isTrue,
        );
        final mit = herleiteErwerbskosten(
          basiskosten: 30,
          mitLehrmeister: true,
          lehrmeisterVerdoppeltOhneIhn: true,
        );
        expect(mit.apKosten, 30);
      },
    );

    test('Summe der Schritte ist der Endwert', () {
      final kosten = herleiteErwerbskosten(
        basiskosten: 37,
        episch: true,
        lehrmeisterVerdoppeltOhneIhn: true,
      );
      expect(
        kosten.herleitung.schritte.fold<int>(0, (s, e) => s + e.betrag),
        kosten.apKosten,
      );
    });
  });
}
