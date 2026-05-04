import 'package:path/path.dart' as p;

/// Web-Stub fuer [AvatarFileStorage].
///
/// Im Web steht kein lokales Dateisystem zur Verfuegung. Saemtliche
/// Operationen sind No-Ops bzw. liefern leere Resultate. Das Avatar-Feature
/// ist im Web v1 deaktiviert.
class AvatarFileStorage {
  const AvatarFileStorage();

  static const String _avatarDir = 'avatare';

  Future<String> saveAvatar({
    required String heroStoragePath,
    required String heroId,
    required List<int> pngBytes,
  }) async {
    return '';
  }

  String resolveAvatarPath({
    required String heroStoragePath,
    required String avatarFileName,
  }) {
    return p.join(heroStoragePath, _avatarDir, avatarFileName);
  }

  Future<List<int>?> loadAvatarBytes({
    required String heroStoragePath,
    required String avatarFileName,
  }) async {
    return null;
  }

  Future<void> deleteAvatar({
    required String heroStoragePath,
    required String avatarFileName,
  }) async {
    // No-Op auf Web.
  }

  Future<String> saveGalleryImage({
    required String heroStoragePath,
    required String heroId,
    required String entryId,
    required List<int> pngBytes,
  }) async {
    return '';
  }

  Future<void> deleteGalleryImage({
    required String heroStoragePath,
    required String fileName,
  }) async {
    // No-Op auf Web.
  }

  Future<List<int>?> loadGalleryImageBytes({
    required String heroStoragePath,
    required String fileName,
  }) async {
    return null;
  }
}
