import 'dart:math' as math;
import 'dart:typed_data';

// Tensoroperationen des BlazeFace-Rechenkerns, alle in NHWC mit Batch 1.
//
// Die Semantik folgt den TFLite-Referenzkernen: `SAME`-Padding verteilt den
// Ueberstand mit dem kleineren Teil vorne (`gesamt ~/ 2`), Pooling ignoriert
// Randfelder statt sie als 0 zu werten. Getrennt vom Interpreter, damit jede
// Op einzeln gegen handgerechnete Werte testbar ist.

/// Ausgabegroesse und vorderes Padding einer Dimension.
({int groesse, int vorne}) faltungsMass({
  required int eingabe,
  required int kern,
  required int stride,
  required bool same,
}) {
  if (!same) {
    return (groesse: (eingabe - kern) ~/ stride + 1, vorne: 0);
  }
  final groesse = (eingabe + stride - 1) ~/ stride;
  final gesamt = math.max((groesse - 1) * stride + kern - eingabe, 0);
  return (groesse: groesse, vorne: gesamt ~/ 2);
}

/// Faltung mit Gewichten in TFLite-Anordnung `[cOut, kh, kw, cIn]`.
Float32List faltung2d({
  required Float32List eingabe,
  required int hoehe,
  required int breite,
  required int kanaeleEin,
  required Float32List gewichte,
  required Float32List bias,
  required int kanaeleAus,
  required int kernHoehe,
  required int kernBreite,
  required int strideH,
  required int strideW,
  required bool same,
  bool relu = false,
}) {
  final zeilen = faltungsMass(
    eingabe: hoehe,
    kern: kernHoehe,
    stride: strideH,
    same: same,
  );
  final spalten = faltungsMass(
    eingabe: breite,
    kern: kernBreite,
    stride: strideW,
    same: same,
  );
  final ausH = zeilen.groesse;
  final ausW = spalten.groesse;
  final ausgabe = Float32List(ausH * ausW * kanaeleAus);

  if (kernHoehe == 1 && kernBreite == 1 && strideH == 1 && strideW == 1) {
    // Punktweise Faltung: der mit Abstand haeufigste Fall im Netz.
    for (var p = 0; p < ausH * ausW; p++) {
      final einBasis = p * kanaeleEin;
      final ausBasis = p * kanaeleAus;
      for (var co = 0; co < kanaeleAus; co++) {
        var summe = bias[co];
        final gBasis = co * kanaeleEin;
        for (var ci = 0; ci < kanaeleEin; ci++) {
          summe += eingabe[einBasis + ci] * gewichte[gBasis + ci];
        }
        ausgabe[ausBasis + co] = relu && summe < 0 ? 0 : summe;
      }
    }
    return ausgabe;
  }

  for (var oy = 0; oy < ausH; oy++) {
    for (var ox = 0; ox < ausW; ox++) {
      final ausBasis = (oy * ausW + ox) * kanaeleAus;
      for (var co = 0; co < kanaeleAus; co++) {
        var summe = bias[co];
        for (var ky = 0; ky < kernHoehe; ky++) {
          final iy = oy * strideH + ky - zeilen.vorne;
          if (iy < 0 || iy >= hoehe) continue;
          for (var kx = 0; kx < kernBreite; kx++) {
            final ix = ox * strideW + kx - spalten.vorne;
            if (ix < 0 || ix >= breite) continue;
            final einBasis = (iy * breite + ix) * kanaeleEin;
            final gBasis =
                ((co * kernHoehe + ky) * kernBreite + kx) * kanaeleEin;
            for (var ci = 0; ci < kanaeleEin; ci++) {
              summe += eingabe[einBasis + ci] * gewichte[gBasis + ci];
            }
          }
        }
        ausgabe[ausBasis + co] = relu && summe < 0 ? 0 : summe;
      }
    }
  }
  return ausgabe;
}

/// Tiefenweise Faltung mit Gewichten `[1, kh, kw, c]` (Multiplikator 1).
Float32List tiefenFaltung2d({
  required Float32List eingabe,
  required int hoehe,
  required int breite,
  required int kanaele,
  required Float32List gewichte,
  required Float32List bias,
  required int kernHoehe,
  required int kernBreite,
  required int strideH,
  required int strideW,
  required bool same,
  bool relu = false,
}) {
  final zeilen = faltungsMass(
    eingabe: hoehe,
    kern: kernHoehe,
    stride: strideH,
    same: same,
  );
  final spalten = faltungsMass(
    eingabe: breite,
    kern: kernBreite,
    stride: strideW,
    same: same,
  );
  final ausH = zeilen.groesse;
  final ausW = spalten.groesse;
  final ausgabe = Float32List(ausH * ausW * kanaele);

  for (var oy = 0; oy < ausH; oy++) {
    for (var ox = 0; ox < ausW; ox++) {
      final ausBasis = (oy * ausW + ox) * kanaele;
      for (var c = 0; c < kanaele; c++) {
        ausgabe[ausBasis + c] = bias[c];
      }
      for (var ky = 0; ky < kernHoehe; ky++) {
        final iy = oy * strideH + ky - zeilen.vorne;
        if (iy < 0 || iy >= hoehe) continue;
        for (var kx = 0; kx < kernBreite; kx++) {
          final ix = ox * strideW + kx - spalten.vorne;
          if (ix < 0 || ix >= breite) continue;
          final einBasis = (iy * breite + ix) * kanaele;
          final gBasis = (ky * kernBreite + kx) * kanaele;
          for (var c = 0; c < kanaele; c++) {
            ausgabe[ausBasis + c] +=
                eingabe[einBasis + c] * gewichte[gBasis + c];
          }
        }
      }
      if (relu) {
        for (var c = 0; c < kanaele; c++) {
          if (ausgabe[ausBasis + c] < 0) ausgabe[ausBasis + c] = 0;
        }
      }
    }
  }
  return ausgabe;
}

