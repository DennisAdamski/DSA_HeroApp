import 'package:hive/hive.dart';

import 'package:dsa_heldenverwaltung/data/sync/offline_hero_review_store.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Hive-basierter Speicher fuer Offline-Helden-Beschluesse eines Kontos.
///
/// Die Box liegt im Konto-Profilpfad neben `sync_metadata_v1`. Die Beschluesse
/// gelten damit pro Konto: meldet sich ein anderes Konto an, wird erneut
/// gefragt.
class HiveOfflineHeroReviewStore implements OfflineHeroReviewStore {
  HiveOfflineHeroReviewStore._(this._box);

  static const String _boxName = 'offline_hero_review_v1';

  final Box<Map> _box;

  /// Oeffnet die Beschluss-Box im angegebenen Profilpfad.
  static Future<HiveOfflineHeroReviewStore> create({
    required String storagePath,
  }) async {
    final box = await Hive.openBox<Map>(_boxName, path: storagePath);
    return HiveOfflineHeroReviewStore._(box);
  }

  @override
  Future<List<OfflineHeroReview>> loadAll() async {
    return _box.values
        .map((raw) => OfflineHeroReview.fromJson(raw.cast<String, dynamic>()))
        .where((review) => review.heroId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> save(OfflineHeroReview review) async {
    await _box.put(review.heroId, review.toJson());
  }

  @override
  Future<void> delete(String heroId) async {
    await _box.delete(heroId);
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  /// Schliesst die zugrunde liegende Hive-Box.
  Future<void> close() async {
    await _box.close();
  }
}
