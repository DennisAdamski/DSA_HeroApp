import 'package:path/path.dart' as p;

import 'avatar_file_ops_stub.dart'
    if (dart.library.io) 'avatar_file_ops_io.dart' as file_ops;

/// Speichert und laedt Avatar-Bilder im Heldenspeicher-Verzeichnis.
class AvatarFileStorage {
  const AvatarFileStorage();

  static const String _avatarDir = 'avatare';

  /// Speichert PNG-Bytes als Avatar-Datei und gibt den Dateinamen zurueck.
  Future<String> saveAvatar({
    required String heroStoragePath,
    required String heroId,
    required List<int> pngBytes,
  }) async {
    final fileName = '$heroId.png';
    return file_ops.saveImageFile(
      directoryPath: p.join(heroStoragePath, _avatarDir),
      fileName: fileName,
      pngBytes: pngBytes,
    );
  }

  /// Loest den vollstaendigen Pfad einer Avatar-Datei auf.
  String resolveAvatarPath({
    required String heroStoragePath,
    required String avatarFileName,
  }) {
    return p.join(heroStoragePath, _avatarDir, avatarFileName);
  }

  /// Laedt Avatar-Bytes fuer den Export (base64-Einbettung).
  /// Gibt `null` zurueck, wenn die Datei nicht existiert.
  Future<List<int>?> loadAvatarBytes({
    required String heroStoragePath,
    required String avatarFileName,
  }) async {
    if (avatarFileName.isEmpty) return null;
    return file_ops.loadImageFileBytes(
      filePath: resolveAvatarPath(
        heroStoragePath: heroStoragePath,
        avatarFileName: avatarFileName,
      ),
    );
  }

  /// Loescht die Avatar-Datei eines Helden.
  Future<void> deleteAvatar({
    required String heroStoragePath,
    required String avatarFileName,
  }) async {
    if (avatarFileName.isEmpty) return;
    return file_ops.deleteImageFile(
      filePath: resolveAvatarPath(
        heroStoragePath: heroStoragePath,
        avatarFileName: avatarFileName,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gallery-Methoden fuer Multi-Image-Support
  // ---------------------------------------------------------------------------

  /// Speichert ein Gallery-Bild und gibt den Dateinamen zurueck.
  Future<String> saveGalleryImage({
    required String heroStoragePath,
    required String heroId,
    required String entryId,
    required List<int> pngBytes,
  }) async {
    final fileName = '${heroId}_$entryId.png';
    return file_ops.saveImageFile(
      directoryPath: p.join(heroStoragePath, _avatarDir),
      fileName: fileName,
      pngBytes: pngBytes,
    );
  }

  /// Loescht ein einzelnes Gallery-Bild.
  Future<void> deleteGalleryImage({
    required String heroStoragePath,
    required String fileName,
  }) async {
    if (fileName.isEmpty) return;
    return file_ops.deleteImageFile(
      filePath: p.join(heroStoragePath, _avatarDir, fileName),
    );
  }

  /// Laedt die Bytes eines Gallery-Bildes (fuer Export).
  Future<List<int>?> loadGalleryImageBytes({
    required String heroStoragePath,
    required String fileName,
  }) async {
    if (fileName.isEmpty) return null;
    return file_ops.loadImageFileBytes(
      filePath: p.join(heroStoragePath, _avatarDir, fileName),
    );
  }
}
