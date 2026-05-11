import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';

/// Hinweistext fuer gesperrte Kataloginhalte.
const lockedContentHint =
    'Inhalt gesperrt – bitte in den Einstellungen freischalten.';

/// Hinweistext fuer geschuetzte Katalogdetails, die erst auf Abruf geladen
/// werden.
const protectedContentDetailHint = 'Details öffnen';

/// Prueft, ob ein Katalogwert verschluesselt abgelegt ist.
bool isProtectedCatalogValue(dynamic raw) {
  return isEncryptedValue(raw);
}

/// In-Memory-Cache fuer entschluesselte Katalogwerte.
///
/// Der Cache verhindert wiederholte PBKDF2/AES-Arbeit in UI-Flows, in denen
/// dieselben geschuetzten Inhalte mehrfach angezeigt werden. Besitzer sollen
/// [clear] aufrufen, wenn sich Freischaltstatus oder Passwort aendern.
class ProtectedContentCache {
  final Map<String, _CachedProtectedValue<String?>> _valueCache =
      <String, _CachedProtectedValue<String?>>{};
  final Map<String, _CachedProtectedValue<List<String>?>> _listCache =
      <String, _CachedProtectedValue<List<String>?>>{};

  /// Leert alle gespeicherten Entschluesselungsergebnisse.
  void clear() {
    _valueCache.clear();
    _listCache.clear();
  }

  /// Loest einen geschuetzten String-Wert auf und cached verschluesselte Werte.
  String? resolveValue({
    required String raw,
    required bool unlocked,
    required String? password,
  }) {
    if (!isEncryptedValue(raw)) {
      return raw;
    }
    if (!unlocked || password == null || password.isEmpty) {
      return null;
    }

    final cached = _valueCache[raw];
    if (cached != null && cached.password == password) {
      return cached.value;
    }

    final decrypted = decryptCatalogValue(raw, password);
    _valueCache[raw] = _CachedProtectedValue<String?>(
      password: password,
      value: decrypted,
    );
    return decrypted;
  }

  /// Loest ein geschuetztes String-Array auf und cached verschluesselte Werte.
  List<String>? resolveList({
    required dynamic raw,
    required bool unlocked,
    required String? password,
  }) {
    if (raw is List) {
      return raw.map((entry) => entry.toString()).toList(growable: false);
    }
    if (raw is! String || !isEncryptedValue(raw)) {
      return const <String>[];
    }
    if (!unlocked || password == null || password.isEmpty) {
      return null;
    }

    final cached = _listCache[raw];
    if (cached != null && cached.password == password) {
      return cached.value;
    }

    final decrypted = decryptCatalogList(raw, password);
    final cachedValue = decrypted == null
        ? null
        : List<String>.unmodifiable(decrypted);
    _listCache[raw] = _CachedProtectedValue<List<String>?>(
      password: password,
      value: cachedValue,
    );
    return cachedValue;
  }
}

class _CachedProtectedValue<T> {
  const _CachedProtectedValue({required this.password, required this.value});

  final String password;
  final T value;
}

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
