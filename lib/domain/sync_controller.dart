import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';

/// Was eine automatische Zusammenführung eines Konflikts ergäbe (ARCH-06).
class SyncKonfliktVorschau {
  /// Erzeugt die Vorschau.
  const SyncKonfliktVorschau({
    required this.felder,
    required this.vonLokal,
    required this.vonOnline,
  });

  /// Werte, die beide Seiten verschieden geändert haben; nur sie brauchen
  /// eine Entscheidung.
  final List<SyncKonfliktFeld> felder;

  /// Änderungen dieses Geräts, die automatisch übernommen werden.
  final int vonLokal;

  /// Online-Änderungen, die automatisch übernommen werden.
  final int vonOnline;
}

/// Steuervertrag fuer den Konto-Sync aus UI- und App-Start-Schicht.
abstract class AppSyncController {
  /// Aktueller Status ohne Stream-Abonnement.
  SyncStatusSnapshot get currentStatus;

  /// Reaktiver Status-Stream mit initialem Snapshot.
  Stream<SyncStatusSnapshot> watchStatus();

  /// Startet einen manuellen Sync.
  Future<void> syncNow();

  /// Loest einen offenen Konflikt.
  Future<void> resolveConflict(
    String conflictId,
    SyncResolutionChoice resolution,
  );

  /// Vorschau der automatischen Zusammenführung oder `null`, wenn für den
  /// Konflikt kein gemeinsamer Basisstand vorliegt (ältere Abgleiche,
  /// Löschungen, Offline-Helden). Dann bleibt nur „Nur Online“, „Nur Lokal“
  /// oder „Beide behalten“.
  Future<SyncKonfliktVorschau?> konfliktVorschau(String conflictId) async {
    return null;
  }

  /// Führt beide Stände automatisch zusammen (ARCH-06).
  ///
  /// [entscheidungen] lösen die echten Konflikte aus [konfliktVorschau] über
  /// ihren Schlüssel. Bleibt einer offen oder ist keine Zusammenführung
  /// möglich, wirft der Aufruf einen [StateError].
  Future<void> resolveConflictAutomatisch(
    String conflictId,
    Map<String, SyncSeite> entscheidungen,
  ) async {
    throw StateError('Automatisches Zusammenführen wird nicht unterstützt.');
  }

  /// Feld-Diff fuer einen offenen Konflikt oder `null`, wenn fuer die
  /// Konflikt-ID keine vollstaendigen Objektdaten verfuegbar sind.
  SyncObjectDiff? conflictDiff(String conflictId);

  /// Bereits getroffene Entscheidungen zu Offline-Helden.
  ///
  /// Die Standardimplementierung liefert eine leere Liste, damit einfache
  /// Controller-Attrappen ohne Offline-Beschluesse auskommen.
  Future<List<OfflineHeroReview>> listOfflineHeroReviews() async {
    return const <OfflineHeroReview>[];
  }

  /// Verwirft den Beschluss zu [heroId] und stellt den Konflikt erneut.
  Future<void> reopenOfflineHeroReview(String heroId) async {}

  /// Verwirft alle Beschluesse zu Offline-Helden.
  Future<void> clearOfflineHeroReviews() async {}
}
