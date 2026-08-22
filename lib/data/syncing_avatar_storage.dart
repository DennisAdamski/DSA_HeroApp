import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:dsa_heldenverwaltung/data/avatar_blob_cache.dart';
import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/data/avatar_load_failure.dart';
import 'package:dsa_heldenverwaltung/data/cloud_avatar_storage.dart';

/// Zeitlimit fuer einzelne Cloud-Operationen.
///
/// Verhindert, dass eine haengende Verbindung das Speichern eines Bildes
/// einfriert.
const Duration _cloudTimeout = Duration(seconds: 20);

/// Verbindet die lokale [AvatarFileStorage] mit einem Cloud-Speicher.
///
/// Schreiben ist local-first: Der lokale Write zaehlt, der Cloud-Upload ist
/// Best-Effort und darf das Speichern nie zum Scheitern bringen. Lesen faellt
/// umgekehrt auf die Cloud zurueck und legt heruntergeladene Bytes lokal ab,
/// damit ein zweites Geraet die Bilder nur einmal holt.
///
/// Wird nur um Implementierungen mit `isCloudBacked == false` gelegt; im Web
/// ist die Plattformimplementierung selbst der Cloud-Speicher.
class SyncingAvatarStorage implements AvatarFileStorage {
  /// Erstellt den Decorator um [local] mit [cloud] als Gegenstelle.
  SyncingAvatarStorage({required this.local, required this.cloud});

  /// Lokale Ablage im Heldenspeicher.
  final AvatarFileStorage local;

  /// Cloud-Gegenstelle, typischerweise Firebase Storage.
  final CloudAvatarStorage cloud;

  @override
  bool get isCloudBacked => false;

  @override
  AvatarBlobCache? get blobCache => local.blobCache;

  @override
  Future<String> saveAvatar({
    required String heroStoragePath,
    required String heroId,
    required List<int> pngBytes,
  }) async {
    final fileName = await local.saveAvatar(
      heroStoragePath: heroStoragePath,
      heroId: heroId,
      pngBytes: pngBytes,
    );
    await _uploadBestEffort(fileName, pngBytes);
    return fileName;
  }

  @override
  String resolveAvatarPath({
    required String heroStoragePath,
    required String avatarFileName,
  }) {
    return local.resolveAvatarPath(
      heroStoragePath: heroStoragePath,
      avatarFileName: avatarFileName,
    );
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
    final fileName = await local.saveGalleryImage(
      heroStoragePath: heroStoragePath,
      heroId: heroId,
      entryId: entryId,
      pngBytes: pngBytes,
    );
    await _uploadBestEffort(fileName, pngBytes);
    return fileName;
  }

  @override
  Future<void> deleteGalleryImage({
    required String heroStoragePath,
    required String fileName,
  }) async {
    await local.deleteGalleryImage(
      heroStoragePath: heroStoragePath,
      fileName: fileName,
    );
    if (fileName.isEmpty || !cloud.isAvailable) return;
    await _guarded(
      () => cloud.delete(fileName),
      context:
          'Avatarbild $fileName konnte nicht aus der Cloud entfernt werden',
    );
  }

  @override
  Future<Uint8List?> loadGalleryImageBytes({
    required String heroStoragePath,
    required String fileName,
  }) async {
    final localBytes = await local.loadGalleryImageBytes(
      heroStoragePath: heroStoragePath,
      fileName: fileName,
    );
    if (localBytes != null) return localBytes;
    if (fileName.isEmpty || !cloud.isAvailable) return null;

    // Anders als beim Schreiben wird ein Lesefehler NICHT geschluckt: Die UI
    // soll den Grund nennen koennen, statt jeden Fehlschlag als leeres Bild
    // darzustellen.
    final Uint8List? remoteBytes;
    try {
      remoteBytes = await cloud.download(fileName).timeout(_cloudTimeout);
    } on AvatarLoadException {
      rethrow;
    } on TimeoutException catch (error) {
      throw AvatarLoadException(
        AvatarLoadFailure.netzwerk,
        details: error.toString(),
      );
    } on Object catch (error) {
      throw AvatarLoadException(
        AvatarLoadFailure.unbekannt,
        details: error.toString(),
      );
    }
    final bytes = remoteBytes;
    if (bytes == null) return null;

    // Heruntergeladene Bytes lokal ablegen, damit weitere Zugriffe offline
    // funktionieren. Ein Schreibfehler darf das Bild nicht verhindern.
    await _guarded(
      () => _cacheLocally(heroStoragePath, fileName, bytes),
      context: 'Avatarbild $fileName konnte nicht lokal abgelegt werden',
    );
    return bytes;
  }

  Future<void> _uploadBestEffort(String fileName, List<int> pngBytes) async {
    if (fileName.isEmpty || !cloud.isAvailable) return;
    await _guarded(
      () => cloud.upload(fileName, pngBytes).timeout(_cloudTimeout),
      context: 'Avatarbild $fileName konnte nicht hochgeladen werden',
    );
  }

  /// Schreibt Bytes unter exakt [fileName] in die lokale Ablage.
  ///
  /// [AvatarFileStorage.saveGalleryImage] baut den Dateinamen selbst aus
  /// `heroId` und `entryId` zusammen und kann Legacy-Namen wie
  /// `{heroId}.png` deshalb nicht reproduzieren. Der Umweg ueber
  /// [AvatarFileStorage.saveAvatar] mit `heroId` = Name ohne Endung liefert
  /// genau den gewuenschten Dateinamen.
  Future<void> _cacheLocally(
    String heroStoragePath,
    String fileName,
    List<int> bytes,
  ) {
    final baseName = fileName.endsWith('.png')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    return local.saveAvatar(
      heroStoragePath: heroStoragePath,
      heroId: baseName,
      pngBytes: bytes,
    );
  }

  Future<void> _guarded(
    Future<void> Function() action, {
    required String context,
  }) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'syncing_avatar_storage',
          context: ErrorDescription(context),
        ),
      );
    }
  }
}
