import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Browser-Download fuer JSON-Exporte.
///
/// Nur aus `*_web.dart`-Implementierungen importieren: die Datei haengt an
/// `package:web` und ist auf anderen Plattformen nicht uebersetzbar.
///
/// Bewusst `package:web` + `dart:js_interop` statt `dart:html`. Letzteres ist
/// deprecated und wird von `dart2wasm` nicht uebersetzt — solange es hier
/// stand, musste der Web-Build mit `--no-wasm-dry-run` an der Pruefung
/// vorbeigefuehrt werden.
void triggerJsonDownload({
  required String fileName,
  required String jsonPayload,
}) {
  final bytes = utf8.encode(jsonPayload);
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// Entfernt Zeichen, die in Dateinamen nicht zulaessig sind.
///
/// [fallback] greift, wenn der Wunschname leer ist oder nur Leerzeichen traegt.
String sanitizeDownloadFileName(String value, {required String fallback}) {
  final trimmed = value.trim().isEmpty ? fallback : value.trim();
  return trimmed.replaceAll(RegExp(r'[<>:"/\|?*\x00-\x1F]'), '_');
}
