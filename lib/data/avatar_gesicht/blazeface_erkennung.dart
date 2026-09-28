import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_rechenkern.dart';

/// Unkomprimiertes Bild mit vier Bytes je Pixel (RGBA, zeilenweise).
class RgbaBild {
  const RgbaBild({
    required this.pixel,
    required this.breite,
    required this.hoehe,
  });

  final Uint8List pixel;
  final int breite;
  final int hoehe;
}

/// Achsenparalleles Rechteck in normierten Bildkoordinaten (0..1).
class BlazeFaceTreffer {
  const BlazeFaceTreffer({
    required this.links,
    required this.oben,
    required this.rechts,
    required this.unten,
    required this.score,
  });

  final double links;
  final double oben;
  final double rechts;
  final double unten;
  final double score;

  double get breite => rechts - links;
  double get hoehe => unten - oben;
  double get flaeche => math.max(breite, 0) * math.max(hoehe, 0);

  @override
  String toString() =>
      'BlazeFaceTreffer(${links.toStringAsFixed(3)}, '
      '${oben.toStringAsFixed(3)}, ${rechts.toStringAsFixed(3)}, '
      '${unten.toStringAsFixed(3)}, score ${score.toStringAsFixed(3)})';
}

/// Gesichtssuche mit BlazeFace Short Range auf einem [RgbaBild].
///
/// Parameter nach MediaPipes `face_detection_short_range`: 896 SSD-Anker,
/// Box-Skalierung 128, Sigmoid-Schwelle 0,5 und gewichtetes NMS mit IoU 0,3.
///
/// Das Short-Range-Modell ist fuer grosse Gesichter gebaut und findet bei
/// Ganzkoerperbildern oft nichts. Dann folgt ein zweiter Durchlauf auf
/// ueberlappenden Kacheln, bei Hochformat nur in den oberen 60 % des Bildes.
class BlazeFaceErkennung {
  BlazeFaceErkennung(this.kern);

  final BlazeFaceRechenkern kern;

  /// Mindestscore eines Treffers.
  static const double scoreSchwelle = 0.5;

  /// IoU, ab der Treffer zu einem verschmolzen werden.
  static const double nmsSchwelle = 0.3;

  /// Kachelseite im zweiten Durchlauf, relativ zur kuerzeren Bildseite.
  static const double kachelAnteil = 0.5;

  static final List<({double x, double y})> _anker = _erzeugeAnker();

  /// Sucht das Hauptgesicht; `null` wenn keines gefunden wurde.
  ///
  /// Gewaehlt wird der Treffer mit dem groessten Produkt aus Score und
  /// Flaeche: Bei Bildern mit mehreren Gesichtern ist das grosse, klare
  /// Gesicht die dargestellte Figur, nicht jemand im Hintergrund.
  Future<BlazeFaceTreffer?> sucheHauptgesicht(
    RgbaBild bild, {
    Future<void> Function()? pause,
  }) async {
    final treffer = await sucheGesichter(bild, pause: pause);
    if (treffer.isEmpty) return null;
    return treffer.reduce(
      (a, b) => a.score * a.flaeche >= b.score * b.flaeche ? a : b,
    );
  }

  /// Alle Gesichter des Bildes nach NMS, in normierten Bildkoordinaten.
  Future<List<BlazeFaceTreffer>> sucheGesichter(
    RgbaBild bild, {
    Future<void> Function()? pause,
  }) async {
    if (bild.breite <= 0 || bild.hoehe <= 0) return const [];
    final ganz = await erkenneBereich(
      bild,
      links: 0,
      oben: 0,
      breite: bild.breite.toDouble(),
      hoehe: bild.hoehe.toDouble(),
      pause: pause,
    );
    if (ganz.isNotEmpty) return ganz;

    final kacheln = kachelnFuer(bild.breite, bild.hoehe);
    final alle = <BlazeFaceTreffer>[];
    for (final kachel in kacheln) {
      alle.addAll(
        await erkenneBereich(
          bild,
          links: kachel.links,
          oben: kachel.oben,
          breite: kachel.seite,
          hoehe: kachel.seite,
          pause: pause,
        ),
      );
    }
    return gewichtetesNms(alle);
  }

  /// Ein Netzdurchlauf auf einem Bildbereich (Pixelkoordinaten).
  Future<List<BlazeFaceTreffer>> erkenneBereich(
    RgbaBild bild, {
    required double links,
    required double oben,
    required double breite,
    required double hoehe,
    Future<void> Function()? pause,
  }) async {
    final seite = kern.eingabeSeite;
    final vorbereitung = letterbox(
      bild,
      links: links,
      oben: oben,
      breite: breite,
      hoehe: hoehe,
      seite: seite,
    );
    final ausgabe = await kern.rechne(vorbereitung.eingabe, pause: pause);
    final roh = dekodiere(
      regressoren: ausgabe.regressoren,
      logits: ausgabe.logits,
      seite: seite,
    );
    final treffer = <BlazeFaceTreffer>[];
    for (final box in gewichtetesNms(roh)) {
      // Letterbox entfernen, dann vom Bereich aufs Gesamtbild umrechnen.
      double x(double wert) =>
          (links +
              (wert * seite - vorbereitung.versatzX) / vorbereitung.skala) /
          bild.breite;
      double y(double wert) =>
          (oben + (wert * seite - vorbereitung.versatzY) / vorbereitung.skala) /
          bild.hoehe;
      treffer.add(
        BlazeFaceTreffer(
          links: x(box.links),
          oben: y(box.oben),
          rechts: x(box.rechts),
          unten: y(box.unten),
          score: box.score,
        ),
      );
    }
    return treffer;
  }

