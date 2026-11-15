import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_kacheln.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_kamera.dart';

// Kamera und Kachelraster folgen dem Maßstab von Avesmaps: 512-px-Kachel bei
// Zoom 0, eine Karteneinheit misst 0,5 · 2^zoom px, y wächst nach Norden.

void main() {
  const bild = Size(400, 300);

  test('eine Karteneinheit misst 0,5 · 2^zoom px', () {
    expect(KartenKamera.pxProEinheitBei(0), .5);
    expect(KartenKamera.pxProEinheitBei(1), 1);
    expect(KartenKamera.pxProEinheitBei(6), 32);
  });

  test('Bildschirm und Karte rechnen hin und zurück, y gespiegelt', () {
    const kamera = KartenKamera(x: 500, y: 500, zoom: 2);
    expect(kamera.zuBildschirm(500, 500, bild), const Offset(200, 150));
    // Nach Norden heißt auf dem Bildschirm nach oben.
    expect(kamera.zuBildschirm(500, 510, bild).dy, lessThan(150));
    final p = kamera.zuBildschirm(523.5, 481.25, bild);
    final (x, y) = kamera.zuKarte(p, bild);
    expect(x, closeTo(523.5, 1e-9));
    expect(y, closeTo(481.25, 1e-9));
  });

  test('Band folgt dem Zoom und endet bei 8', () {
    expect(const KartenKamera(x: 0, y: 0, zoom: 3.7).band, 3);
    expect(const KartenKamera(x: 0, y: 0, zoom: 8).band, 8);
  });

  test('Zoomen hält den Punkt unter dem Fokus fest', () {
    const kamera = KartenKamera(x: 500, y: 500, zoom: 3);
    const fokus = Offset(320, 40);
    final vorher = kamera.zuKarte(fokus, bild);
    final neu = kamera.gezoomt(5, fokus, bild);
    final nachher = neu.zuKarte(fokus, bild);
    expect(neu.zoom, 5);
    expect(nachher.$1, closeTo(vorher.$1, 1e-9));
    expect(nachher.$2, closeTo(vorher.$2, 1e-9));
  });

  test('Verschieben folgt dem Finger', () {
    const kamera = KartenKamera(x: 500, y: 500, zoom: 1);
    final neu = kamera.verschoben(const Offset(10, 20));
    // Finger nach rechts unten: der Blick wandert nach Westen und Norden.
    expect(neu.x, 490);
    expect(neu.y, 520);
  });

  test('Einpassen zeigt das Rechteck ganz und deckelt den Zoom', () {
    const rechteck = KartenRechteck(400, 400, 600, 500);
    final kamera = KartenKamera.einpassen(rechteck, bild, rand: 0);
    expect(kamera.x, 500);
    expect(kamera.y, 450);
    // 200 Einheiten auf 400 px: 2 px je Einheit, also Zoom 2.
    expect(kamera.zoom, closeTo(2, 1e-9));
    final klein = KartenKamera.einpassen(
      KartenRechteck.um(500, 500, .1),
      bild,
      hoechstens: 6,
    );
    expect(klein.zoom, 6);
  });

  group('Kachelraster', () {
    test('(0,1024) liegt links oben, (1024,0) rechts unten', () {
      final ganz = kachelnIm(kKartenWelt, 1);
      expect(ganz, <KachelNummer>[(1, 0, 0), (1, 1, 0), (1, 0, 1), (1, 1, 1)]);
      expect(kachelFlaeche((1, 0, 0)), const KartenRechteck(0, 512, 512, 1024));
      expect(kachelFlaeche((1, 1, 1)), const KartenRechteck(512, 0, 1024, 512));
    });

    test('nur die berührten Kacheln, außerhalb keine', () {
      expect(
        kachelnIm(const KartenRechteck(10, 1000, 20, 1010), 3),
        <KachelNummer>[(3, 0, 0)],
      );
      expect(kachelnIm(const KartenRechteck(-50, -50, -10, -10), 3), isEmpty);
    });

    test('die Stufe rundet den Zoom und endet bei maxZoom', () {
      expect(kachelStufe(const KartenKamera(x: 0, y: 0, zoom: 2.4), 5), 2);
      expect(kachelStufe(const KartenKamera(x: 0, y: 0, zoom: 2.6), 5), 3);
      expect(kachelStufe(const KartenKamera(x: 0, y: 0, zoom: 7.5), 5), 5);
    });

    test('jede Stufe deckt die Karte lückenlos', () {
      for (var z = 0; z <= 4; z++) {
        expect(kachelnIm(kKartenWelt, z).length, math.pow(4, z));
      }
    });
  });
}
