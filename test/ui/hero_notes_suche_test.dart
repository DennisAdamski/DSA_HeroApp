import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import '../test_support/fake_repository.dart';

// Filtersuche über die allgemeinen Chroniken im klassischen Notizen-Tab: Sie
// filtert nur die Leseansicht, schreibt nie und lässt beim Bearbeiten alle
// Chroniken stehen.

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

const _held = HeroSheet(
  id: 'demo',
  name: 'Hexe',
  level: 1,
  apTotal: 1000,
  apSpent: 500,
  apAvailable: 500,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
  notes: <HeroNoteEntry>[
    HeroNoteEntry(
      title: 'Das Rätsel der Höhle',
      description: 'Ein Zwerg nannte den Pfad nach Angbar.',
    ),
    HeroNoteEntry(
      title: 'Schulden',
      description: 'Zwei Dukaten an die Wirtin.',
    ),
  ],
);

void main() {
  final suche = find.byKey(const ValueKey<String>('notes-note-search'));

  Future<WorkspaceTabEditActions?> zeige(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(
      heroes: const [_held],
      states: const {
        'demo': HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    WorkspaceTabEditActions? aktionen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _katalog),
          appSettingsProvider.overrideWith(
            (ref) => Stream<AppSettings>.value(const AppSettings()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroNotesTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (registriert) => aktionen = registriert,
            ),
          ),
        ),
      ),
    );
    await _pumpOhneUeberlauf(tester);
    return aktionen;
  }

  testWidgets('filtert die Chroniken nach Titel und Text, ohne Umlaute', (
    tester,
  ) async {
    await zeige(tester);
    expect(find.text('Das Rätsel der Höhle'), findsOneWidget);
    expect(find.text('Schulden'), findsOneWidget);

    await tester.enterText(suche, 'raetsel');
    await tester.pumpAndSettle();
    expect(find.text('Das Rätsel der Höhle'), findsOneWidget);
    expect(find.text('Schulden'), findsNothing);

    await tester.enterText(suche, 'dukaten');
    await tester.pumpAndSettle();
    expect(find.text('Das Rätsel der Höhle'), findsNothing);
    expect(find.text('Schulden'), findsOneWidget);
  });

  testWidgets('ohne Treffer erscheint ein Hinweis, Leeren zeigt alles', (
    tester,
  ) async {
    await zeige(tester);
    await tester.enterText(suche, 'drache');
    await tester.pumpAndSettle();
    expect(find.text('Keine Chronik passt zu „drache“.'), findsOneWidget);
    expect(find.text('Schulden'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('notes-note-search-clear')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Das Rätsel der Höhle'), findsOneWidget);
    expect(find.text('Schulden'), findsOneWidget);
  });

  testWidgets('beim Bearbeiten stehen alle Chroniken da und die Suche fehlt', (
    tester,
  ) async {
    final aktionen = await zeige(tester);
    await tester.enterText(suche, 'dukaten');
    await tester.pumpAndSettle();
    expect(find.text('Das Rätsel der Höhle'), findsNothing);

    await aktionen!.startEdit();
    await _pumpOhneUeberlauf(tester);
    expect(suche, findsNothing);
    expect(
      find.byKey(const ValueKey<String>('notes-note-title-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('notes-note-title-1')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpOhneUeberlauf(WidgetTester tester) async {
  await tester.pumpAndSettle();
  Object? fehler;
  do {
    fehler = tester.takeException();
    if (fehler != null && !'$fehler'.contains('A RenderFlex overflowed')) {
      throw fehler;
    }
  } while (fehler != null);
}
