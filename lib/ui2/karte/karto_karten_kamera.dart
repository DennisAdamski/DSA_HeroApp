import 'dart:math' as math;
import 'dart:ui';

import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_stil.dart';

/// Blick auf die Karte: Mitte in Karteneinheiten und Zoom.
///
/// Der Maßstab folgt Avesmaps: Bei Zoom 0 ist die Karte (1024 Einheiten)
/// eine Kachel von 512 px breit, jede Zoomstufe verdoppelt. Eine
/// Karteneinheit misst also `0,5 · 2^zoom` px. Auf dem Bildschirm wächst `y`
/// nach unten, auf der Karte nach Norden.
class KartenKamera {
  /// Erstellt die Kamera.
  const KartenKamera({required this.x, required this.y, required this.zoom});

  /// Blick auf die ganze Karte.
  static const KartenKamera ganz = KartenKamera(
    x: kKartenKante / 2,
    y: kKartenKante / 2,
    zoom: 1,
  );

  /// Kantenlänge einer Kachel in px.
  static const double kachelPixel = 512;

  /// Mitte Ost-West in Karteneinheiten.
  final double x;

  /// Mitte Süd-Nord in Karteneinheiten.
  final double y;

  /// Zoom, [kKartenZoomMin] … [kKartenZoomMax].
  final double zoom;

  /// Pixel je Karteneinheit.
  double get pxProEinheit => pxProEinheitBei(zoom);

  /// Pixel je Karteneinheit bei [zoom].
  static double pxProEinheitBei(double zoom) =>
      kachelPixel / kKartenKante * math.pow(2, zoom);

  /// Band der Stiltafeln (0 … 8).
  int get band => zoom.clamp(0.0, (kKartenBaender - 1).toDouble()).floor();

  /// Bildschirmpunkt der Kartenposition ([kx], [ky]) bei der Größe [bild].
  Offset zuBildschirm(double kx, double ky, Size bild) {
    final p = pxProEinheit;
    return Offset(
      bild.width / 2 + (kx - x) * p,
      bild.height / 2 - (ky - y) * p,
    );
  }

  /// Kartenposition `(x, y)` des Bildschirmpunkts [punkt].
  (double, double) zuKarte(Offset punkt, Size bild) {
    final p = pxProEinheit;
    return (
      x + (punkt.dx - bild.width / 2) / p,
      y - (punkt.dy - bild.height / 2) / p,
    );
  }

  /// Der sichtbare Ausschnitt in Karteneinheiten.
  KartenRechteck sichtbar(Size bild) {
    final p = pxProEinheit;
    final halbB = bild.width / 2 / p;
    final halbH = bild.height / 2 / p;
    return KartenRechteck(x - halbB, y - halbH, x + halbB, y + halbH);
  }

  /// Um [delta] px auf dem Bildschirm verschoben (Karte folgt dem Finger).
  KartenKamera verschoben(Offset delta) {
    final p = pxProEinheit;
    return KartenKamera(
      x: (x - delta.dx / p).clamp(0.0, kKartenKante),
      y: (y + delta.dy / p).clamp(0.0, kKartenKante),
      zoom: zoom,
    );
  }

  /// Auf [neuerZoom], wobei die Kartenposition unter [fokus] stehen bleibt.
  KartenKamera gezoomt(double neuerZoom, Offset fokus, Size bild) {
    final z = neuerZoom.clamp(kKartenZoomMin, kKartenZoomMax);
    final (fx, fy) = zuKarte(fokus, bild);
    final p = pxProEinheitBei(z);
    return KartenKamera(
      x: (fx - (fokus.dx - bild.width / 2) / p).clamp(0.0, kKartenKante),
      y: (fy + (fokus.dy - bild.height / 2) / p).clamp(0.0, kKartenKante),
      zoom: z,
    );
  }

  /// Kamera, die [rechteck] mit [rand] px Abstand in [bild] zeigt.
  ///
  /// Der Zoom bleibt unter [hoechstens], damit ein einzelner Ort nicht
  /// bildfüllend wird.
  static KartenKamera einpassen(
    KartenRechteck rechteck,
    Size bild, {
    double rand = 24,
    double hoechstens = 6,
  }) {
    final breite = math.max(1.0, bild.width - 2 * rand);
    final hoehe = math.max(1.0, bild.height - 2 * rand);
    final p = math.min(
      breite / math.max(rechteck.breite, 1e-6),
      hoehe / math.max(rechteck.hoehe, 1e-6),
    );
    final zoom = math.log(p * kKartenKante / kachelPixel) / math.ln2;
    return KartenKamera(
      x: rechteck.mitteX,
      y: rechteck.mitteY,
      zoom: zoom.clamp(kKartenZoomMin, math.min(hoechstens, kKartenZoomMax)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KartenKamera &&
      other.x == x &&
      other.y == y &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(x, y, zoom);

  @override
  String toString() => 'KartenKamera($x, $y, z$zoom)';
}
