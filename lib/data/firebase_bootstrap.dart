import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:dsa_heldenverwaltung/firebase_options.dart';

/// Beschreibt, ob optionale Firebase-Funktionen beim App-Start verfügbar sind.
class FirebaseBootstrapResult {
  /// Kennzeichnet eine erfolgreiche Firebase-Initialisierung.
  const FirebaseBootstrapResult.available()
    : isAvailable = true,
      userMessage = null,
      technicalDetails = null;

  /// Kennzeichnet einen lokalen Fallback ohne verfügbare Firebase-Dienste.
  const FirebaseBootstrapResult.unavailable({
    required this.userMessage,
    this.technicalDetails,
  }) : isAvailable = false;

  /// Gibt an, ob Firebase erfolgreich initialisiert wurde.
  final bool isAvailable;

  /// Benutzerfreundliche Erklärung für deaktivierte Cloud-Funktionen.
  final String? userMessage;

  /// Technische Details für Logs und Diagnose.
  final String? technicalDetails;
}

/// Initialisiert Firebase und fällt bei Fehlern kontrolliert auf Local-Only zurück.
///
/// Die App bleibt auch ohne Firebase benutzbar; lediglich Cloud-Funktionen wie
/// der Gruppen-Sync werden deaktiviert.
Future<FirebaseBootstrapResult> bootstrapFirebase({
  Future<void> Function()? initializer,
}) async {
  final runInitializer = initializer ?? _initializeFirebase;
  try {
    await runInitializer();
    return const FirebaseBootstrapResult.available();
  } on Object catch (error, stackTrace) {
    final result = FirebaseBootstrapResult.unavailable(
      userMessage:
          'Gruppen-Sync ist derzeit nicht verfügbar. Die lokale '
          'Heldenverwaltung läuft weiter, Cloud-Funktionen benötigen aber '
          'eine erfolgreiche Firebase-Konfiguration.',
      technicalDetails: error.toString(),
    );
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'firebase_bootstrap',
        informationCollector: () sync* {
          yield DiagnosticsProperty<String>(
            'firebaseBootstrapMessage',
            result.userMessage,
          );
        },
      ),
    );
    return result;
  }
}

Future<void> _initializeFirebase() {
  return Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
