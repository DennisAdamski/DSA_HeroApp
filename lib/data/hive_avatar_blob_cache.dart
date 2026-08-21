import 'dart:typed_data';

import 'package:hive/hive.dart';

import 'package:dsa_heldenverwaltung/data/avatar_blob_cache.dart';

/// Hive-basierter [AvatarBlobCache].
///
/// Im Web landet die Box in IndexedDB und ist damit an die Origin gebunden —
/// derselbe Grund, aus dem beim lokalen Debuggen ein fester `--web-port` noetig
/// ist.
///
/// Die Box wird bewusst **lazy** beim ersten Zugriff geoeffnet und das `Future`
/// gemerkt: So bleibt `avatarFileStorageProvider` synchron und der Cache
/// braucht kein Startup-Plumbing im `AppStartupGate`.
class HiveAvatarBlobCache implements AvatarBlobCache {
  HiveAvatarBlobCache();

  static const String _boxName = 'avatar_blobs_v1';

  Future<Box<Uint8List>>? _boxFuture;

  Future<Box<Uint8List>> _box() {
    return _boxFuture ??= Hive.openBox<Uint8List>(_boxName);
  }

  @override
  Future<Uint8List?> read(String fileName) async {
    if (fileName.isEmpty) return null;
    final box = await _box();
    return box.get(fileName);
  }

  @override
  Future<void> write(String fileName, Uint8List bytes) async {
    if (fileName.isEmpty) return;
    final box = await _box();
    await box.put(fileName, bytes);
  }

  @override
  Future<void> remove(String fileName) async {
    if (fileName.isEmpty) return;
    final box = await _box();
    await box.delete(fileName);
  }

  @override
  Future<int> entferneVerwaiste(Set<String> behalten) async {
    final box = await _box();
    final verwaist = box.keys
        .cast<String>()
        .where((key) => !behalten.contains(key))
        .toList(growable: false);
    if (verwaist.isEmpty) return 0;
    await box.deleteAll(verwaist);
    return verwaist.length;
  }

  /// Schliesst die Box, sofern sie geoeffnet wurde.
  Future<void> close() async {
    final pending = _boxFuture;
    if (pending == null) return;
    _boxFuture = null;
    await (await pending).close();
  }
}
