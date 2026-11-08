import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/config/app_layout.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui_shared/layout/breiten_schwellen.dart';

void main() {
  test('Bestand, Kartograph und Diagnose teilen dieselben Schwellen', () {
    for (final breite in <double>[
      320,
      743,
      744,
      1023,
      1024,
      1365,
      1366,
      2000,
    ]) {
      final bestand = appLayoutForWidth(breite);
      final karto = kartoBreiteFuer(breite);
      expect(layoutKlassenName(breite), bestand.name, reason: '$breite');
      expect(karto.name, switch (bestand) {
        AppLayoutClass.compact => 'schmal',
        AppLayoutClass.tabletPortrait => 'tablet',
        AppLayoutClass.tabletLandscape => 'breit',
        AppLayoutClass.desktopWide => 'sehrBreit',
      }, reason: '$breite');
    }
  });
}
