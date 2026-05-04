// Plattformspezifisches Repository fuer importierte Hausregel-Pakete.
// Auf Desktop/Mobile schreibt und liest die IO-Implementierung Manifeste
// im Heldenspeicher. Auf Web liefert die Stub-Implementierung leere
// Snapshots und wirft beim Speichern einen UnsupportedError.
export 'house_rule_pack_repository_io.dart'
    if (dart.library.html) 'house_rule_pack_repository_web.dart';
