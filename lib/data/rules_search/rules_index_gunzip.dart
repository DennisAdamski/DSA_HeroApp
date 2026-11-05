/// Entpackt eine gzip-Antwort, falls sie noch gepackt ankam.
///
/// Normalerweise liefert der Speicher die Datei mit `Content-Encoding: gzip`,
/// und Browser wie Dart entpacken sie beim Laden selbst. Fehlt diese Kopfzeile
/// (etwa nach einem Upload ohne `--content-encoding=gzip`), kommen die gzip-
/// Bytes unveraendert an; diese Fassung faengt das auf dem Desktop auf, im Web
/// meldet sie es als Fehler.
library;

export 'rules_index_gunzip_stub.dart'
    if (dart.library.io) 'rules_index_gunzip_io.dart';
