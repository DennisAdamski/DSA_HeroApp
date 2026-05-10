import 'package:encrypt/encrypt.dart' show Key;
import 'package:flutter/foundation.dart' hide Key;

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';

/// Schwelle, ab der die Bulk-Entschluesselung in einen Worker / Isolate
/// ausgelagert wird (gemessen in Anzahl `enc:`-Praefixe im Katalog).
///
/// Unter dieser Schwelle ist der Spawn-Overhead groesser als der eigentliche
/// Decrypt; daher synchron im aufrufenden Thread.
const int _offThreadDecryptThreshold = 64;

/// Entschluesselt alle `enc:`-Werte einer [CatalogSourceData] in einem
/// Durchgang und liefert eine neue [CatalogSourceData] mit Klartext-Strings.
///
/// Optimierungen:
/// - v3-Werte (`enc:3:`) nutzen einen einmal abgeleiteten Key aus
///   ([password] + [globalSaltV3]).
/// - v2-Werte (`enc:2:`) und v1-Werte werden ueber den Standard-Decrypt
///   entschluesselt (PBKDF2 pro Wert; Fallback bis zur Asset-Migration).
/// - Bei genuegend hoher Anzahl `enc:`-Werte wird der gesamte Bulk-Decrypt
///   via [compute] auf einen Worker / Isolate ausgelagert, sodass die UI
///   nicht blockiert.
///
/// Werte, die nicht entschluesselt werden koennen (falsches Passwort,
/// fehlender Salt fuer v3, korrupte Daten), bleiben als Originalstring
/// erhalten — die UI-Schicht zeigt dann einen Locked-Hinweis.
Future<CatalogSourceData> decryptAllCatalogValues({
  required CatalogSourceData encrypted,
  required String password,
  required Uint8List? globalSaltV3,
}) async {
  final encCount = _countEncValues(encrypted);
  if (encCount == 0) {
    return encrypted;
  }

  final payload = _DecryptPayload(
    sectionsRaw: <String, List<Map<String, dynamic>>>{
      for (final entry in encrypted.sections.entries)
        entry.key.name: entry.value,
    },
    reisebericht: encrypted.reisebericht,
    password: password,
    globalSaltV3: globalSaltV3,
  );

  final result = encCount >= _offThreadDecryptThreshold
      ? await compute(_decryptPayloadIsolateEntry, payload)
      : _decryptPayload(payload);

  return CatalogSourceData(
    version: encrypted.version,
    source: encrypted.source,
    metadata: encrypted.metadata,
    sections: <CatalogSectionId, List<Map<String, dynamic>>>{
      for (final entry in result.sectionsRaw.entries)
        CatalogSectionId.values.firstWhere((id) => id.name == entry.key):
            entry.value,
    },
    reisebericht: result.reisebericht,
  );
}

/// Top-Level-Funktion fuer [compute]: identisch zu [_decryptPayload].
_DecryptPayload _decryptPayloadIsolateEntry(_DecryptPayload payload) {
  return _decryptPayload(payload);
}

/// Fuehrt die eigentliche Bulk-Entschluesselung synchron aus.
_DecryptPayload _decryptPayload(_DecryptPayload payload) {
  final v3Key = payload.globalSaltV3 == null
      ? null
      : deriveCatalogKey(
          password: payload.password,
          salt: payload.globalSaltV3!,
        );

  final newSections = <String, List<Map<String, dynamic>>>{};
  for (final entry in payload.sectionsRaw.entries) {
    newSections[entry.key] = <Map<String, dynamic>>[
      for (final item in entry.value)
        _walkMap(item, password: payload.password, v3Key: v3Key),
    ];
  }

  final newReisebericht = <Map<String, dynamic>>[
    for (final item in payload.reisebericht)
      _walkMap(item, password: payload.password, v3Key: v3Key),
  ];

  return _DecryptPayload(
    sectionsRaw: newSections,
    reisebericht: newReisebericht,
    password: payload.password,
    globalSaltV3: payload.globalSaltV3,
  );
}

/// Erzeugt eine flache Kopie der Map, in der alle `enc:`-Strings (auch in
/// verschachtelten Listen / Maps) entschluesselt werden.
Map<String, dynamic> _walkMap(
  Map<String, dynamic> input, {
  required String password,
  required Key? v3Key,
}) {
  final result = <String, dynamic>{};
  input.forEach((key, value) {
    result[key] = _walkValue(value, password: password, v3Key: v3Key);
  });
  return result;
}

/// Rekursiv: entschluesselt enc-Strings, durchwandert Listen und Maps.
dynamic _walkValue(
  dynamic value, {
  required String password,
  required Key? v3Key,
}) {
  if (value is String) {
    return _decryptStringIfNeeded(value, password: password, v3Key: v3Key);
  }
  if (value is List) {
    return <dynamic>[
      for (final item in value)
        _walkValue(item, password: password, v3Key: v3Key),
    ];
  }
  if (value is Map<String, dynamic>) {
    return _walkMap(value, password: password, v3Key: v3Key);
  }
  if (value is Map) {
    return _walkMap(
      value.cast<String, dynamic>(),
      password: password,
      v3Key: v3Key,
    );
  }
  return value;
}

/// Entschluesselt einen einzelnen String, falls er ein `enc:`-Praefix traegt.
///
/// Bei Fehler wird der Originalstring zurueckgegeben, damit der Loader
/// weiterhin Daten liefert und die UI einen Locked-Hinweis zeigen kann.
String _decryptStringIfNeeded(
  String value, {
  required String password,
  required Key? v3Key,
}) {
  if (!isEncryptedValue(value)) return value;
  if (value.startsWith('${encryptedPrefix}3:')) {
    if (v3Key == null) return value;
    final decrypted = decryptCatalogValueV3(
      encryptedValue: value,
      derivedKey: v3Key,
    );
    return decrypted ?? value;
  }
  // v2 oder v1 — langsamer Fallback.
  final decrypted = decryptCatalogValue(value, password);
  return decrypted ?? value;
}

/// Zaehlt alle `enc:`-Praefixe in einer [CatalogSourceData] (rekursiv).
int _countEncValues(CatalogSourceData source) {
  var count = 0;
  for (final entries in source.sections.values) {
    for (final entry in entries) {
      count += _countEncInValue(entry);
    }
  }
  for (final entry in source.reisebericht) {
    count += _countEncInValue(entry);
  }
  return count;
}

int _countEncInValue(dynamic value) {
  if (value is String) {
    return isEncryptedValue(value) ? 1 : 0;
  }
  if (value is List) {
    var sum = 0;
    for (final item in value) {
      sum += _countEncInValue(item);
    }
    return sum;
  }
  if (value is Map) {
    var sum = 0;
    for (final item in value.values) {
      sum += _countEncInValue(item);
    }
    return sum;
  }
  return 0;
}

/// Compute-tauglicher Transferdatensatz fuer den Bulk-Decrypt.
///
/// `sectionsRaw` nutzt String-Schluessel statt [CatalogSectionId], damit
/// die Struktur problemlos durch [compute] in einen Worker geschickt werden
/// kann (Enums sind dort nicht zuverlaessig serialisierbar).
class _DecryptPayload {
  const _DecryptPayload({
    required this.sectionsRaw,
    required this.reisebericht,
    required this.password,
    required this.globalSaltV3,
  });

  final Map<String, List<Map<String, dynamic>>> sectionsRaw;
  final List<Map<String, dynamic>> reisebericht;
  final String password;
  final Uint8List? globalSaltV3;
}