  /// Ueberlappende quadratische Kacheln fuer den zweiten Durchlauf.
  ///
  /// Hoechstens [maxKachelnJeAchse] je Richtung, gleichmaessig verteilt. Bis
  /// zu einem Seitenverhaeltnis von 2:1 bleibt der Abstand unter einer
  /// Kachelseite, jedes Gesicht liegt dann in mindestens einer Kachel ganz.
  static List<({double links, double oben, double seite})> kachelnFuer(
    int breite,
    int hoehe,
  ) {
    final seite = math.min(breite, hoehe) * kachelAnteil;
    if (seite < 16) return const [];
    final bereichHoehe = hoehe > breite ? hoehe * 0.6 : hoehe.toDouble();
    List<double> positionen(double laenge) {
      final spielraum = math.max(laenge - seite, 0.0);
      final anzahl = math.min(
        maxKachelnJeAchse,
        (spielraum / (seite / 2)).ceil() + 1,
      );
      if (anzahl <= 1) return const [0];
      return [for (var i = 0; i < anzahl; i++) spielraum * i / (anzahl - 1)];
    }

    return [
      for (final y in positionen(bereichHoehe))
        for (final x in positionen(breite.toDouble()))
          (links: x, oben: y, seite: seite),
    ];
  }

  /// Obergrenze der Kacheln je Achse im zweiten Durchlauf.
  static const int maxKachelnJeAchse = 4;
}

/// Netzeingabe eines Bildbereichs samt Letterbox-Geometrie.
class BlazeFaceVorbereitung {
  const BlazeFaceVorbereitung({
    required this.eingabe,
    required this.skala,
    required this.versatzX,
    required this.versatzY,
  });

  /// NHWC-Werte in [-1, 1]; Rand ist schwarz (-1).
  final Float32List eingabe;

  /// Pixel der Eingabe je Pixel des Bereichs.
  final double skala;

  /// Linker Rand der Letterbox in Eingabepixeln.
  final double versatzX;

  /// Oberer Rand der Letterbox in Eingabepixeln.
  final double versatzY;
}

/// Skaliert einen Bildbereich seitentreu mittig in ein Quadrat der Seite
/// [seite] und normiert auf [-1, 1].
///
/// Beim Verkleinern mittelt ein Ueberabtaster bis zu 4 x 4 bilineare Proben je
/// Zielpixel; ohne das entstuende Aliasing, das der Detektor als Struktur
/// liest.
BlazeFaceVorbereitung letterbox(
  RgbaBild bild, {
  required double links,
  required double oben,
  required double breite,
  required double hoehe,
  required int seite,
}) {
  final skala = seite / math.max(breite, hoehe);
  final zielBreite = math.max(1, (breite * skala).round());
  final zielHoehe = math.max(1, (hoehe * skala).round());
  final versatzX = (seite - zielBreite) ~/ 2;
  final versatzY = (seite - zielHoehe) ~/ 2;
  final eingabe = Float32List(seite * seite * 3)
    ..fillRange(0, seite * seite * 3, -1);
  final proben = math.min(4, math.max(1, (1 / skala).ceil()));
  final pixel = bild.pixel;
  final maxX = bild.breite - 1;
  final maxY = bild.hoehe - 1;

  for (var ty = 0; ty < zielHoehe; ty++) {
    for (var tx = 0; tx < zielBreite; tx++) {
      var r = 0.0;
      var g = 0.0;
      var b = 0.0;
      for (var py = 0; py < proben; py++) {
        final sy = (oben + (ty + (py + 0.5) / proben) / skala - 0.5).clamp(
          0.0,
          maxY.toDouble(),
        );
        final y0 = sy.floor();
        final y1 = math.min(y0 + 1, maxY);
        final fy = sy - y0;
        for (var px = 0; px < proben; px++) {
          final sx = (links + (tx + (px + 0.5) / proben) / skala - 0.5).clamp(
            0.0,
            maxX.toDouble(),
          );
          final x0 = sx.floor();
          final x1 = math.min(x0 + 1, maxX);
          final fx = sx - x0;
          final i00 = (y0 * bild.breite + x0) * 4;
          final i01 = (y0 * bild.breite + x1) * 4;
          final i10 = (y1 * bild.breite + x0) * 4;
          final i11 = (y1 * bild.breite + x1) * 4;
          final w00 = (1 - fx) * (1 - fy);
          final w01 = fx * (1 - fy);
          final w10 = (1 - fx) * fy;
          final w11 = fx * fy;
          r +=
              pixel[i00] * w00 +
              pixel[i01] * w01 +
              pixel[i10] * w10 +
              pixel[i11] * w11;
          g +=
              pixel[i00 + 1] * w00 +
              pixel[i01 + 1] * w01 +
              pixel[i10 + 1] * w10 +
              pixel[i11 + 1] * w11;
          b +=
              pixel[i00 + 2] * w00 +
              pixel[i01 + 2] * w01 +
              pixel[i10 + 2] * w10 +
              pixel[i11 + 2] * w11;
        }
      }
      final teiler = proben * proben * 127.5;
      final ziel = ((ty + versatzY) * seite + tx + versatzX) * 3;
      eingabe[ziel] = r / teiler - 1;
      eingabe[ziel + 1] = g / teiler - 1;
      eingabe[ziel + 2] = b / teiler - 1;
    }
  }
  return BlazeFaceVorbereitung(
    eingabe: eingabe,
    skala: skala,
    versatzX: versatzX.toDouble(),
    versatzY: versatzY.toDouble(),
  );
}

