import 'dart:io';

import 'package:path/path.dart' as p;

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
    final dir = Directory(p.join(heroStoragePath, _avatarDir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final fileName = '$heroId.png';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(pngBytes, flush: true);
    return fileName;
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
    final file = File(
      resolveAvatarPath(
        heroStoragePath: heroStoragePath,
        avatarFileName: avatarFileName,
      ),
    );
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Loescht die Avatar-Datei eines Helden.
  Future<void> deleteAvatar({
    required String heroStoragePath,
    required String avatarFileName,
  }) async {
    if (avatarFileName.isEmpty) return;
    final file = File(
      resolveAvatarPath(
        heroStoragePath: heroStoragePath,
        avatarFileName: avatarFileName,
      ),
    );
    if (file.existsSync()) {
      await file.delete();
    }
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
    final dir = Directory(p.join(heroStoragePath, _avatarDir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final fileName = '${heroId}_$entryId.png';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(pngBytes, flush: true);
    return fileName;
  }

  /// Loescht ein einzelnes Gallery-Bild.
  Future<void> deleteGalleryImage({
    required String heroStoragePath,
    required String fileName,
  }) async {
    if (fileName.isEmpty) return;
    final file = File(p.join(heroStoragePath, _avatarDir, fileName));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Laedt die Bytes eines Gallery-Bildes (fuer Export).
  Future<List<int>?> loadGalleryImageBytes({
    required String heroStoragePath,
    required String fileName,
  }) async {
    if (fileName.isEmpty) return null;
    final file = File(p.join(heroStoragePath, _avatarDir, fileName));
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }
}
