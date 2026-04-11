import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_gruppe_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  testWidgets('empty group view disables cloud actions when Firebase is unavailable', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        HeroSheet(
          id: 'hero',
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
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          firebaseBootstrapProvider.overrideWithValue(
            const FirebaseBootstrapResult.unavailable(
              userMessage:
                  'Gruppen-Sync ist auf diesem Gerät deaktiviert.',
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroGruppeTab(
              heroId: 'hero',
              onDirtyChanged: _noopBool,
              onEditingChanged: _noopBool,
              onRegisterDiscard: _noopDiscard,
              onRegisterEditActions: _noopEditActions,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Gruppen-Sync ist auf diesem Gerät deaktiviert.'),
      findsOneWidget,
    );

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Gruppe erstellen'),
    );
    final joinButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Gruppe beitreten'),
    );

    expect(createButton.onPressed, isNull);
    expect(joinButton.onPressed, isNull);
  });
}

void _noopBool(bool value) {}

void _noopDiscard(WorkspaceAsyncAction action) {}

void _noopEditActions(WorkspaceTabEditActions actions) {}
