import 'dart:typed_data';

import 'package:dsa_heldenverwaltung/data/cloud_avatar_storage.dart';

/// Speicherbasierte [CloudAvatarStorage] fuer Tests.
///
/// Zaehlt Zugriffe und erlaubt gezielte Fehlerinjektion, damit das
/// Best-Effort-Verhalten pruefbar bleibt.
class InMemoryCloudAvatarStorage implements CloudAvatarStorage {
  InMemoryCloudAvatarStorage({this.available = true});

  /// Dateiname zu Bytes.
  final Map<String, Uint8List> objects = <String, Uint8List>{};

  /// Anzahl der Aufrufe je Methode.
  int uploadCalls = 0;
  int downloadCalls = 0;
  int existsCalls = 0;
  int deleteCalls = 0;

  /// Wenn `true`, wirft [upload].
  bool failUploads = false;

  /// Wenn `true`, wirft [download].
  bool failDownloads = false;

  /// Wenn `true`, wirft [exists].
  bool failExists = false;

  /// Steuert [isAvailable]; simuliert einen abgemeldeten Nutzer.
  bool available;

  @override
  bool get isAvailable => available;

  @override
  Future<void> upload(String fileName, List<int> pngBytes) async {
    uploadCalls++;
    if (failUploads) {
      throw StateError('Upload fehlgeschlagen: $fileName');
    }
    if (!available) return;
    objects[fileName] = Uint8List.fromList(pngBytes);
  }

  @override
  Future<Uint8List?> download(String fileName) async {
    downloadCalls++;
    if (failDownloads) {
      throw StateError('Download fehlgeschlagen: $fileName');
    }
    if (!available) return null;
    return objects[fileName];
  }

  @override
  Future<bool> exists(String fileName) async {
    existsCalls++;
    if (failExists) {
      throw StateError('Existenzpruefung fehlgeschlagen: $fileName');
    }
    if (!available) return false;
    return objects.containsKey(fileName);
  }

  @override
  Future<void> delete(String fileName) async {
    deleteCalls++;
    if (!available) return;
    objects.remove(fileName);
  }
}
