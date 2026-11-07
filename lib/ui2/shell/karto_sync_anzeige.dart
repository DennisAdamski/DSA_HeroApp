import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/sync_anzeige_rules.dart';

/// Wie dringend ein Syncstand die Aufmerksamkeit braucht.
enum KartoSyncStufe {
  /// Abgeglichen oder gerade im Abgleich; nichts zu tun.
  ruhig,

  /// Der Nutzer muss etwas entscheiden (Konflikte, offene Entscheidungen).
  entscheidung,

  /// Der letzte Abgleich ist fehlgeschlagen.
  fehler,
}

/// Darstellbare Zusammenfassung des Konto-Syncs für den Workspace.
@immutable
class KartoSyncAnzeige {
  /// Erstellt eine Anzeige aus Stufe, Symbol und Kurztext.
  const KartoSyncAnzeige({
    required this.stufe,
    required this.icon,
    required this.text,
    this.laeuft = false,
  });

  /// Dringlichkeit; bestimmt Farbe und Betonung.
  final KartoSyncStufe stufe;

  /// Symbol zur Stufe.
  final IconData icon;

  /// Kurztext für Fußzeile und Tooltip.
  final String text;

  /// Ob gerade ein Abgleich läuft.
  final bool laeuft;
}

/// Ordnet einen [SyncStatusSnapshot] einer [KartoSyncAnzeige] zu.
///
/// Ohne Konto gibt es nichts anzuzeigen (`null`): der reine Offlinebetrieb ist
/// der Normalfall und kein Zustand, auf den hingewiesen werden müsste. Die
/// Reihenfolge ist die der Dringlichkeit: Konflikte, offene Entscheidungen,
/// Fehler, laufender Abgleich, dann der Zeitpunkt des letzten Abgleichs.
KartoSyncAnzeige? beschreibeKartoSync(
  SyncStatusSnapshot status, {
  required DateTime jetzt,
}) {
  if (!status.isOnlineAccount) return null;
  final konflikte = status.openConflicts.length;
  if (konflikte > 0) {
    return KartoSyncAnzeige(
      stufe: KartoSyncStufe.entscheidung,
      icon: Icons.report_problem_outlined,
      text: konflikte == 1
          ? 'Sync: 1 Konflikt offen'
          : 'Sync: $konflikte Konflikte offen',
    );
  }
  if (status.ausstehendeVorgaenge > 0) {
    return const KartoSyncAnzeige(
      stufe: KartoSyncStufe.entscheidung,
      icon: Icons.pending_actions_outlined,
      text: 'Sync: Entscheidung nicht abgeschlossen',
    );
  }
  final fehler = status.lastFailure;
  if (fehler != null) {
    return KartoSyncAnzeige(
      stufe: KartoSyncStufe.fehler,
      icon: switch (fehler.kind) {
        SyncErrorKind.network => Icons.cloud_off_outlined,
        _ => Icons.sync_problem_outlined,
      },
      text: switch (fehler.kind) {
        SyncErrorKind.network => 'Sync: Cloud nicht erreichbar',
        SyncErrorKind.auth => 'Sync: Anmeldung erneuern',
        _ => 'Sync fehlgeschlagen',
      },
    );
  }
  if (status.isSyncing) {
    return const KartoSyncAnzeige(
      stufe: KartoSyncStufe.ruhig,
      icon: Icons.sync,
      text: 'Sync läuft …',
      laeuft: true,
    );
  }
  final zuletzt = status.lastSuccessfulSync;
  return KartoSyncAnzeige(
    stufe: KartoSyncStufe.ruhig,
    icon: Icons.cloud_done_outlined,
    text: zuletzt == null
        ? 'Sync: noch nicht abgeglichen'
        : 'Abgeglichen ${formatiereSyncZeitpunkt(zuletzt, jetzt: jetzt)}',
  );
}
