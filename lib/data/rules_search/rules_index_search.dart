/// Plattform-Fassade der Regel-Volltextsuche.
///
/// Reicht je nach Build-Ziel die IO-Implementierung (Desktop), die
/// WASM/IndexedDB-Implementierung (Web) oder den Stub (z. B. Mobile) durch.
/// Aufrufer importieren ausschließlich diese Datei und
/// `rules_index_types.dart`.
library;

export 'rules_index_search_stub.dart'
    if (dart.library.html) 'rules_index_search_web.dart'
    if (dart.library.io) 'rules_index_search_io.dart';
