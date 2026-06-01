import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Web-Implementierung von [AvatarFileStorage].
///
/// Speichert Avatar-Bilder in Firebase Storage, da im Browser kein
/// lokales Dateisystem zur Verfuegung steht.
/// Pfadschema: `avatars/{uid}/{fileName}`.
class AvatarFileStorage {
  const AvatarFileStorage();

  static const String _prefix = 'avatars';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String _cloudPath(String fileName) {
    final uid = _uid;
    if (uid == null || uid.isEmpty || fileName.isEmpty) return '';
    return '$_prefix/$uid/$fileName';
  }

  Future<String> saveAvatar({
    required String heroStoragePath,
    required String heroId,
    required List<int> pngBytes,
  }) async {
    final fileName = '$heroId.png';
    final path = _cloudPath(fileName);
    if (path.isEmpty) return '';
    await FirebaseStorage.instance.ref(path).putData(
      Uint8List.fromList(pngBytes),
      SettableMetadata(contentType: 'image/png'),
    );
    return fileName;
  }

  String resolveAvatarPath({
    required String heroStoragePath,
    required String avatarFileName,
  }) {
    return _cloudPath(avatarFileName);
  }

  Future<List<int>?> loadAvatarBytes({
    required String heroStoragePath,
    required String avatarFileName,
  }) async {
    if (avatarFileName.isEmpty) return null;
    final path = _cloudPath(avatarFileName);
    if (path.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(path).getData();
    } on FirebaseException {
      return null;
    }
  }

  Future<void> deleteAvatar({
    required String heroStoragePath,
    required String avatarFileName,
  }) async {
    if (avatarFileName.isEmpty) return;
    final path = _cloudPath(avatarFileName);
    if (path.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } on FirebaseException {
      // Datei existiert moeglicherweise nicht.
    }
  }

  Future<String> saveGalleryImage({
    required String heroStoragePath,
    required String heroId,
    required String entryId,
    required List<int> pngBytes,
  }) async {
    final fileName = '${heroId}_$entryId.png';
    final path = _cloudPath(fileName);
    if (path.isEmpty) return '';
    await FirebaseStorage.instance.ref(path).putData(
      Uint8List.fromList(pngBytes),
      SettableMetadata(contentType: 'image/png'),
    );
    return fileName;
  }

  Future<void> deleteGalleryImage({
    required String heroStoragePath,
    required String fileName,
  }) async {
    if (fileName.isEmpty) return;
    final path = _cloudPath(fileName);
    if (path.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } on FirebaseException {
      // Datei existiert moeglicherweise nicht.
    }
  }

  Future<List<int>?> loadGalleryImageBytes({
    required String heroStoragePath,
    required String fileName,
  }) async {
    if (fileName.isEmpty) return null;
    final path = _cloudPath(fileName);
    if (path.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(path).getData();
    } on FirebaseException {
      return null;
    }
  }
}
