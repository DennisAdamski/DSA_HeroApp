import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

double _kanal(double anteil) {
  return anteil <= 0.03928
      ? anteil / 12.92
      : math.pow((anteil + 0.055) / 1.055, 2.4).toDouble();
}

double _luminanz(Color c) =>
    0.2126 * _kanal(c.r) + 0.7152 * _kanal(c.g) + 0.0722 * _kanal(c.b);

/// Kontrastverhaeltnis nach WCAG 2.1, zwischen 1 und 21.
double kontrast(Color a, Color b) {
  final la = _luminanz(a);
  final lb = _luminanz(b);
  final hell = math.max(la, lb);
  final dunkel = math.min(la, lb);
  return (hell + 0.05) / (dunkel + 0.05);
}

void main() {
  // Der Test laeuft ueber beide Paletten. Die dunkle ist keine Spiegelung der
  // hellen: ihre Signalfarben sind angehoben, weil die hellen Werte auf
  // dunklem Grund sonst unbrauchbar waeren. Genau das sichert dieser Test ab.
  final paletten = <String, KartoTheme>{
    'hell': kartoHell,
    'dunkel': kartoDunkel,
  };

  for (final eintrag in paletten.entries) {
    final name = eintrag.key;
    final t = eintrag.value;

    void pruefe(String was, Color vorn, Color hinten, double mindestens) {
      final wert = kontrast(vorn, hinten);
      expect(
        wert,
        greaterThanOrEqualTo(mindestens),
        reason:
            '$name: $was erreicht nur ${wert.toStringAsFixed(2)}:1, '
            'gefordert sind ${mindestens.toStringAsFixed(1)}:1.',
      );
    }

    group('Palette $name', () {
      test('Text auf allen drei Flaechen ist lesbar', () {
        for (final flaeche in <(String, Color)>[
          ('Blatt', t.blatt),
          ('Feld', t.feld),
          ('Senke', t.senke),
        ]) {
          pruefe('Schrift auf ${flaeche.$1}', t.schrift, flaeche.$2, 4.5);
          pruefe(
            'leise Schrift auf ${flaeche.$1}',
            t.schriftLeise,
            flaeche.$2,
            4.5,
          );
        }
      });

      test('Signalfarben sind als Text auf dem Blatt lesbar', () {
        pruefe('Meer', t.meer, t.blatt, 4.5);
        pruefe('Siegel', t.siegel, t.blatt, 4.5);
        pruefe('Wachs', t.wachs, t.blatt, 4.5);
        pruefe('Moos', t.moos, t.blatt, 4.5);
      });

      test('Ressourcenfarben sind als Zahl neben ihrem Balken lesbar', () {
        // In der Spielansicht steht neben jedem Balken der Wert. Die Farbe
        // muss deshalb als Text taugen, nicht nur als Flaeche.
        pruefe('Lebensenergie', t.lebensenergie, t.blatt, 4.5);
        pruefe('Astralenergie', t.astralenergie, t.blatt, 4.5);
        pruefe('Ausdauer', t.ausdauer, t.blatt, 4.5);
      });

      test('die drei Ressourcen sind voneinander unterscheidbar', () {
        // Wer rot-gruen-blind ist, unterscheidet Lebensenergie und Ausdauer
        // nicht am Farbton. Die Balken tragen deshalb immer auch ihr Etikett;
        // hier wird nur sichergestellt, dass die Farben nicht ohnehin
        // zusammenfallen.
        final farben = <Color>{t.lebensenergie, t.astralenergie, t.ausdauer};
        expect(farben, hasLength(3));
      });

      test('Text auf Signalflaechen ist lesbar', () {
        pruefe('Schrift auf Meer', t.schriftAufSignal, t.meer, 4.5);
        pruefe('Schrift auf Siegel', t.schriftAufSignal, t.siegel, 4.5);
      });

      test('tragende Linien sind sichtbar', () {
        // Kueste und Grat gliedern die Oberflaeche und sind damit
        // bedeutungstragend: WCAG 1.4.11 verlangt 3:1.
        pruefe('Kueste', t.kueste, t.blatt, 3);
        pruefe('Grat', t.grat, t.blatt, 3);
      });

      test('leise Elemente bleiben wahrnehmbar', () {
        // Bewusst schwaechere Schwellen, jeweils mit Grund:
        //
        // Stumme Schrift ist inaktiver Text und Platzhalter. WCAG nimmt
        // inaktive Bedienelemente ausdruecklich aus; 3:1 haelt sie trotzdem
        // erkennbar.
        pruefe('stumme Schrift', t.schriftStumm, t.blatt, 3);
        // Die Hoehenlinie trennt Tabellenzeilen. Sie soll die Zeilen ordnen,
        // ohne sie zu zerschneiden - eine Linie mit 3:1 wuerde die Tabelle
        // dominieren. Sie traegt keine Bedeutung, die nicht auch ohne sie da
        // waere, deshalb genuegt hier blosse Sichtbarkeit.
        pruefe('Hoehenlinie', t.hoehenlinie, t.blatt, 1.3);
      });

      test('die drei Linienstaerken sind voneinander unterscheidbar', () {
        // Wenn Linienstaerke die Hierarchie tragen soll, muessen sich die
        // drei Stufen auch farblich staffeln: je wichtiger, desto kraeftiger.
        final kueste = kontrast(t.kueste, t.blatt);
        final grat = kontrast(t.grat, t.blatt);
        final hoehenlinie = kontrast(t.hoehenlinie, t.blatt);
        expect(
          kueste,
          greaterThan(grat),
          reason: '$name: Kueste muss kraeftiger sein als Grat.',
        );
        expect(
          grat,
          greaterThan(hoehenlinie),
          reason: '$name: Grat muss kraeftiger sein als die Hoehenlinie.',
        );
      });
    });
  }

  test('beide Paletten belegen dieselben Rollen', () {
    // Schuetzt davor, dass beim Nachziehen einer Palette ein Token vergessen
    // wird und still auf einer Farbe der anderen Helligkeit stehen bleibt.
    expect(kartoHell.blatt, isNot(kartoDunkel.blatt));
    expect(kartoHell.schrift, isNot(kartoDunkel.schrift));
    expect(kartoHell.meer, isNot(kartoDunkel.meer));
    expect(kartoHell.siegel, isNot(kartoDunkel.siegel));
    expect(kartoHell.wachs, isNot(kartoDunkel.wachs));
    expect(kartoHell.moos, isNot(kartoDunkel.moos));
  });
}
