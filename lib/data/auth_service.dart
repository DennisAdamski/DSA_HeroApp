// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:dsa_heldenverwaltung/data/registration_invite_client.dart';

/// Vereinfachte Sicht auf den eingeloggten Benutzer fuer die UI-Schicht.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.emailVerified = false,
  });

  final String uid;
  final String? email;

  /// Gibt an, ob Firebase die E-Mail-Adresse bestätigt hat.
  final bool emailVerified;
}

/// Wrapper um [FirebaseAuth] mit den fuer die App benoetigten Operationen.
///
/// Liefert einen [Stream] des aktuell eingeloggten Benutzers und Methoden
/// fuer Email/Password-Login, Registrierung sowie Logout. Die API ist bewusst
/// schmal gehalten und kann fuer Tests durch eine Fake-Implementierung ersetzt
/// werden.
class AuthService {
  // Der öffentliche Parametername bleibt für die Verdrahtung lesbar, während
  // die austauschbare Infrastruktur nicht Teil der Service-Oberfläche wird.
  AuthService({
    FirebaseAuth? firebaseAuth,
    RegistrationInviteGateway? registrationInviteGateway,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _registrationInviteGateway = registrationInviteGateway;

  final FirebaseAuth _auth;
  final RegistrationInviteGateway? _registrationInviteGateway;

  /// Liefert den aktuell eingeloggten Benutzer oder `null`.
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  /// Reaktiver Stream des eingeloggten Benutzers (Login/Logout/Refresh).
  Stream<AuthUser?> watchUser() {
    return _auth.userChanges().map(_mapUser);
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
    required String registrationKeyword,
  }) async {
    final gateway = _registrationInviteGateway;
    if (gateway == null) {
      throw const RegistrationInviteException('REGISTRATION_UNAVAILABLE');
    }
    await gateway.issueTicket(email: email, keyword: registrationKeyword);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = _mapUser(credential.user);
    if (user == null) {
      throw StateError('Registrierung lieferte keinen Benutzer.');
    }
    await credential.user?.sendEmailVerification();
    return user;
  }

  /// Sendet eine E-Mail zum Zurücksetzen des Passworts.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sendet dem aktuellen, noch nicht verifizierten Konto eine Bestätigung.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Kein Konto angemeldet.');
    }
    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Lädt den aktuellen Kontostand neu und gibt ihn für die UI zurück.
  Future<AuthUser?> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
    return _mapUser(_auth.currentUser);
  }

  /// Bestätigt sensible Kontoaktionen erneut mit dem Kontopasswort.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError(
        'Für dieses Konto ist keine E-Mail-Anmeldung verfügbar.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Loggt den aktuellen Benutzer aus.
  Future<void> signOut() => _auth.signOut();

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AuthUser(
      uid: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
    );
  }
}
