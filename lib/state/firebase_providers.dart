import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';

/// Laufzeitstatus der optionalen Firebase-Initialisierung.
final firebaseBootstrapProvider = Provider<FirebaseBootstrapResult>((ref) {
  return const FirebaseBootstrapResult.unavailable(
    userMessage:
        'Firebase wurde für diese Sitzung nicht initialisiert. '
        'Lokale Funktionen bleiben verfügbar.',
  );
});
