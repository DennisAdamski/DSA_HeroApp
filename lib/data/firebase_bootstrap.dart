import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:dsa_heldenverwaltung/data/sync/sync_transport.dart';
import 'package:dsa_heldenverwaltung/firebase_options.dart';

/// Beschreibt, ob optionale Firebase-Funktionen beim App-Start verfügbar sind.
class FirebaseBootstrapResult {
  /// Kennzeichnet eine erfolgreiche Firebase-Initialisierung.
  const FirebaseBootstrapResult.available({
    this.isFirestoreAvailable = true,
    bool? isAccountSyncAvailable,
    this.firestoreUserMessage,
  }) : isAvailable = true,
       isAccountSyncAvailable = isAccountSyncAvailable ?? isFirestoreAvailable,
       userMessage = null,
       technicalDetails = null;

  /// Kennzeichnet einen lokalen Fallback ohne verfügbare Firebase-Dienste.
  const FirebaseBootstrapResult.unavailable({
    required this.userMessage,
    this.technicalDetails,
  }) : isAvailable = false,
       isFirestoreAvailable = false,
       isAccountSyncAvailable = false,
       firestoreUserMessage = null;

  /// Gibt an, ob Firebase Auth grundsätzlich initialisiert wurde.
  final bool isAvailable;

  /// Gibt an, ob Firestore-basierte Cloud-Funktionen sicher nutzbar sind.
  final bool isFirestoreAvailable;

  /// Gibt an, ob der private Konto-Sync sicher nutzbar ist.
  final bool isAccountSyncAvailable;

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
    if (usesRestFirestoreSyncTransport()) {
      return const FirebaseBootstrapResult.available(
        isFirestoreAvailable: false,
        isAccountSyncAvailable: true,
        firestoreUserMessage:
            'Konto-Sync nutzt auf Windows den REST-Transport. '
            'Andere Firestore-Cloudfunktionen sind dort derzeit deaktiviert.',
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

Future<void> _initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
}

/// Entscheidet, ob App Check auf der aktuellen Plattform aktiviert werden kann.
///
/// Windows besitzt derzeit nur einen Debug-Provider. Ohne ausdrücklich
/// konfiguriertes Debug-Token bleibt App Check dort aus, damit ein
/// Produktionsstart nicht die übrige Firebase-Initialisierung blockiert.
bool shouldActivateFirebaseAppCheck({
  required bool isWeb,
  required TargetPlatform platform,
  required bool hasWindowsDebugToken,
}) {
  if (isWeb) {
    return true;
  }
  return platform != TargetPlatform.windows || hasWindowsDebugToken;
}

Future<void> _activateAppCheck() async {
  const siteKey = String.fromEnvironment('FIREBASE_APP_CHECK_SITE_KEY');
  const debugToken = String.fromEnvironment('FIREBASE_APP_CHECK_DEBUG_TOKEN');

  if (kIsWeb && kReleaseMode && siteKey.isEmpty) {
    throw StateError('FIREBASE_APP_CHECK_SITE_KEY fehlt im Release-Build.');
  }

  final shouldActivate = shouldActivateFirebaseAppCheck(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    hasWindowsDebugToken: debugToken.isNotEmpty,
  );
  if (!shouldActivate) {
    return;
  }

  final webProvider = kReleaseMode
      ? ReCaptchaEnterpriseProvider(siteKey)
      : WebDebugProvider(debugToken: debugToken.isEmpty ? null : debugToken);
  final windowsProvider = WindowsDebugProvider(
    debugToken: debugToken.isEmpty ? null : debugToken,
  );
  await FirebaseAppCheck.instance.activate(
    providerWeb: webProvider,
    providerAndroid: const AndroidPlayIntegrityProvider(),
    providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
    providerWindows: windowsProvider,
  );
}
