import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';

import 'gefecht_ansagen_paket2_test.dart' as fixture;
import '../ui2/shell/karto_test_support.dart';

GefechtAuftrag _auftrag(
  int schritte, {
  int finte = 0,
  int wucht = 0,
  int fk = 0,
}) => GefechtAuftrag(
  aktion: Gefechtsaktion.angriff,
  titel: 'Distanzklasse ändern',
  zuschlag: 0,
  dk: 'N',
  dauer: 1,
  kosten: 1,
  distanzSchritte: schritte,
  finte: finte,
  wuchtschlag: wucht,
  fernkampfansage: fk,
);

void main() {
  final snap = fixture.ansageSnapshot(sf: true);
  const zustand = Gefechtszustand(iniWurf: 6, dk: 'N');
  for (final schritte in [-1, 1, 2]) {
    test(
      'DK $schritte rechnet einmal AT, freien Schritt und Finte ohne Waffen-DK-Malus',
      () {
        final p = pruefeGefechtAuftrag(
          zustand,
          snap,
          testCatalog,
          _auftrag(schritte, finte: 2),
        );
        final erschwernis = (schritte > 0 ? schritte * 4 : 0) + 2;
        expect(p.ausfuehrbar, true);
        expect(p.angriffe, 1);
        expect(p.freie, 1);
        expect(p.zielwert, gefechtswerteFuer(snap).at - erschwernis);
        expect(p.modifikatoren.any((m) => m.name == 'Distanzklasse'), false);
      },
    );
  }
  test(
    'Zu kurze Waffen-DK sperrt Annäherung nicht und erhält Zweischrittzuschlag',
    () {
      final p = pruefeGefechtAuftrag(
        zustand.copyWith(dk: 'P'),
        snap,
        testCatalog,
        const GefechtAuftrag(
          aktion: Gefechtsaktion.angriff,
          titel: 'DK',
          zuschlag: 0,
          dk: 'P',
          dauer: 1,
          kosten: 1,
          distanzSchritte: -2,
        ),
      );
      expect(p.ausfuehrbar, true);
      expect(p.zielwert, gefechtswerteFuer(snap).at - 8);
    },
  );
  test('Drei DK, fehlender Schritt und fehlende AT bleiben gesperrt', () {
    expect(
      pruefeGefechtAuftrag(zustand, snap, testCatalog, _auftrag(3)).ausfuehrbar,
      false,
    );
    for (final s in [
      zustand.copyWith(freieVerbraucht: 2),
      zustand.copyWith(angriffeVerbraucht: 1),
    ]) {
      final p = pruefeGefechtAuftrag(s, snap, testCatalog, _auftrag(1));
      expect(p.ausfuehrbar, false);
      expect(p.sperrgruende, isNotEmpty);
    }
  });
  test('DK verbietet Schadensansagen auch in direkten Aufträgen', () {
    for (final a in [_auftrag(1, wucht: 2), _auftrag(1, fk: 2)]) {
      expect(
        pruefeGefechtAuftrag(
          zustand,
          snap,
          testCatalog,
          a,
        ).sperrgruende.join(' '),
        contains(
          'Distanzklassenwechsel erlaubt keine TP- oder Fernkampfansage',
        ),
      );
    }
  });
}
