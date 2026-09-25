import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import 'karto_test_support.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required TestBestand bestand,
    FakeRepository? repository,
    AuthService? authService,
    AuthUser? user,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 950);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(
            repository ?? FakeRepository.empty(),
          ),
          authServiceProvider.overrideWithValue(authService),
          authUserProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          home: KartoShell(bestand: bestand),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('leere Heldenwahl ohne Konto bietet Anmelden und Registrieren', (
    tester,
  ) async {
    final bestand = TestBestand();
    await pumpShell(tester, bestand: bestand, authService: _FakeAuthService());

    expect(
      find.byKey(const ValueKey('karto-heldenwahl-konto')),
      findsOneWidget,
    );
    expect(find.text('Noch keine Helden vorhanden.'), findsOneWidget);
    expect(find.text('Helden verwalten'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-sign-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-register')));
    await tester.pumpAndSettle();

    expect(bestand.aufrufe, ['anmelden', 'registrieren']);
  });

  testWidgets('ohne Firebase keine Konto-Karte', (tester) async {
    await pumpShell(tester, bestand: TestBestand());
    expect(find.byKey(const ValueKey('karto-heldenwahl-konto')), findsNothing);
  });

  testWidgets('angemeldet keine Konto-Karte', (tester) async {
    await pumpShell(
      tester,
      bestand: TestBestand(),
      authService: _FakeAuthService(),
      user: const AuthUser(uid: 'u1', email: 'a@b.de'),
    );
    expect(find.byKey(const ValueKey('karto-heldenwahl-konto')), findsNothing);
  });
}

class _FakeAuthService implements AuthService {
  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async => AuthUser(uid: email, email: email);

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthUser(uid: email, email: email);

  @override
  Stream<AuthUser?> watchUser() => const Stream<AuthUser?>.empty();
}
