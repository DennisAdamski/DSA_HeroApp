import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_erkennung.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_modell.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_ops.dart';

Float32List _f(List<double> werte) => Float32List.fromList(werte);

void main() {
  group('faltungsMass', () {
    test('SAME mit Stride 2 legt den kleineren Rand nach vorne', () {
      // 64 -> 32 bei Kern 3: gesamt 1, vorne 0 (TFLite-Konvention).
      final mass = faltungsMass(eingabe: 64, kern: 3, stride: 2, same: true);
      expect(mass.groesse, 32);
      expect(mass.vorne, 0);
    });

    test('SAME mit Kern 5 und Stride 2 polstert vorne 1', () {
      final mass = faltungsMass(eingabe: 128, kern: 5, stride: 2, same: true);
      expect(mass.groesse, 64);
      expect(mass.vorne, 1);
    });

    test('VALID schrumpft ohne Rand', () {
      final mass = faltungsMass(eingabe: 5, kern: 3, stride: 1, same: false);
      expect(mass.groesse, 3);
      expect(mass.vorne, 0);
    });
  });

  test('punktweise Faltung mischt Kanaele mit Bias und ReLU', () {
    // 1 x 2 Pixel, 2 Kanaele -> 2 Kanaele.
    final ausgabe = faltung2d(
      eingabe: _f([1, 2, 3, 4]),
      hoehe: 1,
      breite: 2,
      kanaeleEin: 2,
      gewichte: _f([1, 1, -1, 0]),
      bias: _f([0.5, 0]),
      kanaeleAus: 2,
      kernHoehe: 1,
      kernBreite: 1,
      strideH: 1,
      strideW: 1,
      same: true,
      relu: true,
    );
    expect(ausgabe, [3.5, 0, 7.5, 0]);
  });

  test('3x3-Faltung mit SAME summiert nur Felder im Bild', () {
    // 3 x 3 Einsen, Kern aus Einsen: Ecken sehen 4, Kanten 6, Mitte 9.
    final ausgabe = faltung2d(
      eingabe: _f(List.filled(9, 1)),
      hoehe: 3,
      breite: 3,
      kanaeleEin: 1,
      gewichte: _f(List.filled(9, 1)),
      bias: _f([0]),
      kanaeleAus: 1,
      kernHoehe: 3,
      kernBreite: 3,
      strideH: 1,
      strideW: 1,
      same: true,
    );
    expect(ausgabe, [4, 6, 4, 6, 9, 6, 4, 6, 4]);
  });

  test('tiefenweise Faltung mit Stride 2 rechnet je Kanal getrennt', () {
    // 4 x 1 Zeile, 2 Kanaele; Kern 1 x 3, Stride 2, SAME -> 2 Ausgaben,
    // Rand vorne 0, hinten 1.
    final ausgabe = tiefenFaltung2d(
      eingabe: _f([1, 10, 2, 20, 3, 30, 4, 40]),
      hoehe: 1,
      breite: 4,
      kanaele: 2,
      gewichte: _f([1, 0, 1, 1, 1, 0]),
      bias: _f([0, 0.5]),
      kernHoehe: 1,
      kernBreite: 3,
      strideH: 1,
      strideW: 2,
      same: true,
    );
    // Kanal 0: 1+2+3=6, 3+4=7. Kanal 1 (nur Mitte): 20.5, 40.5.
    expect(ausgabe, [6, 20.5, 7, 40.5]);
  });

  test('Max-Pooling 2x2 halbiert die Aufloesung', () {
    final ausgabe = maxPool2d(
      eingabe: _f([1, 5, 3, 2, -1, 0, 4, 8]),
      hoehe: 2,
      breite: 4,
      kanaele: 1,
      filterHoehe: 2,
      filterBreite: 2,
      strideH: 2,
      strideW: 2,
      same: true,
    );
    expect(ausgabe, [5, 8]);
  });

  test('PAD haengt Nullkanaele hinten an', () {
    final ausgabe = auffuellen(
      eingabe: _f([1, 2, 3, 4]),
      form: const [1, 1, 2, 2],
      paddings: const [
        [0, 0],
        [0, 0],
        [0, 0],
        [0, 1],
      ],
    );
    expect(ausgabe, [1, 2, 0, 3, 4, 0]);
  });

  test('Verketten entlang Achse 1 haengt Bloecke aneinander', () {
    final ausgabe = verketten(
      eingaben: [
        _f([1, 2]),
        _f([3, 4, 5]),
      ],
      formen: const [
        [1, 2, 1],
        [1, 3, 1],
      ],
      form: const [1, 5, 1],
      achse: 1,
    );
    expect(ausgabe, [1, 2, 3, 4, 5]);
  });

  test('halbZuFloat deckt normale, subnormale und Sonderwerte ab', () {
    expect(halbZuFloat(0x3c00), 1.0);
    expect(halbZuFloat(0xc000), -2.0);
    expect(halbZuFloat(0x3555), closeTo(0.33325, 1e-5));
    expect(halbZuFloat(0x0001), closeTo(5.96e-8, 1e-10));
    expect(halbZuFloat(0x7c00), double.infinity);
    expect(halbZuFloat(0x0000), 0.0);
  });

  group('Kacheln', () {
    test('Hochformat sucht nur in den oberen 60 Prozent', () {
      final kacheln = BlazeFaceErkennung.kachelnFuer(1024, 1536);
      expect(kacheln, isNotEmpty);
      for (final kachel in kacheln) {
        expect(kachel.seite, 512);
        expect(
          kachel.oben + kachel.seite,
          lessThanOrEqualTo(1536 * 0.6 + 1e-9),
        );
      }
    });

    test('Querformat bleibt je Achse bei hoechstens vier Kacheln', () {
      final kacheln = BlazeFaceErkennung.kachelnFuer(1536, 1024);
      expect(kacheln.length, lessThanOrEqualTo(16));
      final letzte = kacheln.last;
      expect(letzte.links + letzte.seite, closeTo(1536, 1e-9));
      expect(letzte.oben + letzte.seite, closeTo(1024, 1e-9));
    });

    test('winzige Bilder bekommen keinen zweiten Durchlauf', () {
      expect(BlazeFaceErkennung.kachelnFuer(20, 20), isEmpty);
    });
  });

  test('gewichtetes NMS verschmilzt ueberlappende Treffer', () {
    const a = BlazeFaceTreffer(
      links: 0,
      oben: 0,
      rechts: 1,
      unten: 1,
      score: 0.9,
    );
    const b = BlazeFaceTreffer(
      links: 0.1,
      oben: 0,
      rechts: 1.1,
      unten: 1,
      score: 0.6,
    );
    const fern = BlazeFaceTreffer(
      links: 5,
      oben: 5,
      rechts: 6,
      unten: 6,
      score: 0.7,
    );
    final ergebnis = gewichtetesNms([b, fern, a]);
    expect(ergebnis, hasLength(2));
    expect(ergebnis.first.score, 0.9);
    expect(ergebnis.first.links, closeTo(0.04, 1e-9));
    expect(ergebnis.last.links, 5);
  });
}
