import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';

/// Stand der Cloud-Sicherung unmittelbar vor dem Abmelden.
class AbmeldeBefund {
  /// Erstellt den Befund.
  const AbmeldeBefund({
    this.offeneKonflikte = 0,
    this.ausstehendeVorgaenge = 0,
    this.syncFehler,
  });

  /// Alles ist in der Cloud: nichts geht beim Abmelden verloren.
  static const AbmeldeBefund gesichert = AbmeldeBefund();

  /// Konflikte, die noch keine Entscheidung haben.
  final int offeneKonflikte;

  /// Getroffene, aber noch nicht vollständig abgelegte Entscheidungen.
  final int ausstehendeVorgaenge;

  /// Meldung des letzten Sync-Fehlers oder `null`.
  final String? syncFehler;

  /// Ob alle lokalen Änderungen sicher in der Cloud liegen.
  bool get istGesichert =>
      offeneKonflikte == 0 && ausstehendeVorgaenge == 0 && syncFehler == null;
}

/// Gleicht vor dem Abmelden ein letztes Mal ab und meldet, was offen bleibt.
///
/// Nach dem Abmelden werden die Online-Helden dieses Geräts entfernt; was bis
/// dahin nicht hochgeladen oder entschieden ist, ginge verloren. Ohne
/// [controller] (reiner Offline-Betrieb) gibt es nichts zu sichern.
Future<AbmeldeBefund> pruefeVorAbmeldung(AppSyncController? controller) async {
  if (controller == null) {
    return AbmeldeBefund.gesichert;
  }
  await controller.syncNow();
  await controller.warteAufUebertragungen();
  final status = controller.currentStatus;
  return AbmeldeBefund(
    offeneKonflikte: status.openConflicts.length,
    ausstehendeVorgaenge: status.ausstehendeVorgaenge,
    syncFehler: status.lastFailure == null
        ? null
        : (status.lastError ?? 'Unbekannter Sync-Fehler'),
  );
}
