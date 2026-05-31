import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';

/// Beobachtet optional den Firebase-Login und startet die App immer weiter.
///
/// Ohne Login bleibt die App im lokalen Offline-Profil. Sobald ein User
/// angemeldet ist, baut der nachgelagerte App-Start ein accountgebundenes
/// lokales Profil mit Remote-Sync auf. Der Login selbst wird ueber die
/// Einstellungen geoeffnet, nicht mehr als Pflicht-Gate.
class WebAuthGate extends StatefulWidget {
  const WebAuthGate({
    super.key,
    required this.firebaseBootstrap,
    required this.builder,
    AuthService? authService,
  }) : _authService = authService;

  /// Ergebnis der Firebase-Initialisierung; bestimmt ob Login moeglich ist.
  final FirebaseBootstrapResult firebaseBootstrap;

  /// Baut den eigentlichen App-Inhalt mit dem (optionalen) eingeloggten User.
  final Widget Function(BuildContext context, AuthUser? user) builder;

  final AuthService? _authService;

  @override
  State<WebAuthGate> createState() => _WebAuthGateState();
}

class _WebAuthGateState extends State<WebAuthGate> {
  late final AuthService? _authService;

  @override
  void initState() {
    super.initState();
    if (widget.firebaseBootstrap.isAvailable) {
      _authService = widget._authService ?? AuthService();
    } else {
      _authService = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseBootstrap.isAvailable || _authService == null) {
      return widget.builder(context, null);
    }

    return StreamBuilder<AuthUser?>(
      stream: _authService.watchUser(),
      initialData: _authService.currentUser,
      builder: (context, snapshot) {
        debugPrint(
          '[gate] state=${snapshot.connectionState} '
          'hasData=${snapshot.hasData} '
          'uid=${snapshot.data?.uid ?? "null"} '
          'hasError=${snapshot.hasError}',
        );
        if (snapshot.hasError) {
          debugPrint('[gate] error=${snapshot.error}');
        }
        final user = snapshot.data;
        debugPrint(
          '[gate] showing AppStartupGate for uid=${user?.uid ?? "null"}',
        );
        return widget.builder(context, user);
      },
    );
  }
}
