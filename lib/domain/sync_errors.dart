/// Typisierte Fehler des Konto-Syncs.
///
/// Gateways und Transportclients werfen diese Typen, damit Repository und UI
/// zwischen Auth-, Netzwerk-, Konflikt- und Datenfehlern unterscheiden
/// koennen, statt nur Fehlertexte zu vergleichen.
sealed class SyncException implements Exception {
  /// Erstellt einen Sync-Fehler mit benutzerlesbarer [message].
  const SyncException(this.message, {this.cause});

  /// Benutzerlesbare Beschreibung des Fehlers.
  final String message;

  /// Urspruenglicher Fehler, falls dieser Fehler einen anderen umhuellt.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Fehlendes, abgelaufenes oder abgelehntes Auth-Token (401/403).
final class SyncAuthException extends SyncException {
  /// Erstellt einen Auth-Fehler.
  const SyncAuthException(super.message, {super.cause});
}

/// Netzwerk- oder Verfuegbarkeitsfehler (Timeouts, Offline, 5xx).
final class SyncNetworkException extends SyncException {
  /// Erstellt einen Netzwerkfehler.
  const SyncNetworkException(super.message, {super.cause});
}

/// Verletzte Revisions-/updateTime-Precondition beim Schreiben.
///
/// Signalisiert einen parallelen Schreibzugriff und wird vom Repository in
/// einen [SyncConflict]-Flow ueberfuehrt statt still zu ueberschreiben.
final class SyncPreconditionException extends SyncException {
  /// Erstellt einen Precondition-Fehler.
  const SyncPreconditionException(
    super.message, {
    this.expectedRevision,
    this.actualRevision,
    super.cause,
  });

  /// Revision, die der Client zuletzt gesehen hat.
  final String? expectedRevision;

  /// Tatsaechliche Revision auf dem Server (falls bekannt).
  final String? actualRevision;
}

/// Nicht dekodierbare oder unbrauchbare Remote-Daten.
final class SyncDecodeException extends SyncException {
  /// Erstellt einen Dekodierfehler.
  const SyncDecodeException(super.message, {super.cause});
}

/// Kategorie eines Sync-Fehlers fuer Status-Anzeige und UI-Entscheidungen.
enum SyncErrorKind {
  /// Anmeldung erforderlich oder Token abgelaufen.
  auth,

  /// Voraussichtlich voruebergehender Netzwerk-/Serverfehler.
  network,

  /// Paralleler Schreibzugriff, Konfliktaufloesung noetig.
  conflict,

  /// Remote-Daten konnten nicht uebernommen werden.
  decode,

  /// Nicht klassifizierter Fehler.
  unknown,
}

/// Unveraenderliche, UI-taugliche Beschreibung des letzten Sync-Fehlers.
class SyncFailure {
  /// Erstellt eine Fehlerbeschreibung.
  const SyncFailure({required this.kind, required this.message, this.occurredAt});

  /// Klassifiziert einen beliebigen Fehler anhand seines Typs.
  factory SyncFailure.fromError(Object error, {DateTime? occurredAt}) {
    final kind = switch (error) {
      SyncAuthException() => SyncErrorKind.auth,
      SyncNetworkException() => SyncErrorKind.network,
      SyncPreconditionException() => SyncErrorKind.conflict,
      SyncDecodeException() => SyncErrorKind.decode,
      _ => SyncErrorKind.unknown,
    };
    final message = error is SyncException ? error.message : error.toString();
    return SyncFailure(kind: kind, message: message, occurredAt: occurredAt);
  }

  /// Fehlerkategorie.
  final SyncErrorKind kind;

  /// Benutzerlesbare Beschreibung.
  final String message;

  /// Zeitpunkt des Fehlers (optional).
  final DateTime? occurredAt;
}
