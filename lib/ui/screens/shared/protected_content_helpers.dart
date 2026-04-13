import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';

/// Hinweistext fuer gesperrte Kataloginhalte.
const lockedContentHint =
    'Inhalt gesperrt – bitte in den Einstellungen freischalten.';

/// Loest einen moeglicherweise verschluesselten String-Wert auf.
///
/// - Nicht verschluesselt → Klartext zurueck.
/// - Verschluesselt + [unlocked] + gueltiges [password] → entschluesselt.
/// - Verschluesselt + gesperrt → `null`.
String? resolveProtectedValue({
  required String raw,
  required bool unlocked,
  required String? password,
}) {
  if (!isEncryptedValue(raw)) return raw;
  if (!unlocked || password == null || password.isEmpty) return null;
  return decryptCatalogValue(raw, password);
}

/// Loest ein moeglicherweise verschluesseltes String-Array auf.
///
/// Verschluesselte Arrays sind als einzelner `enc:`-String gespeichert.
/// Gibt `null` zurueck wenn gesperrt, sonst die entschluesselte Liste.
List<String>? resolveProtectedList({
  required dynamic raw,
  required bool unlocked,
  required String? password,
}) {
  if (raw is List) {
    return raw.map((e) => e.toString()).toList(growable: false);
  }
  if (raw is String && isEncryptedValue(raw)) {
    if (!unlocked || password == null || password.isEmpty) return null;
    return decryptCatalogList(raw, password);
  }
  return const <String>[];
}
