import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

void main() {
  test('group actions fail with a clear message when Firebase is unavailable', () async {
    const message =
        'Gruppen-Sync ist derzeit nicht verfügbar. Bitte Firebase zuerst konfigurieren.';
    final container = ProviderContainer(
      overrides: [
        firebaseBootstrapProvider.overrideWithValue(
          const FirebaseBootstrapResult.unavailable(userMessage: message),
        ),
      ],
    );
    addTearDown(container.dispose);

    final actions = container.read(heroActionsProvider);

    await expectLater(
      actions.erstelleGruppe(heroId: 'hero', gruppenName: 'Testgruppe'),
      throwsA(
        predicate<Object>((error) {
          return error is StateError && error.message == message;
        }),
      ),
    );
  });
}
