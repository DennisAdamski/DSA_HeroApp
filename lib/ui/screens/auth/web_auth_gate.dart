import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/sign_in_screen.dart';

/// Erzwingt im Web-Build einen Login, bevor der eigentliche App-Inhalt
/// angezeigt wird. Auf Desktop/Mobile reicht dieser Gate den Inhalt direkt
/// durch und uebergibt einen `null`-AuthUser, sodass der Heldenspeicher wie
/// bisher rein lokal arbeitet.
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
    if (kIsWeb && widget.firebaseBootstrap.isAvailable) {
      _authService = widget._authService ?? AuthService();
    } else {
      _authService = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Desktop/Mobile: Login optional, App startet wie bisher rein lokal.
      return widget.builder(context, null);
    }
    if (!widget.firebaseBootstrap.isAvailable || _authService == null) {
      return _FirebaseUnavailableScreen(
        message:
            widget.firebaseBootstrap.userMessage ??
            'Login ist derzeit nicht verfuegbar.',
      );
    }

    return StreamBuilder<AuthUser?>(
      stream: _authService.watchUser(),
      initialData: _authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return SignInScreen(authService: _authService);
        }
        return widget.builder(context, user);
      },
    );
  }
}

class _FirebaseUnavailableScreen extends StatelessWidget {
  const _FirebaseUnavailableScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Cloud-Anbindung nicht verfuegbar',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
