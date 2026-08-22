import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Maximale Anzahl KI-generierter Bilder pro Held im Cloud-Speicher.
const int maxKiBilderProHeld = 2;

/// Maximale Anzahl von Helden pro Nutzer.
const int maxHeldenProNutzer = 5;

/// Maximale Groesse eines einzelnen Avatarbildes in Bytes.
///
/// Muss zur Groessenbedingung in `storage.rules` passen.
const int maxAvatarBildBytes = 8 * 1024 * 1024;

/// Cloud-Ablage fuer Avatarbilder.
///
/// Speicherpfad: `avatars/{uid}/{fileName}`.
abstract class CloudAvatarStorage {
  /// Gibt an, ob ein angemeldeter Nutzer Cloud-Zugriff hat.
  bool get isAvailable;

  /// Laedt Bytes unter [fileName] hoch.
  Future<void> upload(String fileName, List<int> pngBytes);

  /// Laedt die Bytes zu [fileName] herunter, oder `null` wenn nicht vorhanden.
  Future<Uint8List?> download(String fileName);

  /// Prueft, ob [fileName] in der Cloud liegt, ohne die Bytes zu laden.
  Future<bool> exists(String fileName);

  /// Loescht [fileName] aus der Cloud.
  Future<void> delete(String fileName);
}

/// Verwaltet Avatarbilder in Firebase Storage.
class FirebaseCloudAvatarStorage implements CloudAvatarStorage {
  const FirebaseCloudAvatarStorage();

  static const String _prefix = 'avatars';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  bool get isAvailable {
    final uid = _uid;
    return uid != null && uid.isNotEmpty;
  }

  String _path(String fileName) => '$_prefix/${_uid!}/$fileName';

  @override
  Future<void> upload(String fileName, List<int> pngBytes) async {
    if (!isAvailable || fileName.isEmpty) return;
    // Siehe `FirebaseAvatarFileStorage._upload`: der Content-Type ist bewusst
    // pauschal `image/png`.
    await FirebaseStorage.instance
        .ref(_path(fileName))
        .putData(
          Uint8List.fromList(pngBytes),
          SettableMetadata(contentType: 'image/png'),
        );
  }

  @override
  Future<void> delete(String fileName) async {
    if (!isAvailable || fileName.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(_path(fileName)).delete();
    } on FirebaseException {
      // Datei existiert moeglicherweise nicht.
    }
  }

  @override
  Future<Uint8List?> download(String fileName) async {
    if (!isAvailable || fileName.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(_path(fileName)).getData();
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<bool> exists(String fileName) async {
    if (!isAvailable || fileName.isEmpty) return false;
    try {
      await FirebaseStorage.instance.ref(_path(fileName)).getMetadata();
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return false;
      }
      // Netz- und Rechtefehler duerfen nicht als "fehlt" gelten, sonst
      // laedt der Backfill unnoetig erneut hoch.
      rethrow;
    }
  }
}
