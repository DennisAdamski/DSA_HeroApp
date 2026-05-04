// Plattformspezifische Avatardatei-Persistenz.
// Auf Desktop/Mobile schreibt/liest der IO-Implementierung Dateien im
// Heldenspeicher. Auf Web sind alle Operationen No-Ops.
export 'avatar_file_storage_io.dart'
    if (dart.library.html) 'avatar_file_storage_web.dart';