/// Dekodiert Netzausgaben zu Treffern in normierten Eingabekoordinaten.
List<BlazeFaceTreffer> dekodiere({
  required Float32List regressoren,
  required Float32List logits,
  required int seite,
}) {
  final anker = BlazeFaceErkennung._anker;
  final treffer = <BlazeFaceTreffer>[];
  for (var i = 0; i < anker.length; i++) {
    final logit = logits[i].clamp(-100.0, 100.0);
    final score = 1 / (1 + math.exp(-logit));
    if (score < BlazeFaceErkennung.scoreSchwelle) continue;
    final basis = i * 16;
    final mitteX = regressoren[basis] / seite + anker[i].x;
    final mitteY = regressoren[basis + 1] / seite + anker[i].y;
    final breite = regressoren[basis + 2] / seite;
    final hoehe = regressoren[basis + 3] / seite;
    if (breite <= 0 || hoehe <= 0) continue;
    treffer.add(
      BlazeFaceTreffer(
        links: mitteX - breite / 2,
        oben: mitteY - hoehe / 2,
        rechts: mitteX + breite / 2,
        unten: mitteY + hoehe / 2,
        score: score,
      ),
    );
  }
  return treffer;
}

/// Gewichtetes NMS nach MediaPipe: Ueberlappende Treffer werden nach Score
/// gewichtet gemittelt, der Score des besten bleibt.
List<BlazeFaceTreffer> gewichtetesNms(List<BlazeFaceTreffer> treffer) {
  final offen = [...treffer]..sort((a, b) => b.score.compareTo(a.score));
  final ergebnis = <BlazeFaceTreffer>[];
  while (offen.isNotEmpty) {
    final bester = offen.first;
    final gruppe = offen
        .where((t) => _iou(bester, t) > BlazeFaceErkennung.nmsSchwelle)
        .toList(growable: false);
    offen.removeWhere(gruppe.contains);
    if (gruppe.isEmpty) {
      offen.remove(bester);
      ergebnis.add(bester);
      continue;
    }
    var summe = 0.0;
    var links = 0.0;
    var oben = 0.0;
    var rechts = 0.0;
    var unten = 0.0;
    for (final t in gruppe) {
      summe += t.score;
      links += t.links * t.score;
      oben += t.oben * t.score;
      rechts += t.rechts * t.score;
      unten += t.unten * t.score;
    }
    ergebnis.add(
      BlazeFaceTreffer(
        links: links / summe,
        oben: oben / summe,
        rechts: rechts / summe,
        unten: unten / summe,
        score: bester.score,
      ),
    );
  }
  return ergebnis;
}

double _iou(BlazeFaceTreffer a, BlazeFaceTreffer b) {
  final breite = math.min(a.rechts, b.rechts) - math.max(a.links, b.links);
  final hoehe = math.min(a.unten, b.unten) - math.max(a.oben, b.oben);
  if (breite <= 0 || hoehe <= 0) return 0;
  final schnitt = breite * hoehe;
  final vereinigung = a.flaeche + b.flaeche - schnitt;
  return vereinigung <= 0 ? 0 : schnitt / vereinigung;
}

/// SSD-Anker fuer 128er-Eingabe: Stride 8 mit 2 Ankern je Zelle, dann drei
/// Schichten mit Stride 16, die zu 6 Ankern je Zelle zusammenfallen.
List<({double x, double y})> _erzeugeAnker() {
  const schichten = <({int stride, int proZelle})>[
    (stride: 8, proZelle: 2),
    (stride: 16, proZelle: 6),
  ];
  final anker = <({double x, double y})>[];
  for (final schicht in schichten) {
    final raster = 128 ~/ schicht.stride;
    for (var y = 0; y < raster; y++) {
      for (var x = 0; x < raster; x++) {
        for (var n = 0; n < schicht.proZelle; n++) {
          anker.add((x: (x + 0.5) / raster, y: (y + 0.5) / raster));
        }
      }
    }
  }
  return List.unmodifiable(anker);
}
