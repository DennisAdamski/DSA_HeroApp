import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/data/registration_invite_client.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';

/// FirebaseAuth-Service fuer optionale Konto-Funktionen.
final authServiceProvider = Provider<AuthService?>((ref) {
  final firebase = ref.watch(firebaseBootstrapProvider);
  if (!firebase.isAvailable) {
    return null;
  }
  const endpoint = String.fromEnvironment('REGISTRATION_INVITE_API_URL');
  final registrationGateway = endpoint.isEmpty
      ? null
      : RegistrationInviteClient(
          endpoint: Uri.parse(endpoint),
          appCheckTokenProvider: () => FirebaseAppCheck.instance.getToken(),
        );
  return AuthService(registrationInviteGateway: registrationGateway);
});

/// Aktuell angemeldeter User oder `null` im Offline-Modus.
final authUserProvider = StreamProvider<AuthUser?>((ref) {
  final service = ref.watch(authServiceProvider);
  if (service == null) {
    return Stream<AuthUser?>.value(null);
  }
  return service.watchUser();
});
