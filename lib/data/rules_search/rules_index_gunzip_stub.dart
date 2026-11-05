import 'dart:typed_data';

/// Ob [bytes] mit der gzip-Kennung beginnen.
bool isGzip(Uint8List bytes) =>
    bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

/// Web und andere Plattformen ohne `dart:io`: kein eigenes Entpacken.
///
/// Der Browser entpackt `Content-Encoding: gzip` selbst; kommt trotzdem
/// gzip an, ist die Datei falsch hochgeladen.
Uint8List gunzipIfNeeded(Uint8List bytes) {
  if (isGzip(bytes)) {
    throw const FormatException(
      'Die Datei kam noch gepackt an. Beim Hochladen fehlt '
      '`Content-Encoding: gzip`.',
    );
  }
  return bytes;
}
