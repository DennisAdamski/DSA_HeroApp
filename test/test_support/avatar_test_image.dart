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
