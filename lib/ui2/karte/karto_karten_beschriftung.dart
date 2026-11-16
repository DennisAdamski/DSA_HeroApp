import 'dart:ui';

import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_stil.dart';

/// Ein Name, der auf die Karte soll.
class BeschriftungsWunsch {
  /// Erstellt den Wunsch.
  const BeschriftungsWunsch({
    required this.schluessel,
    required this.anker,
    required this.abstand,
    required this.groesse,
  });

  /// Kennung des Orts.
  final String schluessel;

  /// Mitte der Marke auf dem Bildschirm.
  final Offset anker;

  /// Abstand von der Mitte bis zum Namen (äußerer Halbmesser der Marke
  /// plus [kNamensspalt]).
  final double abstand;

  /// Ausmaß des gesetzten Namens.
  final Size groesse;
}

/// Ein gesetzter Name.
class GesetzteBeschriftung {
  /// Erstellt den Eintrag.
  const GesetzteBeschriftung(this.wunsch, this.flaeche);

  /// Der erfüllte Wunsch.
  final BeschriftungsWunsch wunsch;

  /// Fläche des Namens auf dem Bildschirm.
  final Rect flaeche;
}

/// Setzt Namen ohne Überlappung, in der Reihenfolge der [wuensche] (die
/// bedeutenden zuerst).
///
/// Wie bei Avesmaps steht ein Name rechts der Marke und weicht nach links
/// aus; findet er beidseits keinen Platz, entfällt er. [frei] sind Flächen,
/// die kein Name überdecken darf (etwa Wegpunkte der Route). Gesucht wird
/// über ein Raster, damit auch viele Namen schnell gehen.
List<GesetzteBeschriftung> setzeBeschriftungen(
  List<BeschriftungsWunsch> wuensche, {
  Rect? bild,
  List<Rect> frei = const <Rect>[],
  double puffer = kBeschriftungsPuffer,
}) {
  final raster = _Raster(64);
  for (final f in frei) {
    raster.belege(f);
  }
  final gesetzt = <GesetzteBeschriftung>[];
  for (final wunsch in wuensche) {
    final oben = wunsch.anker.dy - wunsch.groesse.height / 2;
    final rechts = Rect.fromLTWH(
      wunsch.anker.dx + wunsch.abstand,
      oben,
      wunsch.groesse.width,
      wunsch.groesse.height,
    );
    final links = rechts.translate(
      -(2 * wunsch.abstand + wunsch.groesse.width),
      0,
    );
    for (final flaeche in <Rect>[rechts, links]) {
      if (bild != null && !_liegtIn(flaeche, bild)) continue;
      final pruef = flaeche.inflate(puffer / 2);
      if (raster.ueberlappt(pruef)) continue;
      raster.belege(pruef);
      gesetzt.add(GesetzteBeschriftung(wunsch, flaeche));
      break;
    }
  }
  return gesetzt;
}

bool _liegtIn(Rect innen, Rect aussen) =>
    innen.left >= aussen.left &&
    innen.top >= aussen.top &&
    innen.right <= aussen.right &&
    innen.bottom <= aussen.bottom;

class _Raster {
  _Raster(this.zelle);

  final double zelle;
  final Map<int, List<Rect>> _zellen = <int, List<Rect>>{};

  Iterable<int> _schluessel(Rect r) sync* {
    final x0 = (r.left / zelle).floor();
    final x1 = (r.right / zelle).floor();
    final y0 = (r.top / zelle).floor();
    final y1 = (r.bottom / zelle).floor();
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        yield (x & 0xFFFF) << 16 | (y & 0xFFFF);
      }
    }
  }

  bool ueberlappt(Rect r) {
    for (final k in _schluessel(r)) {
      final liste = _zellen[k];
      if (liste == null) continue;
      for (final belegt in liste) {
        if (belegt.overlaps(r)) return true;
      }
    }
    return false;
  }

  void belege(Rect r) {
    for (final k in _schluessel(r)) {
      (_zellen[k] ??= <Rect>[]).add(r);
    }
  }
}
