import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_shell.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

void main() {
  testWidgets('App bootstrappt bis zum leeren Helden-Startscreen ohne Fehler', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeRepository.empty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(fakeRepository),
          dunkelModusProvider.overrideWith((ref) => false),
        ],
        child: const DsaAppShell(home: HeroesHomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('DSA Helden'), findsOneWidget);
    expect(
      find.text('Dein Heldenarchiv ist noch leer'),
      findsOneWidget,
    );
    expect(find.text('Neuer Held'), findsOneWidget);
    expect(find.byTooltip('Einstellungen'), findsOneWidget);
  });
}
