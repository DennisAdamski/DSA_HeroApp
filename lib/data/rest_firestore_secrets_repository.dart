import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/data/firestore_rest_client.dart';
import 'package:dsa_heldenverwaltung/data/firestore_secrets_repository.dart';

/// Firestore-REST-Repository für verschlüsselte Konto-Geheimnisse.
///
/// Wird auf Windows verwendet, damit Settings-Sync nicht den nativen
/// `cloud_firestore`-Pfad berührt. Die eigentlichen Werte bleiben wie bei der
/// nativen Implementierung AES-verschlüsselt.
class RestFirestoreSecretsRepository implements RemoteSecretsRepository {
  /// Erstellt das Repository für `users/{userId}/private/secrets`.
  RestFirestoreSecretsRepository({
    required this.userId,
    required String projectId,
    required Future<String?> Function() idTokenProvider,
    String databaseId = '(default)',
    http.Client? httpClient,
    FirestoreRestClient? restClient,
  }) : _rest =
           restClient ??
           FirestoreRestClient(
             projectId: projectId,
             databaseId: databaseId,
             idTokenProvider: idTokenProvider,
             httpClient: httpClient,
           );

  /// UID des angemeldeten Firebase-Users.
  final String userId;

  final FirestoreRestClient _rest;

  String get _documentPath => 'users/$userId/private/secrets';

  @override
  Future<RemoteSecrets?> load() async {
    final fields = await _rest.getDocumentFields(_documentPath);
    if (fields == null) {
      return null;
    }
    return RemoteSecrets(
      catalogPasswordCipher: _readBytes(fields['catalogPasswordCipher']),
      catalogPasswordIv: _readBytes(fields['catalogPasswordIv']),
      catalogPasswordSet: fields['catalogPasswordSet'] as bool? ?? false,
      apiKeyCipher: _readBytes(fields['apiKeyCipher']),
      apiKeyIv: _readBytes(fields['apiKeyIv']),
      apiProvider: fields['apiProvider'] as String? ?? '',
      cipherVersion: (fields['cipherVersion'] as num?)?.toInt() ?? 1,
      lastModified: fields['lastModified'] is DateTime
          ? fields['lastModified'] as DateTime
          : null,
    );
  }

  @override
  Future<void> save(RemoteSecrets secrets) async {
    await _rest.patchDocumentFields(_documentPath, <String, dynamic>{
      'catalogPasswordCipher': secrets.catalogPasswordCipher,
      'catalogPasswordIv': secrets.catalogPasswordIv,
      'catalogPasswordSet': secrets.catalogPasswordSet,
      'apiKeyCipher': secrets.apiKeyCipher,
      'apiKeyIv': secrets.apiKeyIv,
      'apiProvider': secrets.apiProvider,
      'cipherVersion': secrets.cipherVersion,
      'lastModified': DateTime.now().toUtc(),
    });
  }

  static Uint8List _readBytes(Object? value) {
    if (value is Uint8List) {
      return value;
    }
    if (value is List) {
      return Uint8List.fromList(value.cast<int>());
    }
    return Uint8List(0);
  }
}
