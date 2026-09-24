import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/sign_in_screen.dart';

/// Oeffnet den Login- bzw. Registrierungsbildschirm als eigene Route.
///
/// Gemeinsamer Einstieg fuer Einstellungen und den leeren Heldenstart, damit
/// beide denselben Bildschirm im selben Modus zeigen.
Future<void> openSignInScreen(
  BuildContext context,
  AuthService authService, {
  bool register = false,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) =>
          SignInScreen(authService: authService, initialRegisterMode: register),
    ),
  );
}
