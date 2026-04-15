import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dsa_heldenverwaltung/domain/held_visitenkarte.dart';

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

  /// Erzeugt aus [imageBytes] ein kompaktes PNG-Thumbnail als Base64.
  ///
  /// Gibt `null` zurueck, wenn die Quelldaten ungueltig sind oder selbst das
  /// kleinste Thumbnail die konfigurierte Groessenobergrenze ueberschreitet.
  Future<String?> createThumbnailBase64({required List<int> imageBytes}) async {
    if (imageBytes.isEmpty) return null;

    for (final edgeLength in targetEdgeLengths) {
      final thumbnailBase64 = await _tryEncodeThumbnailBase64(
        imageBytes: imageBytes,
        edgeLength: edgeLength,
      );
      if (thumbnailBase64 == null) continue;
      if (thumbnailBase64.length <= maxBase64Length) {
        return thumbnailBase64;
      }
    }
    return null;
  }

  /// Kodiert ein einzelnes Thumbnail-Ziel und behandelt Codec-Fehler defensiv.
  Future<String?> _tryEncodeThumbnailBase64({
    required List<int> imageBytes,
    required int edgeLength,
  }) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        Uint8List.fromList(imageBytes),
        targetWidth: edgeLength,
        targetHeight: edgeLength,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return base64Encode(byteData.buffer.asUint8List());
    } on Exception {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}
