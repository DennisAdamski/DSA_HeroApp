// Plattformspezifisches Repository fuer Custom-Katalogeintraege.
// Auf Desktop/Mobile schreibt und liest die IO-Implementierung Dateien
// im Heldenspeicher. Auf Web liefert die Stub-Implementierung leere
// Snapshots und wirft bei Schreibvorgaengen einen UnsupportedError.
export 'custom_catalog_repository_io.dart'
    if (dart.library.html) 'custom_catalog_repository_web.dart';
