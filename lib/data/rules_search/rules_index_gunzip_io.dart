import 'dart:io';
import 'dart:typed_data';

/// Ob [bytes] mit der gzip-Kennung beginnen.
bool isGzip(Uint8List bytes) =>
    bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

/// Entpackt [bytes], wenn sie gzip-gepackt sind, sonst unveraendert.
Uint8List gunzipIfNeeded(Uint8List bytes) {
  if (!isGzip(bytes)) return bytes;
  const beschaedigt = FormatException('Die gepackte Datei ist beschädigt.');
  try {
    final entpackt = gzip.decode(bytes);
    // Ein abgeschnittener Datenstrom liefert mitunter leere Bytes statt eines
    // Fehlers.
    if (entpackt.isEmpty) throw beschaedigt;
    return Uint8List.fromList(entpackt);
  } on FormatException {
    throw beschaedigt;
  }
}
