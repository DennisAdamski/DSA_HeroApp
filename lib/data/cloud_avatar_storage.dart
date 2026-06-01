import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Maximale Anzahl KI-generierter Bilder pro Nutzer im Cloud-Speicher.
const int maxKiBilderOnline = 2;

/// Verwaltet KI-generierte Avatar-Bilder in Firebase Storage.
///
/// Speicherpfad: `avatars/{uid}/{fileName}`.
class CloudAvatarStorage {
  const CloudAvatarStorage();

  static const String _prefix = 'avatars';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get isAvailable => _uid != null;

  String _path(String fileName) => '$_prefix/${_uid!}/$fileName';

  Future<void> upload(String fileName, List<int> pngBytes) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = FirebaseStorage.instance.ref(_path(fileName));
    await ref.putData(
      Uint8List.fromList(pngBytes),
      SettableMetadata(contentType: 'image/png'),
    );
  }

  Future<void> delete(String fileName) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseStorage.instance.ref(_path(fileName)).delete();
    } on FirebaseException {
      // Datei existiert moeglicherweise nicht.
    }
  }

  Future<Uint8List?> download(String fileName) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      return await FirebaseStorage.instance.ref(_path(fileName)).getData();
    } on FirebaseException {
      return null;
    }
  }

  /// Loest den Firebase-Storage-Referenzpfad fuer eine Datei auf.
  String resolvePath(String fileName) {
    final uid = _uid;
    if (uid == null || uid.isEmpty || fileName.isEmpty) return '';
    return '$_prefix/$uid/$fileName';
  }
}
