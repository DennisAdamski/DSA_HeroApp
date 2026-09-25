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
    expect(registerFields, hasLength(2));
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
    await tester.enterText(fields.at(1), 'geheim123');
    await tester.tap(find.widgetWithText(FilledButton, 'Konto anlegen'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsNothing);
    expect(find.text('öffnen'), findsOneWidget);
  });
}

List<TextField> _textFields(WidgetTester tester) {
  return tester.widgetList<TextField>(find.byType(TextField)).toList();
}

class _FakeAuthService implements AuthService {
  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return AuthUser(uid: email, email: email);
  }

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
