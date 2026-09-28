import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dsa_heldenverwaltung/domain/held_visitenkarte.dart';

/// Normierter, quadratischer Bildausschnitt (Anteile von Breite und Hoehe).
typedef AvatarThumbnailAusschnitt = ({
  double links,
  double oben,
  double breite,
  double hoehe,
});

/// Erzeugt kompakte Base64-PNG-Thumbnails fuer Gruppen-Sync und -Export.
class AvatarThumbnailEncoder {
  /// Erstellt einen Encoder mit fester Fallback-Reihenfolge fuer Zielgroessen.
  const AvatarThumbnailEncoder({
    this.maxBase64Length = HeldVisitenkarte.avatarThumbnailBase64MaxLength,
    this.targetEdgeLengths = const <int>[128, 96, 64],
  });

  /// Maximale Laenge des erzeugten Base64-Strings.
  final int maxBase64Length;

  /// Zielkanten, die nacheinander fuer kleinere Thumbnails ausprobiert werden.
  final List<int> targetEdgeLengths;

  /// Laengste Kante, auf die vor dem Zuschnitt verkleinert wird.
  ///
  /// Auch ein Gesichtsausschnitt mit vierfachem Zoom bleibt damit ueber
  /// 128 Pixeln und wird nie hochskaliert.
  static const int _decodeEdge = 1024;

  /// Erzeugt aus [imageBytes] ein kompaktes, quadratisches PNG als Base64.
  ///
  /// [ausschnitt] waehlt den Bildbereich, in der Regel um das erkannte Gesicht
  /// herum. Ohne ihn gilt das mittige Quadrat — nie ein aufs Quadrat
  /// gestauchtes Gesamtbild.
  ///
  /// Gibt `null` zurueck, wenn die Quelldaten ungueltig sind oder selbst das
  /// kleinste Thumbnail die konfigurierte Groessenobergrenze ueberschreitet.
  Future<String?> createThumbnailBase64({
    required List<int> imageBytes,
    AvatarThumbnailAusschnitt? ausschnitt,
  }) async {
    if (imageBytes.isEmpty) return null;

    final source = await _decode(imageBytes);
    if (source == null) return null;
    try {
      final sourceRect = _sourceRect(source, ausschnitt);
      for (final edgeLength in targetEdgeLengths) {
        final thumbnailBase64 = await _tryEncodeThumbnailBase64(
          source: source,
          sourceRect: sourceRect,
          edgeLength: edgeLength,
        );
        if (thumbnailBase64 == null) continue;
        if (thumbnailBase64.length <= maxBase64Length) {
          return thumbnailBase64;
        }
      }
      return null;
    } finally {
      source.dispose();
    }
  }

  /// Dekodiert seitentreu auf hoechstens [_decodeEdge] Pixel Kante.
  Future<ui.Image?> _decode(List<int> imageBytes) async {
    ui.Codec? codec;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        Uint8List.fromList(imageBytes),
      );
      // Den Puffer gibt `instantiateImageCodecWithSize` selbst frei.
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          final edge = math.max(width, height);
          if (edge <= _decodeEdge) {
            return ui.TargetImageSize(width: width, height: height);
          }
          final factor = _decodeEdge / edge;
          return ui.TargetImageSize(
            width: math.max(1, (width * factor).round()),
            height: math.max(1, (height * factor).round()),
          );
        },
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } on Exception {
      return null;
    } finally {
      codec?.dispose();
    }
  }

  ui.Rect _sourceRect(ui.Image source, AvatarThumbnailAusschnitt? ausschnitt) {
    final width = source.width.toDouble();
    final height = source.height.toDouble();
    if (ausschnitt != null &&
        ausschnitt.breite > 0 &&
        ausschnitt.hoehe > 0 &&
        ausschnitt.links >= 0 &&
        ausschnitt.oben >= 0) {
      return ui.Rect.fromLTWH(
        ausschnitt.links * width,
        ausschnitt.oben * height,
        math.min(ausschnitt.breite, 1 - ausschnitt.links) * width,
        math.min(ausschnitt.hoehe, 1 - ausschnitt.oben) * height,
      );
    }
    final side = math.min(width, height);
    return ui.Rect.fromLTWH(
      (width - side) / 2,
      (height - side) / 2,
      side,
      side,
    );
  }

  /// Zeichnet den Ausschnitt auf eine Zielkante und kodiert ihn als PNG.
  Future<String?> _tryEncodeThumbnailBase64({
    required ui.Image source,
    required ui.Rect sourceRect,
    required int edgeLength,
  }) async {
    ui.Image? image;
    try {
      final recorder = ui.PictureRecorder();
      final edge = edgeLength.toDouble();
      ui.Canvas(recorder).drawImageRect(
        source,
        sourceRect,
        ui.Rect.fromLTWH(0, 0, edge, edge),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      try {
        image = await picture.toImage(edgeLength, edgeLength);
      } finally {
        picture.dispose();
      }
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return base64Encode(byteData.buffer.asUint8List());
    } on Exception {
      return null;
    } finally {
      image?.dispose();
    }
  }
}
