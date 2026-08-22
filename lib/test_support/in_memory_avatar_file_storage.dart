import 'dart:typed_data';

import 'package:dsa_heldenverwaltung/data/avatar_blob_cache.dart';
import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';

/// Speicherbasierte [AvatarFileStorage] fuer Tests.
///
/// Bildet den lokalen `avatare`-Ordner als Map ab und zaehlt Zugriffe, damit
/// Tests pruefen koennen, ob ein Cloud-Umweg genommen wurde.
class InMemoryAvatarFileStorage implements AvatarFileStorage {
  InMemoryAvatarFileStorage({this.isCloudBacked = false});

  /// Dateiname zu Bytes, unabhaengig vom Heldenspeicherpfad.
  final Map<String, Uint8List> files = <String, Uint8List>{};

  /// Dateinamen in Aufrufreihenfolge von [saveGalleryImage] und [saveAvatar].
  final List<String> savedFileNames = <String>[];

  /// Dateinamen in Aufrufreihenfolge von [deleteGalleryImage].
  final List<String> deletedFileNames = <String>[];

  /// Wenn gesetzt, liefern die Speichermethoden einen leeren Dateinamen.
  bool failSaves = false;

  @override
  final bool isCloudBacked;

  @override
  AvatarBlobCache? blobCache;

  @override
  Future<String> saveAvatar({
    required String heroStoragePath,
    required String heroId,
    required List<int> pngBytes,
  }) async {
    if (failSaves) return '';
    final fileName = '$heroId.png';
    files[fileName] = Uint8List.fromList(pngBytes);
    savedFileNames.add(fileName);
    return fileName;
  }

  @override
  String resolveAvatarPath({
    required String heroStoragePath,
    required String avatarFileName,
  }) {
    return '$heroStoragePath/avatare/$avatarFileName';
  }

  @override
  Future<Uint8List?> loadAvatarBytes({
    required String heroStoragePath,
    required String avatarFileName,
  }) async {
    return files[avatarFileName];
  }

  @override
  Future<void> deleteAvatar({
    required String heroStoragePath,
    required String avatarFileName,
  }) async {
    files.remove(avatarFileName);
    deletedFileNames.add(avatarFileName);
  }

  @override
  Future<String> saveGalleryImage({
    required String heroStoragePath,
    required String heroId,
    required String entryId,
    required List<int> pngBytes,
  }) async {
    if (failSaves) return '';
    final fileName = '${heroId}_$entryId.png';
    files[fileName] = Uint8List.fromList(pngBytes);
    savedFileNames.add(fileName);
    return fileName;
  }

  @override
  Future<void> deleteGalleryImage({
    required String heroStoragePath,
    required String fileName,
  }) async {
    files.remove(fileName);
    deletedFileNames.add(fileName);
  }

  @override
  Future<Uint8List?> loadGalleryImageBytes({
    required String heroStoragePath,
    required String fileName,
  }) async {
    return files[fileName];
  }
}
