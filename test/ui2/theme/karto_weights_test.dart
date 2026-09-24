import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

import 'karto_test_fonts.dart';

/// Breite, die ein Text in einem Stil tatsaechlich einnimmt.
double gemesseneBreite(String text, TextStyle stil) {
  final maler = TextPainter(
    text: TextSpan(text: text, style: stil),
    textDirection: TextDirection.ltr,
  )..layout();
  return maler.width;
}

void main() {
  const probe = 'Alrik Feuerstein, Krieger aus Gareth';

  setUpAll(ladeKartoSchriften);

  // Der Kern dieses Tests: ein Fettschnitt, der auf dieselbe Datei zeigt wie
  // der regulaere, liefert exakt dieselben Glyphen - und damit exakt dieselbe
  // Breite. Genau das passiert in der bestehenden Oberflaeche bei
  // Merriweather und Cinzel. Eine Behauptung im Manifest faellt dort nicht
  // auf; eine Messung schon.
  test('Spectral hat drei wirklich verschiedene Schnitte', () {
    const basis = TextStyle(fontFamily: kSchriftTitel, fontSize: 24);
    final breiten = <int, double>{
      400: gemesseneBreite(probe, basis),
      500: gemesseneBreite(probe, basis.copyWith(fontWeight: FontWeight.w500)),
      600: gemesseneBreite(probe, basis.copyWith(fontWeight: FontWeight.w600)),
    };

    expect(
      breiten.values.toSet(),
      hasLength(3),
      reason:
          'Zwei Gewichte messen gleich breit: ${breiten.entries.map((e) => "${e.key}=${e.value.toStringAsFixed(2)}").join(", ")}. '
          'Dann zeigen sie auf dieselbe Schriftdatei.',
    );
    expect(
      breiten[600],
      greaterThan(breiten[400]!),
      reason: 'Der halbfette Schnitt muss breiter laufen als der regulaere.',
    );
  });

  test('Spectral hat eine echte Kursive, keine geneigte Aufrechte', () {
    const basis = TextStyle(fontFamily: kSchriftTitel, fontSize: 24);
    final aufrecht = gemesseneBreite(probe, basis);
    final kursiv = gemesseneBreite(
      probe,
      basis.copyWith(fontStyle: FontStyle.italic),
    );
    // Eine synthetisch geneigte Schrift behaelt ihre Vorbreiten und misst
    // deshalb identisch. Eine echte Kursive hat eigene Glyphen.
    expect(
      kursiv,
      isNot(closeTo(aufrecht, 0.01)),
      reason:
          'Kursiv und aufrecht messen gleich breit - dann gibt es keinen '
          'eigenen Kursivschnitt.',
    );
  });

  test('Inter Tight staffelt sein Gewicht ueber die variable Achse', () {
    TextStyle mitGewicht(double w) => TextStyle(
      fontFamily: kSchriftDaten,
      fontSize: 24,
      fontVariations: <FontVariation>[FontVariation('wght', w)],
    );
    final breiten = <int, double>{
      400: gemesseneBreite(probe, mitGewicht(400)),
      500: gemesseneBreite(probe, mitGewicht(500)),
      600: gemesseneBreite(probe, mitGewicht(600)),
    };

    expect(
      breiten.values.toSet(),
      hasLength(3),
      reason:
          'Die variable Achse greift nicht: '
          '${breiten.entries.map((e) => "${e.key}=${e.value.toStringAsFixed(2)}").join(", ")}',
    );
    expect(breiten[600], greaterThan(breiten[400]!));
  });

  test('Zahlen laufen in der Wertrolle auf gleicher Breite', () {
    // Tabellenziffern sind der Grund, warum Zahlen in einer Spalte
    // untereinander stehen. Ohne sie wandert jede Zeile.
    final stil = buildKartoTextTheme(
      kartoHell,
      ThemeData(brightness: Brightness.light).textTheme,
    ).wert;
    final breiten = <String, double>{
      for (final ziffernfolge in <String>[
        '1111111111',
        '0000000000',
        '8888888888',
        '1234567890',
      ])
        ziffernfolge: gemesseneBreite(ziffernfolge, stil),
    };
    final spanne =
        breiten.values.reduce((a, b) => a > b ? a : b) -
        breiten.values.reduce((a, b) => a < b ? a : b);

    // Nicht auf exakte Gleichheit pruefen: Rasterung und Rundung erzeugen
    // Bruchteile eines Pixels. Eine Schrift mit proportionalen Ziffern laege
    // hier mehrere Pixel auseinander, weil die Eins deutlich schmaler baut.
    expect(
      spanne,
      lessThan(0.5),
      reason:
          'Ziffernfolgen gleicher Laenge messen um ${spanne.toStringAsFixed(3)} px '
          'auseinander: $breiten. Dann fehlen die Tabellenziffern, und Zahlen '
          'in Spalten stehen nicht untereinander.',
    );
  });

  test('die Rollen benutzen die vorgesehenen Familien', () {
    final rollen = buildKartoTextTheme(
      kartoHell,
      ThemeData(brightness: Brightness.light).textTheme,
    );
    for (final rolle in <(String, TextStyle)>[
      ('titelGross', rollen.titelGross),
      ('titel', rollen.titel),
      ('abschnitt', rollen.abschnitt),
      ('legende', rollen.legende),
    ]) {
      expect(rolle.$2.fontFamily, kSchriftTitel, reason: rolle.$1);
    }
    for (final rolle in <(String, TextStyle)>[
      ('fliess', rollen.fliess),
      ('etikett', rollen.etikett),
      ('wert', rollen.wert),
      ('wertGross', rollen.wertGross),
      ('marke', rollen.marke),
    ]) {
      expect(rolle.$2.fontFamily, kSchriftDaten, reason: rolle.$1);
    }
    expect(rollen.legende.fontStyle, FontStyle.italic);
  });

  test('die Schriftskala wird nach oben tatsaechlich genutzt', () {
    // Die bestehende Oberflaeche nutzt praktisch nur das untere Drittel. Die
    // neue Skala ist deshalb kuerzer und muss oben offen sein.
    final rollen = buildKartoTextTheme(
      kartoHell,
      ThemeData(brightness: Brightness.light).textTheme,
    );
    expect(rollen.titelGross.fontSize, greaterThanOrEqualTo(32));
    expect(rollen.wertGross.fontSize, greaterThanOrEqualTo(24));
    expect(
      rollen.titelGross.fontSize! / rollen.marke.fontSize!,
      greaterThan(2.5),
      reason: 'Ohne Spannweite entsteht keine Hierarchie.',
    );
  });
}
