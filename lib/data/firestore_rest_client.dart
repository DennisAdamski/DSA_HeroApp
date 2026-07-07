import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';

/// Kleiner Firestore-REST-Client für Plattformen ohne stabilen nativen SDK-Pfad.
///
/// Der Client authentifiziert jeden Request mit einem Firebase-ID-Token. Damit
/// gelten weiterhin die normalen Firestore Security Rules des angemeldeten
/// Users; es wird kein Admin- oder Service-Account-Zugriff verwendet.
class FirestoreRestClient {
  /// Erstellt einen REST-Client für ein Firebase-Projekt.
  FirestoreRestClient({
    required this.projectId,
    required this.idTokenProvider,
    this.databaseId = '(default)',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Firebase/Google-Cloud-Projekt-ID.
  final String projectId;

  /// Firestore-Datenbank-ID, in Firebase-Projekten normalerweise `(default)`.
  final String databaseId;

  /// Liefert das aktuelle Firebase Auth ID Token für Security Rules.
  final Future<String?> Function() idTokenProvider;

  final http.Client _http;

  /// Lädt ein einzelnes Dokument inklusive Server-`updateTime`.
  Future<FirestoreRestDocument?> getDocument(String documentPath) async {
    final headers = await _authHeaders();
    final response = await _send(
      () => _http.get(_documentUri(documentPath), headers: headers),
    );
    if (response.statusCode == 404) {
      return null;
    }
    final body = _decodeSuccess(response);
    return FirestoreRestDocument.fromJson(body);
  }

  /// Lädt ein einzelnes Dokument und gibt dessen dekodierte Felder zurück.
  Future<Map<String, dynamic>?> getDocumentFields(String documentPath) async {
    final document = await getDocument(documentPath);
    return document?.fields;
  }

  /// Listet alle Dokumente einer Collection mit dekodierten Feldern.
  Future<List<FirestoreRestDocument>> listDocuments(
    String collectionPath,
  ) async {
    final headers = await _authHeaders();
    final response = await _send(
      () => _http.get(_documentUri(collectionPath), headers: headers),
    );
    if (response.statusCode == 404) {
      return const <FirestoreRestDocument>[];
    }
    final body = _decodeSuccess(response);
    final rawDocuments = body['documents'];
    if (rawDocuments is! List) {
      return const <FirestoreRestDocument>[];
    }
    return rawDocuments
        .whereType<Map>()
        .map((entry) => FirestoreRestDocument.fromJson(_castMap(entry)))
        .toList(growable: false);
  }

  /// Schreibt ein Dokument per PATCH und gibt die dekodierten Antwortfelder zurück.
  ///
  /// [updateTimePrecondition] bzw. [existsPrecondition] werden als
  /// `currentDocument.*`-Precondition mitgesendet; verletzt der Server sie,
  /// antwortet er mit 409/`FAILED_PRECONDITION`, was als
  /// [SyncPreconditionException] auftaucht.
  Future<Map<String, dynamic>> patchDocumentFields(
    String documentPath,
    Map<String, dynamic> fields, {
    DateTime? updateTimePrecondition,
    bool? existsPrecondition,
  }) async {
    final body = <String, dynamic>{'fields': _encodeFields(fields)};
    final headers = await _authHeaders(contentTypeJson: true);
    final query = <String, String>{
      if (updateTimePrecondition != null)
        'currentDocument.updateTime': updateTimePrecondition
            .toUtc()
            .toIso8601String(),
      if (existsPrecondition != null)
        'currentDocument.exists': existsPrecondition.toString(),
    };
    final response = await _send(
      () => _http.patch(
        _documentUri(documentPath, queryParameters: query),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
    return _decodeFields(_decodeSuccess(response));
  }

  Future<Map<String, String>> _authHeaders({
    bool contentTypeJson = false,
  }) async {
    final token = await idTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const SyncAuthException(
        'Kein Firebase-ID-Token für Firestore-REST verfügbar.',
      );
    }
    return <String, String>{
      'authorization': 'Bearer $token',
      if (contentTypeJson) 'content-type': 'application/json',
    };
  }

  Uri _documentUri(String path, {Map<String, String>? queryParameters}) {
    final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
    return Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/$databaseId/documents/$encodedPath',
      queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  /// Führt einen HTTP-Request aus und übersetzt Transportfehler in
  /// [SyncNetworkException].
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on http.ClientException catch (error) {
      throw SyncNetworkException(
        'Firestore-REST ist nicht erreichbar: ${error.message}',
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw SyncNetworkException(
        'Firestore-REST-Request hat das Zeitlimit überschritten.',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _decodeSuccess(http.Response response) {
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      final description =
          'Firestore-REST-Request fehlgeschlagen ($status): ${response.body}';
      if (status == 401 || status == 403) {
        throw SyncAuthException(description);
      }
      if (status == 409 || response.body.contains('FAILED_PRECONDITION')) {
        throw SyncPreconditionException(description);
      }
      if (status >= 500) {
        throw SyncNetworkException(description);
      }
      throw StateError(description);
    }
    if (response.body.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      return _castMap(decoded);
    }
    return const <String, dynamic>{};
  }
}

/// Dekodiertes Firestore-REST-Dokument aus einer Collection-Abfrage.
class FirestoreRestDocument {
  /// Erstellt einen dekodierten Dokument-Snapshot.
  const FirestoreRestDocument({
    required this.name,
    required this.id,
    required this.fields,
    this.updateTime,
  });

  /// Vollständiger Firestore-Ressourcenname.
  final String name;

  /// Letztes Segment des Dokumentpfads.
  final String id;

  /// Plain-Dart-Felder des Dokuments.
  final Map<String, dynamic> fields;

  /// Server-Zeitstempel der letzten Änderung (für Preconditions).
  final DateTime? updateTime;

  /// Dekodiert ein REST-Dokument.
  factory FirestoreRestDocument.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final segments = name.split('/');
    final rawId = segments.isEmpty ? '' : segments.last;
    final rawUpdateTime = json['updateTime'];
    return FirestoreRestDocument(
      name: name,
      id: Uri.decodeComponent(rawId),
      fields: _decodeFields(json),
      updateTime: rawUpdateTime is String
          ? DateTime.tryParse(rawUpdateTime)
          : null,
    );
  }
}

Map<String, dynamic> _encodeFields(Map<String, dynamic> fields) {
  return fields.map((key, value) => MapEntry(key, _encodeValue(value)));
}

Map<String, dynamic> _decodeFields(Map<String, dynamic> json) {
  final fields = json['fields'];
  if (fields is! Map) {
    return const <String, dynamic>{};
  }
  return _castMap(
    fields,
  ).map((key, value) => MapEntry(key, _decodeValue(_castMap(value as Map))));
}

Map<String, dynamic> _encodeValue(Object? value) {
  if (value == null) {
    return const <String, dynamic>{'nullValue': null};
  }
  if (value is bool) {
    return <String, dynamic>{'booleanValue': value};
  }
  if (value is int) {
    return <String, dynamic>{'integerValue': value.toString()};
  }
  if (value is double) {
    return <String, dynamic>{'doubleValue': value};
  }
  if (value is DateTime) {
    return <String, dynamic>{'timestampValue': value.toUtc().toIso8601String()};
  }
  if (value is Uint8List) {
    return <String, dynamic>{'bytesValue': base64Encode(value)};
  }
  if (value is String) {
    return <String, dynamic>{'stringValue': value};
  }
  if (value is Iterable) {
    final values = value.map(_encodeValue).toList(growable: false);
    return <String, dynamic>{
      'arrayValue': <String, dynamic>{'values': values},
    };
  }
  if (value is Map) {
    final fields = value.map(
      (key, entry) => MapEntry(key.toString(), _encodeValue(entry)),
    );
    return <String, dynamic>{
      'mapValue': <String, dynamic>{'fields': fields},
    };
  }
  throw UnsupportedError('Firestore-REST-Wert wird nicht unterstützt: $value');
}

Object? _decodeValue(Map<String, dynamic> value) {
  if (value.containsKey('nullValue')) {
    return null;
  }
  if (value.containsKey('booleanValue')) {
    return value['booleanValue'] as bool? ?? false;
  }
  if (value.containsKey('integerValue')) {
    final raw = value['integerValue'];
    return int.tryParse(raw.toString()) ?? 0;
  }
  if (value.containsKey('doubleValue')) {
    final raw = value['doubleValue'];
    return raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;
  }
  if (value.containsKey('timestampValue')) {
    final raw = value['timestampValue'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }
  if (value.containsKey('bytesValue')) {
    final raw = value['bytesValue'];
    return raw is String ? base64Decode(raw) : Uint8List(0);
  }
  if (value.containsKey('stringValue')) {
    return value['stringValue'] as String? ?? '';
  }
  if (value.containsKey('arrayValue')) {
    final arrayValue = value['arrayValue'];
    if (arrayValue is! Map) {
      return const <dynamic>[];
    }
    final values = _castMap(arrayValue)['values'];
    if (values is! List) {
      return const <dynamic>[];
    }
    return values
        .whereType<Map>()
        .map((entry) => _decodeValue(_castMap(entry)))
        .toList(growable: false);
  }
  if (value.containsKey('mapValue')) {
    final mapValue = value['mapValue'];
    if (mapValue is! Map) {
      return const <String, dynamic>{};
    }
    final fields = _castMap(mapValue)['fields'];
    if (fields is! Map) {
      return const <String, dynamic>{};
    }
    return _castMap(
      fields,
    ).map((key, entry) => MapEntry(key, _decodeValue(_castMap(entry as Map))));
  }
  return null;
}

Map<String, dynamic> _castMap(Map<dynamic, dynamic> raw) {
  return raw.map((key, value) => MapEntry(key.toString(), value));
}
