import 'package:hive/hive.dart';

/// Vermerk, dass ein Avatarbild mit der Cloud abgeglichen ist.
class AvatarSyncMarker {
  const AvatarSyncMarker({required this.byteLength, required this.syncedAt});

  /// Groesse der abgeglichenen Datei; erkennt spaetere Aenderungen.
  final int byteLength;

  /// Zeitpunkt des Abgleichs.
  final DateTime syncedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'byteLength': byteLength,
    'syncedAt': syncedAt.toUtc().toIso8601String(),
  };

  static AvatarSyncMarker? fromJson(Map<String, dynamic> json) {
    final byteLength = json['byteLength'];
    final syncedAt = DateTime.tryParse((json['syncedAt'] as String?) ?? '');
    if (byteLength is! int || syncedAt == null) return null;
    return AvatarSyncMarker(byteLength: byteLength, syncedAt: syncedAt);
  }
}

/// Haelt fest, welche Avatarbilder bereits mit der Cloud abgeglichen sind.
///
/// Liegt bewusst im Kontoprofil (`<base>/accounts/<uid>/`) und nicht neben den
/// Bildern: Der `avatare`-Ordner wird von allen Profilen eines Geraets geteilt,
/// die Cloud-Ablage dagegen ist pro Konto getrennt.
abstract class AvatarSyncMarkerStore {
  /// Liest den Vermerk zu [fileName].
  AvatarSyncMarker? load(String fileName);

  /// Schreibt den Vermerk zu [fileName].
  Future<void> save(String fileName, AvatarSyncMarker marker);
}

/// Hive-basierte [AvatarSyncMarkerStore].
class HiveAvatarSyncMarkerStore implements AvatarSyncMarkerStore {
  HiveAvatarSyncMarkerStore._(this._box);

  static const String _boxName = 'avatar_sync_v1';

  final Box<Map> _box;

  /// Oeffnet die Marker-Box im angegebenen Profilpfad.
  static Future<HiveAvatarSyncMarkerStore> create({
    required String storagePath,
  }) async {
    final box = await Hive.openBox<Map>(_boxName, path: storagePath);
    return HiveAvatarSyncMarkerStore._(box);
  }

  @override
  AvatarSyncMarker? load(String fileName) {
    final raw = _box.get(fileName);
    if (raw == null) return null;
    return AvatarSyncMarker.fromJson(raw.cast<String, dynamic>());
  }

  @override
  Future<void> save(String fileName, AvatarSyncMarker marker) {
    return _box.put(fileName, marker.toJson());
  }

  /// Schliesst die zugrunde liegende Hive-Box.
  Future<void> close() async {
    await _box.close();
  }
}

/// Speicherbasierte [AvatarSyncMarkerStore] fuer Tests.
class InMemoryAvatarSyncMarkerStore implements AvatarSyncMarkerStore {
  final Map<String, AvatarSyncMarker> markers = <String, AvatarSyncMarker>{};

  @override
  AvatarSyncMarker? load(String fileName) => markers[fileName];

  @override
  Future<void> save(String fileName, AvatarSyncMarker marker) async {
    markers[fileName] = marker;
  }
}
