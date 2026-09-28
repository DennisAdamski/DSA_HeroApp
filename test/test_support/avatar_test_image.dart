import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Erzeugt ein rauschartiges PNG fuer Thumbnail-Tests.
Future<List<int>> createNoisyPngBytes({
  int width = 768,
  int height = 768,
}) async {
  final pixels = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixelIndex = (y * width + x) * 4;
      pixels[pixelIndex] = (x * 73 + y * 19) % 256;
      pixels[pixelIndex + 1] = (x * 11 + y * 97) % 256;
      pixels[pixelIndex + 2] = ((x * 37) ^ (y * 53)) % 256;
      pixels[pixelIndex + 3] = 255;
    }
  }

  final image = await _decodeImageFromPixels(
    pixels: pixels,
    width: width,
    height: height,
  );
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Erzeugt ein PNG aus gleich breiten, senkrechten Farbstreifen (ARGB).
Future<List<int>> createStripedPngBytes({
  required int width,
  required int height,
  required List<int> stripes,
}) async {
  final pixels = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final color = stripes[x * stripes.length ~/ width];
      final pixelIndex = (y * width + x) * 4;
      pixels[pixelIndex] = (color >> 16) & 0xFF;
      pixels[pixelIndex + 1] = (color >> 8) & 0xFF;
      pixels[pixelIndex + 2] = color & 0xFF;
      pixels[pixelIndex + 3] = (color >> 24) & 0xFF;
    }
  }
  final image = await _decodeImageFromPixels(
    pixels: pixels,
    width: width,
    height: height,
  );
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Liest die RGBA-Pixel eines [ui.Image].
Future<Uint8List> readRgbaPixels(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return byteData!.buffer.asUint8List();
}

/// Farbe eines Pixels als ARGB-Wert.
int pixelAt(Uint8List rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return (rgba[i + 3] << 24) |
      (rgba[i] << 16) |
      (rgba[i + 1] << 8) |
      rgba[i + 2];
}

/// Dekodiert PNG-Bytes zu einem [ui.Image] fuer Groessenpruefungen.
Future<ui.Image> decodePngBytes(List<int> pngBytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(pngBytes));
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

Future<ui.Image> _decodeImageFromPixels({
  required Uint8List pixels,
  required int width,
  required int height,
}) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
