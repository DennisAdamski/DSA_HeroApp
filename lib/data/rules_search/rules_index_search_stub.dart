import 'dart:typed_data';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';

/// Fallback-Variante (z. B. Mobile): keine lokale Regel-Wissensbasis verfügbar.
bool rulesIndexSearchSupported() => false;

/// Fallback-Variante: liefert immer `null`.
Future<RulesIndexSearch?> openRulesIndexSearch({String? dataDirectory}) async =>
    null;

/// Fallback-Variante: Datei-Import ist nur auf Web implementiert.
Future<RulesIndexSearch> importRulesIndexDatabase(
  Uint8List bytes, {
  String? dataDirectory,
}) {
  throw UnsupportedError(
    'Index-Import wird auf dieser Plattform nicht unterstützt.',
  );
}
