import 'package:hive_ce/hive.dart';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht_cache.dart';

/// Hive-basierter [AvatarGesichtCache].
///
/// Liegt im Heldenspeicher neben dem profiluebergreifend geteilten
/// `avatare`-Ordner, nicht im Kontoprofil: Der Befund haengt nur am Bild, nicht
/// am Konto. Im Web landet die Box in IndexedDB.
///
/// Die Box wird lazy beim ersten Zugriff geoeffnet und nach einem fremden
/// Schliessen (etwa beim Profilwechsel im `AppStartupGate`) wieder geoeffnet.
class HiveAvatarGesichtCache implements AvatarGesichtCache {
  HiveAvatarGesichtCache({required this.speicherPfad});

  static const String _boxName = 'avatar_gesicht_v1';

  /// Heldenspeicherpfad, in dem die Box liegt.
  final String speicherPfad;

  Future<Box<Map>>? _boxFuture;

  Future<Box<Map>> _box() async {
    final vorhanden = _boxFuture;
    if (vorhanden != null) {
      final box = await vorhanden;
      if (box.isOpen) return box;
    }
    final neu = Hive.openBox<Map>(_boxName, path: speicherPfad);
    _boxFuture = neu;
    return neu;
  }

  @override
  Future<AvatarGesichtCacheEintrag?> lese(String fileName) async {
    if (fileName.isEmpty) return null;
    final box = await _box();
    return AvatarGesichtCacheEintrag.fromJson(box.get(fileName));
  }

  @override
  Future<void> schreibe(
    String fileName,
    AvatarGesichtCacheEintrag eintrag,
  ) async {
    if (fileName.isEmpty) return;
    final box = await _box();
    await box.put(fileName, eintrag.toJson());
  }
}
