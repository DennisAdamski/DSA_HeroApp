import 'package:flutter/foundation.dart';

/// True, wenn der Konto-Sync auf dieser Plattform den Firestore-REST-Transport
/// statt des nativen cloud_firestore-Plugins verwendet (derzeit nur Windows).
///
/// Respektiert `debugDefaultTargetPlatformOverride` und ist damit in Tests
/// plattformunabhängig steuerbar.
bool usesRestFirestoreSyncTransport() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.windows;
}
