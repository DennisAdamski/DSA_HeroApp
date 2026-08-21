import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:dsa_heldenverwaltung/data/avatar_blob_cache.dart';
import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/data/avatar_load_failure.dart';
import 'package:dsa_heldenverwaltung/data/hive_avatar_blob_cache.dart';

/// Web-Implementierung von [AvatarFileStorage].
///
/// Speichert Avatar-Bilder in Firebase Storage, da im Browser kein
/// lokales Dateisystem zur Verfuegung steht.
/// Pfadschema: `avatars/{uid}/{fileName}`.
///
/// Gelesene Bytes landen zusaetzlich in [cache] (IndexedDB), damit ein Reload
/// die Bilder nicht erneut ueber die Leitung holt.
///
/// Bewusst **kein** `SyncingAvatarStorage` drumherum: Dort gilt der lokale
/// Write als Erfolg und der Upload ist Best-Effort. IndexedDB ist im Browser
/// aber kein haltbarer Speicher — ein Bild darf hier erst als gespeichert
/// gelten, wenn der Upload durch ist. Deshalb bleibt [isCloudBacked] `true`.
class FirebaseAvatarFileStorage implements AvatarFileStorage {
  FirebaseAvatarFileStorage({AvatarBlobCache? cache})
    : cache = cache ?? HiveAvatarBlobCache();

  static const String _prefix = 'avatars';

  /// Zwischenspeicher fuer bereits geladene Bytes.
  final AvatarBlobCache cache;

  @override
  AvatarBlobCache? get blobCache => cache;

  @override
  bool get isCloudBacked => true;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Baut den Cloud-Pfad und wirft, wenn kein Konto angemeldet ist.
  ///
  /// Frueher lieferte diese Stelle bei fehlender uid einen leeren String —
  /// ununterscheidbar von „Bild existiert nicht" und damit die Hauptquelle
  /// stummer Platzhalter im Web.
  String _cloudPath(String fileName) {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw const AvatarLoadException(AvatarLoadFailure.nichtAngemeldet);
    }
    return '$_prefix/$uid/$fileName';
  }

  @override
  Future<String> saveAvatar({
    required String heroStoragePath,
    required String heroId,
    required List<int> pngBytes,
  }) {
    return _upload('$heroId.png', pngBytes);
  }

  @override
  String resolveAvatarPath({
    required String heroStoragePath,
    required String avatarFileName,
  }) {
    if (avatarFileName.isEmpty) return '';
    return _cloudPath(avatarFileName);
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
  }) {
    return _upload('${heroId}_$entryId.png', pngBytes);
  }

  @override
  Future<void> deleteGalleryImage({
    required String heroStoragePath,
    required String fileName,
  }) async {
    if (fileName.isEmpty) return;
    await _removeCache(fileName);
    try {
      await FirebaseStorage.instance.ref(_cloudPath(fileName)).delete();
    } on FirebaseException {
      // Datei existiert moeglicherweise nicht.
    } on AvatarLoadException {
      // Ohne Konto gibt es nichts zu loeschen.
    }
  }

  @override
  Future<Uint8List?> loadGalleryImageBytes({
    required String heroStoragePath,
    required String fileName,
  }) async {
    if (fileName.isEmpty) return null;

    // Cache zuerst, und bewusst vor `_cloudPath`: Ein bereits geladenes Bild
    // soll auch dann sichtbar bleiben, wenn die Sitzung abgemeldet ist.
    final cached = await _readCache(fileName);
    if (cached != null) return cached;

    final path = _cloudPath(fileName);
    try {
      final bytes = await FirebaseStorage.instance.ref(path).getData();
      if (bytes == null) {
        // `getData()` liefert null, wenn die Datei das Limit ueberschreitet.
        throw const AvatarLoadException(AvatarLoadFailure.zuGross);
      }
      await _writeCache(fileName, bytes);
      return bytes;
    } on FirebaseException catch (error) {
      // Wirklich fehlende Dateien sind kein Fehler, sondern der Normalfall
      // fuer Galerie-Eintraege, deren Bytes nie hochgeladen wurden.
      if (error.code == 'object-not-found') return null;
      if (error.code == 'unauthorized') {
        throw AvatarLoadException(
          AvatarLoadFailure.keineBerechtigung,
          details: error.code,
        );
      }
      throw AvatarLoadException(
        AvatarLoadFailure.netzwerk,
        details: '${error.code}: ${error.message}',
      );
    } on AvatarLoadException {
      rethrow;
    } on Object catch (error, stackTrace) {
      // firebase_storage_web laedt die Bytes per `http.readBytes` statt ueber
      // das JS-SDK und greift auf `metadata.size!` zu. Beides kann Fehler
      // werfen, die `guard()` unveraendert durchreicht — ein reines
      // `on FirebaseException` wuerde sie verpassen.
      //
      // Der Sammelfall wird zusaetzlich geloggt: Ein Tooltip ist beim
      // Diagnostizieren zu fluechtig, und `runtimeType` grenzt die Ursache
      // deutlich schaerfer ein als die Meldung allein.
      debugPrint(
        '[avatar] Laden von $path fehlgeschlagen: '
        '${error.runtimeType} — $error',
      );
      debugPrintStack(stackTrace: stackTrace, label: '[avatar]');
      throw AvatarLoadException(
        AvatarLoadFailure.unbekannt,
        details: '${error.runtimeType}: $error',
      );
    }
  }

  /// Cache-Zugriffe duerfen den Bildabruf nie zum Scheitern bringen.
  ///
  /// Ein blockiertes IndexedDB (privater Modus, gesperrte Site-Daten) ist ein
  /// Komfortverlust, kein Fehler.
  Future<Uint8List?> _readCache(String fileName) async {
    try {
      return await cache.read(fileName);
    } on Object catch (error) {
      debugPrint('[avatar] Cache-Lesen fehlgeschlagen: $error');
      return null;
    }
  }

  Future<void> _writeCache(String fileName, Uint8List bytes) async {
    try {
      await cache.write(fileName, bytes);
    } on Object catch (error) {
      debugPrint('[avatar] Cache-Schreiben fehlgeschlagen: $error');
    }
  }

  Future<void> _removeCache(String fileName) async {
    try {
      await cache.remove(fileName);
    } on Object catch (error) {
      debugPrint('[avatar] Cache-Loeschen fehlgeschlagen: $error');
    }
  }

  Future<String> _upload(String fileName, List<int> pngBytes) async {
    final path = _cloudPath(fileName);
    // Der Content-Type ist bewusst pauschal `image/png`: die Galerie speichert
    // auch hochgeladene JPEGs unter `.png`. Die Storage-Regel prueft deshalb
    // nur auf `image/.*`.
    await FirebaseStorage.instance
        .ref(path)
        .putData(
          Uint8List.fromList(pngBytes),
          SettableMetadata(contentType: 'image/png'),
        );
    await _writeCache(fileName, Uint8List.fromList(pngBytes));
    return fileName;
  }
}

AvatarFileStorage createAvatarFileStorageImpl() {
  return FirebaseAvatarFileStorage();
}
