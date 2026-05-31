import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';

/// FirebaseAuth-Service fuer optionale Konto-Funktionen.
final authServiceProvider = Provider<AuthService?>((ref) {
  final firebase = ref.watch(firebaseBootstrapProvider);
  if (!firebase.isAvailable) {
    return null;
  }
  return AuthService();
});

/// Aktuell angemeldeter User oder `null` im Offline-Modus.
final authUserProvider = StreamProvider<AuthUser?>((ref) {
  final service = ref.watch(authServiceProvider);
  if (service == null) {
    return Stream<AuthUser?>.value(null);
  }
  return service.watchUser();
});
