import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_shell.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/sign_in_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    required FakeRepository repository,
    AuthService? authService,
    AuthUser? user,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repository),
          dunkelModusProvider.overrideWith((ref) => false),
          authServiceProvider.overrideWithValue(authService),
          authUserProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: const DsaAppShell(home: HeroesHomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('leeres Archiv ohne Konto zeigt die Konto-Karte', (tester) async {
    await pumpHome(
      tester,
      repository: FakeRepository.empty(),
      authService: _FakeAuthService(),
    );

    expect(find.byKey(const ValueKey('home-account-prompt')), findsOneWidget);
    expect(find.text('Dein Heldenarchiv ist noch leer'), findsOneWidget);
    expect(find.text('Ersten Helden anlegen'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-register')));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Stattdessen anmelden'), findsOneWidget);
  });

  testWidgets('Anmelden öffnet den Login-Modus', (tester) async {
    await pumpHome(
      tester,
      repository: FakeRepository.empty(),
      authService: _FakeAuthService(),
    );

    await tester.tap(find.byKey(const ValueKey('home-sign-in')));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Neues Konto anlegen'), findsOneWidget);
  });

  testWidgets('ohne Firebase gibt es keine Konto-Karte', (tester) async {
    await pumpHome(tester, repository: FakeRepository.empty());

    expect(find.byKey(const ValueKey('home-account-prompt')), findsNothing);
    expect(find.text('Dein Heldenarchiv ist noch leer'), findsOneWidget);
  });

  testWidgets('angemeldet gibt es keine Konto-Karte', (tester) async {
    await pumpHome(
      tester,
      repository: FakeRepository.empty(),
      authService: _FakeAuthService(),
      user: const AuthUser(uid: 'u1', email: 'a@b.de'),
    );

    expect(find.byKey(const ValueKey('home-account-prompt')), findsNothing);
  });

  testWidgets('mit Helden gibt es keine Konto-Karte', (tester) async {
    await pumpHome(
      tester,
      repository: FakeRepository(
        heroes: [
          HeroSheet(
            id: 'h1',
            name: 'Alrik',
            level: 1,
            attributes: const Attributes(
              mu: 12,
              kl: 12,
              inn: 12,
              ch: 12,
              ff: 12,
              ge: 12,
              ko: 12,
              kk: 12,
            ),
          ),
        ],
      ),
      authService: _FakeAuthService(),
    );

    expect(find.byKey(const ValueKey('home-account-prompt')), findsNothing);
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
