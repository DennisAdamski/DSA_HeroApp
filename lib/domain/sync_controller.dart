import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

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
}
