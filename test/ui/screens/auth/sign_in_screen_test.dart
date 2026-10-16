import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/sign_in_screen.dart';

void main() {
  testWidgets('marks email and password fields for browser autofill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SignInScreen(authService: _FakeAuthService())),
    );

    expect(find.byType(AutofillGroup), findsOneWidget);

    final loginFields = _textFields(tester);
    expect(loginFields, hasLength(2));
    final emailField = loginFields[0];
    final passwordField = loginFields[1];

    expect(emailField.keyboardType, TextInputType.emailAddress);
    expect(
      emailField.autofillHints,
      containsAll([AutofillHints.email, AutofillHints.username]),
    );
    expect(
      passwordField.autofillHints,
      orderedEquals([AutofillHints.password]),
    );

    await tester.tap(find.text('Neues Konto anlegen'));
    await tester.pumpAndSettle();

    final registerFields = _textFields(tester);
    expect(registerFields, hasLength(3));
    expect(
      registerFields[1].autofillHints,
      orderedEquals([AutofillHints.newPassword]),
    );
  });

  testWidgets('schließt sich als gepushte Route nach erfolgreichem Login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SignInScreen(
                  authService: _FakeAuthService(),
                  initialRegisterMode: true,
                ),
              ),
            ),
            child: const Text('öffnen'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Stattdessen anmelden'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'held@example.de');
    await tester.enterText(fields.at(1), 'geheim123456');
    await tester.enterText(fields.at(2), 'invite-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Konto anlegen'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsNothing);
    expect(find.text('öffnen'), findsOneWidget);
    // Die Freigabe wird nur für den unmittelbar folgenden Ticketaufruf genutzt.
    // Der Fake hält sie ausschließlich zur Verifikation dieses Tests fest.
    expect(_FakeAuthService.lastRegistrationKeyword, 'invite-secret');
  });

  testWidgets('Registrierung verlangt mindestens zwölf Zeichen', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(MaterialApp(home: SignInScreen(authService: auth)));

    await tester.tap(find.text('Neues Konto anlegen'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'held@example.de');
    await tester.enterText(fields.at(1), 'zu-kurz-11');
    await tester.tap(find.widgetWithText(FilledButton, 'Konto anlegen'));
    await tester.pump();

    expect(find.text('Mindestens 12 Zeichen.'), findsOneWidget);
    expect(auth.registerCalls, 0);
  });

  testWidgets('Passwort-Reset nutzt die eingegebene E-Mail neutral', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(MaterialApp(home: SignInScreen(authService: auth)));

    await tester.enterText(
      find.byType(TextFormField).first,
      ' held@example.de ',
    );
    await tester.tap(find.text('Passwort vergessen?'));
    await tester.pumpAndSettle();

    expect(auth.resetEmails, ['held@example.de']);
    expect(find.textContaining('Falls ein Konto existiert'), findsOneWidget);
  });
}

List<TextField> _textFields(WidgetTester tester) {
  return tester.widgetList<TextField>(find.byType(TextField)).toList();
}

class _FakeAuthService implements AuthService {
  static String? lastRegistrationKeyword;
  int registerCalls = 0;
  final List<String> resetEmails = [];

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String registrationKeyword,
  }) async {
    registerCalls++;
    lastRegistrationKeyword = registrationKeyword;
    return AuthUser(uid: email, email: email);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmails.add(email);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<AuthUser?> reloadCurrentUser() async => currentUser;

  @override
  Future<void> reauthenticateWithPassword(String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return AuthUser(uid: email, email: email);
  }

  @override
  Stream<AuthUser?> watchUser() {
    return const Stream<AuthUser?>.empty();
  }
}
