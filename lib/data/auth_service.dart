import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Vereinfachte Sicht auf den eingeloggten Benutzer fuer die UI-Schicht.
class AuthUser {
  const AuthUser({required this.uid, required this.email});

  final String uid;
  final String? email;
}

/// Wrapper um [FirebaseAuth] mit den fuer die App benoetigten Operationen.
///
/// Liefert einen [Stream] des aktuell eingeloggten Benutzers und Methoden
/// fuer Email/Password-Login, Registrierung sowie Logout. Die API ist bewusst
/// schmal gehalten und kann fuer Tests durch eine Fake-Implementierung ersetzt
/// werden.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Liefert den aktuell eingeloggten Benutzer oder `null`.
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  /// Reaktiver Stream des eingeloggten Benutzers (Login/Logout/Refresh).
  Stream<AuthUser?> watchUser() {
    return _auth.authStateChanges().map(_mapUser);
  }

  /// Loggt den Benutzer per Email und Passwort ein.
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = _mapUser(credential.user);
    if (user == null) {
      throw StateError('Login lieferte keinen Benutzer.');
    }
    return user;
  }

  /// Legt einen neuen Benutzer mit Email und Passwort an.
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = _mapUser(credential.user);
    if (user == null) {
      throw StateError('Registrierung lieferte keinen Benutzer.');
    }
    return user;
  }

  /// Loggt den aktuellen Benutzer aus.
  Future<void> signOut() => _auth.signOut();

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AuthUser(uid: user.uid, email: user.email);
  }
}
