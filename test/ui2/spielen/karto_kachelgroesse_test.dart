import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';

void main() {
  test('Stufen folgen der Kachelbreite', () {
    expect(KartoKachelGroesse.fuerBreite(300), KartoKachelGroesse.kompakt);
    expect(KartoKachelGroesse.fuerBreite(419.9), KartoKachelGroesse.kompakt);
    expect(KartoKachelGroesse.fuerBreite(420), KartoKachelGroesse.normal);
    expect(KartoKachelGroesse.fuerBreite(699.9), KartoKachelGroesse.normal);
    expect(KartoKachelGroesse.fuerBreite(700), KartoKachelGroesse.weit);
    expect(
      KartoKachelGroesse.fuerBreite(double.infinity),
      KartoKachelGroesse.normal,
    );
  });

  testWidgets('die Steuerung reicht die Stufe auch an verschachtelte '
      'Abschnitte', (tester) async {
    KartoKachelGroesse? aussen;
    KartoKachelGroesse? innen;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: KartoKachelSteuerung(
          kennung: 'test',
          groesse: KartoKachelGroesse.weit,
          child: Builder(
            builder: (context) {
              aussen = KartoKachelSteuerung.groesseVon(context);
              return KartoKachelSteuerung(
                kennung: '',
                groesse: KartoKachelGroesse.kompakt,
                child: Builder(
                  builder: (context) {
                    innen = KartoKachelSteuerung.groesseVon(context);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(aussen, KartoKachelGroesse.weit);
    expect(innen, KartoKachelGroesse.kompakt);
  });

  testWidgets('ohne Kachel gilt die gewohnte Darstellung', (tester) async {
    KartoKachelGroesse? gelesen;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          gelesen = KartoKachelSteuerung.groesseVon(context);
          return const SizedBox();
        },
      ),
    );
    expect(gelesen, KartoKachelGroesse.normal);
  });
}
