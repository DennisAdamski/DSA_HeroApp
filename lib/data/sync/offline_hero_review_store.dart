import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Persistenzvertrag fuer Offline-Helden-Beschluesse eines Konto-Profils.
abstract class OfflineHeroReviewStore {
  /// Laedt alle Beschluesse des aktuellen Konto-Profils.
  Future<List<OfflineHeroReview>> loadAll();

  /// Speichert oder ersetzt den Beschluss zu einem Helden.
  Future<void> save(OfflineHeroReview review);

  /// Entfernt den Beschluss zu [heroId], damit erneut gefragt wird.
  Future<void> delete(String heroId);

  /// Entfernt alle Beschluesse des Konto-Profils.
  Future<void> clear();
}

/// Speicher fuer Offline-Beschluesse in Tests und isolierten Szenarien.
class InMemoryOfflineHeroReviewStore implements OfflineHeroReviewStore {
  final Map<String, OfflineHeroReview> _entries = <String, OfflineHeroReview>{};

  @override
  Future<List<OfflineHeroReview>> loadAll() async {
    return _entries.values.toList(growable: false);
  }

  @override
  Future<void> save(OfflineHeroReview review) async {
    _entries[review.heroId] = review;
  }

  @override
  Future<void> delete(String heroId) async {
    _entries.remove(heroId);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}
