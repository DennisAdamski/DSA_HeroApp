import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Verschluesselter Snapshot der pro-User-Geheimnisse, wie er von Firestore
/// abgelegt/abgerufen wird. Cipher-Bytes und IVs sind opak — die eigentliche
/// Ent-/Verschluesselung liegt eine Schicht hoeher (siehe `SecretsCipher`).
class RemoteSecrets {
  const RemoteSecrets({
    required this.catalogPasswordCipher,
    required this.catalogPasswordIv,
    required this.catalogPasswordSet,
    required this.apiKeyCipher,
    required this.apiKeyIv,
    required this.apiProvider,
    required this.cipherVersion,
    required this.lastModified,
  });

  final Uint8List catalogPasswordCipher;
  final Uint8List catalogPasswordIv;
  final bool catalogPasswordSet;
  final Uint8List apiKeyCipher;
  final Uint8List apiKeyIv;
  final String apiProvider;
  final int cipherVersion;
  final DateTime? lastModified;
}

/// Abstraktion fuer die Remote-Persistenz der pro-User-Geheimnisse.
///
/// Existiert separat zur konkreten Firestore-Implementierung, damit die
/// uebergeordnete Settings-Schicht in Tests gegen ein Fake getestet werden
/// kann.
abstract class RemoteSecretsRepository {
  Future<RemoteSecrets?> load();
  Future<void> save(RemoteSecrets secrets);
}

/// Firestore-basierter Remote-Speicher fuer pro-User-Geheimnisse.
///
/// Pfad: `users/{userId}/private/secrets`. Die abgelegten Geheimnisse sind
/// AES-CBC-verschluesselt; der Schluessel wird aus der UID abgeleitet.
class FirestoreSecretsRepository implements RemoteSecretsRepository {
  FirestoreSecretsRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('users').doc(userId).collection('private').doc('secrets');

  @override
  Future<RemoteSecrets?> load() async {
    final snapshot = await _ref.get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    final lastModifiedRaw = data['lastModified'];
    return RemoteSecrets(
      catalogPasswordCipher: _readBytes(data['catalogPasswordCipher']),
      catalogPasswordIv: _readBytes(data['catalogPasswordIv']),
      catalogPasswordSet: (data['catalogPasswordSet'] as bool?) ?? false,
      apiKeyCipher: _readBytes(data['apiKeyCipher']),
      apiKeyIv: _readBytes(data['apiKeyIv']),
      apiProvider: (data['apiProvider'] as String?) ?? '',
      cipherVersion: (data['cipherVersion'] as int?) ?? 1,
      lastModified: lastModifiedRaw is Timestamp ? lastModifiedRaw.toDate() : null,
    );
  }

  @override
  Future<void> save(RemoteSecrets secrets) async {
    await _ref.set(<String, dynamic>{
      'catalogPasswordCipher': Blob(secrets.catalogPasswordCipher),
      'catalogPasswordIv': Blob(secrets.catalogPasswordIv),
      'catalogPasswordSet': secrets.catalogPasswordSet,
      'apiKeyCipher': Blob(secrets.apiKeyCipher),
      'apiKeyIv': Blob(secrets.apiKeyIv),
      'apiProvider': secrets.apiProvider,
      'cipherVersion': secrets.cipherVersion,
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  static Uint8List _readBytes(Object? value) {
    if (value is Blob) {
      return Uint8List.fromList(value.bytes);
    }
    if (value is Uint8List) {
      return value;
    }
    if (value is List) {
      return Uint8List.fromList(value.cast<int>());
    }
    return Uint8List(0);
  }
}
