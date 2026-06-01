import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:dsa_heldenverwaltung/firebase_options.dart';

/// Beschreibt, ob optionale Firebase-Funktionen beim App-Start verfügbar sind.
class FirebaseBootstrapResult {
  /// Kennzeichnet eine erfolgreiche Firebase-Initialisierung.
  const FirebaseBootstrapResult.available({
    this.isFirestoreAvailable = true,
    this.firestoreUserMessage,
  }) : isAvailable = true,
       userMessage = null,
       technicalDetails = null;

  /// Kennzeichnet einen lokalen Fallback ohne verfügbare Firebase-Dienste.
  const FirebaseBootstrapResult.unavailable({
    required this.userMessage,
    this.technicalDetails,
  }) : isAvailable = false,
       isFirestoreAvailable = false,
       firestoreUserMessage = null;

  /// Gibt an, ob Firebase Auth grundsätzlich initialisiert wurde.
  final bool isAvailable;

  /// Gibt an, ob Firestore-basierte Cloud-Funktionen sicher nutzbar sind.
  final bool isFirestoreAvailable;

  /// Benutzerfreundliche Erklärung für deaktivierte Cloud-Funktionen.
  final String? userMessage;

  /// Benutzerfreundliche Erklärung, wenn nur Firestore deaktiviert ist.
  final String? firestoreUserMessage;

  /// Technische Details für Logs und Diagnose.
  final String? technicalDetails;
}

/// Initialisiert Firebase und fällt bei Fehlern kontrolliert auf Local-Only zurück.
///
/// Die App bleibt auch ohne Firebase benutzbar; lediglich Cloud-Funktionen wie
/// der Konto-Sync werden deaktiviert.
Future<FirebaseBootstrapResult> bootstrapFirebase({
  Future<void> Function()? initializer,
}) async {
  final runInitializer = initializer ?? _initializeFirebase;
  try {
    await runInitializer();
    if (_isFirestoreDisabledForCurrentPlatform()) {
      return const FirebaseBootstrapResult.available(
        isFirestoreAvailable: false,
        firestoreUserMessage:
            'Cloud-Sync ist auf dieser Windows-Version derzeit deaktiviert. '
            'Firebase-Login bleibt verfügbar, die App nutzt lokal gespeicherte Daten.',
      );
    }
    return const FirebaseBootstrapResult.available();
  } on Object catch (error, stackTrace) {
    final result = FirebaseBootstrapResult.unavailable(
      userMessage:
          'Konto-Sync ist derzeit nicht verfügbar. Die lokale '
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

bool _isFirestoreDisabledForCurrentPlatform() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.windows;
}