/// Max-Pooling; Randfelder ausserhalb des Bildes zaehlen nicht mit.
Float32List maxPool2d({
  required Float32List eingabe,
  required int hoehe,
  required int breite,
  required int kanaele,
  required int filterHoehe,
  required int filterBreite,
  required int strideH,
  required int strideW,
  required bool same,
}) {
  final zeilen = faltungsMass(
    eingabe: hoehe,
    kern: filterHoehe,
    stride: strideH,
    same: same,
  );
  final spalten = faltungsMass(
    eingabe: breite,
    kern: filterBreite,
    stride: strideW,
    same: same,
  );
  final ausH = zeilen.groesse;
  final ausW = spalten.groesse;
  final ausgabe = Float32List(ausH * ausW * kanaele);
  for (var oy = 0; oy < ausH; oy++) {
    for (var ox = 0; ox < ausW; ox++) {
      final ausBasis = (oy * ausW + ox) * kanaele;
      for (var c = 0; c < kanaele; c++) {
        var maximum = double.negativeInfinity;
        for (var ky = 0; ky < filterHoehe; ky++) {
          final iy = oy * strideH + ky - zeilen.vorne;
          if (iy < 0 || iy >= hoehe) continue;
          for (var kx = 0; kx < filterBreite; kx++) {
            final ix = ox * strideW + kx - spalten.vorne;
            if (ix < 0 || ix >= breite) continue;
            final wert = eingabe[(iy * breite + ix) * kanaele + c];
            if (wert > maximum) maximum = wert;
          }
        }
        ausgabe[ausBasis + c] = maximum;
      }
    }
  }
  return ausgabe;
}

/// Fuellt einen 4D-Tensor mit Nullen auf.
///
/// [paddings] ist `[[vor, nach], ...]` je Dimension, die Batch-Dimension
/// muss unveraendert bleiben.
Float32List auffuellen({
  required Float32List eingabe,
  required List<int> form,
  required List<List<int>> paddings,
}) {
  if (form.length != 4 || paddings.length != 4) {
    throw ArgumentError('PAD erwartet einen 4D-Tensor.');
  }
  if (form[0] != 1 || paddings[0][0] != 0 || paddings[0][1] != 0) {
    throw ArgumentError(
      'PAD entlang der Batch-Dimension ist nicht vorgesehen.',
    );
  }
  final h = form[1];
  final w = form[2];
  final c = form[3];
  final ausH = h + paddings[1][0] + paddings[1][1];
  final ausW = w + paddings[2][0] + paddings[2][1];
  final ausC = c + paddings[3][0] + paddings[3][1];
  final ausgabe = Float32List(ausH * ausW * ausC);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final einBasis = (y * w + x) * c;
      final ausBasis =
          ((y + paddings[1][0]) * ausW + x + paddings[2][0]) * ausC +
          paddings[3][0];
      for (var k = 0; k < c; k++) {
        ausgabe[ausBasis + k] = eingabe[einBasis + k];
      }
    }
  }
  return ausgabe;
}

/// Elementweise Summe gleich grosser Tensoren.
Float32List addiere(Float32List a, Float32List b, {bool relu = false}) {
  if (a.length != b.length) {
    throw ArgumentError('ADD ohne Broadcasting erwartet gleiche Groessen.');
  }
  final ausgabe = Float32List(a.length);
  for (var i = 0; i < a.length; i++) {
    final summe = a[i] + b[i];
    ausgabe[i] = relu && summe < 0 ? 0 : summe;
  }
  return ausgabe;
}

/// ReLU als neue Liste.
Float32List gleichrichten(Float32List eingabe) {
  final ausgabe = Float32List(eingabe.length);
  for (var i = 0; i < eingabe.length; i++) {
    final wert = eingabe[i];
    ausgabe[i] = wert < 0 ? 0 : wert;
  }
  return ausgabe;
}

/// Verkettet Tensoren entlang [achse] der Ausgabeform [form].
Float32List verketten({
  required List<Float32List> eingaben,
  required List<List<int>> formen,
  required List<int> form,
  required int achse,
}) {
  final rang = form.length;
  final normierteAchse = achse < 0 ? achse + rang : achse;
  var aussen = 1;
  for (var d = 0; d < normierteAchse; d++) {
    aussen *= form[d];
  }
  final bloecke = <int>[
    for (final eingabeForm in formen)
      eingabeForm.skip(normierteAchse).fold<int>(1, (a, b) => a * b),
  ];
  final gesamt = bloecke.fold<int>(0, (a, b) => a + b) * aussen;
  final ausgabe = Float32List(gesamt);
  var ziel = 0;
  for (var o = 0; o < aussen; o++) {
    for (var i = 0; i < eingaben.length; i++) {
      final block = bloecke[i];
      ausgabe.setRange(ziel, ziel + block, eingaben[i], o * block);
      ziel += block;
    }
  }
  return ausgabe;
}
