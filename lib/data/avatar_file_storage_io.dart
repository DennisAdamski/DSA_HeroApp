import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:dsa_heldenverwaltung/data/avatar_blob_cache.dart';
import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';

/// Speichert und laedt Avatar-Bilder im Heldenspeicher-Verzeichnis.
class LocalAvatarFileStorage implements AvatarFileStorage {
  const LocalAvatarFileStorage();

  static const String _avatarDir = 'avatare';

  @override
  bool get isCloudBacked => false;

  /// Die Dateisystem-Ablage braucht keinen Cache — die Bytes liegen bereits
  /// lokal.
  @override
  AvatarBlobCache? get blobCache => null;

  @override
  Future<String> saveAvatar({
    required String heroStoragePath,
    required String heroId,
    required List<int> pngBytes,
  }) async {
    final fileName = '$heroId.png';
    await _write(heroStoragePath, fileName, pngBytes);
    return fileName;
  }

  @override
  String resolveAvatarPath({
    required String heroStoragePath,
    required String avatarFileName,
  }) {
    return p.join(heroStoragePath, _avatarDir, avatarFileName);
  }

  @override
  Future<Uint8List?> loadAvatarBytes({
    required String heroStoragePath,
    required String avatarFileName,
  }) {
    return loadGalleryImageBytes(
      heroStoragePath: heroStoragePath,
      fileName: avatarFileName,
    );
  }

  @override
  Future<void> deleteAvatar({
    required String heroStoragePath,
    required String avatarFileName,
  }) {
    return deleteGalleryImage(
      heroStoragePath: heroStoragePath,
      fileName: avatarFileName,
    );
  }

  @override
  Future<String> saveGalleryImage({
    required String heroStoragePath,
    required String heroId,
    required String entryId,
    required List<int> pngBytes,
  }) async {
    final fileName = '${heroId}_$entryId.png';
    await _write(heroStoragePath, fileName, pngBytes);
    return fileName;
  }

  @override
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

  @override
  Future<Uint8List?> loadGalleryImageBytes({
    required String heroStoragePath,
    required String fileName,
  }) async {
    if (fileName.isEmpty) return null;
    final file = File(p.join(heroStoragePath, _avatarDir, fileName));
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  Future<void> _write(
    String heroStoragePath,
    String fileName,
    List<int> pngBytes,
  ) async {
    final dir = Directory(p.join(heroStoragePath, _avatarDir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(pngBytes, flush: true);
  }
}

AvatarFileStorage createAvatarFileStorageImpl() {
  return const LocalAvatarFileStorage();
}
