import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/modifikatoren_dialog.dart';

void main() {
  testWidgets('Wert ohne Beschreibung blockiert das Speichern sichtbar', (
    tester,
  ) async {
    List<HeroTalentModifier>? ergebnis;
    var geschlossen = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              ergebnis = await showModifikatorenDialog(
                context: context,
                bezeichnung: 'MU',
                schluesselPrefix: 'test',
                modifikatoren: const <HeroTalentModifier>[],
              );
              geschlossen = true;
            },
            child: const Text('öffnen'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('test-modifiers-add')));
    await tester.pumpAndSettle();
    final wertFeld = tester.widget<TextField>(
      find.byKey(const ValueKey('test-modifier-value-0')),
    );
    expect(
      wertFeld.keyboardType,
      const TextInputType.numberWithOptions(signed: true),
    );
    await tester.enterText(
      find.byKey(const ValueKey('test-modifier-value-0')),
      '-2',
    );
    await tester.tap(find.byKey(const ValueKey('test-modifiers-save')));
    await tester.pumpAndSettle();

    // Der Wert verschwindet nicht still: Dialog bleibt offen, Feld markiert.
    expect(geschlossen, isFalse);
    expect(find.text('Beschreibung fehlt'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('test-modifier-description-0')),
      'Fluch',
    );
    await tester.pumpAndSettle();
    expect(find.text('Beschreibung fehlt'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('test-modifiers-save')));
    await tester.pumpAndSettle();

    expect(geschlossen, isTrue);
    expect(ergebnis, hasLength(1));
    expect(ergebnis!.single.modifier, -2);
    expect(ergebnis!.single.description, 'Fluch');
  });

  testWidgets('leere neue Zeilen fallen beim Speichern weg', (tester) async {
    List<HeroTalentModifier>? ergebnis;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              ergebnis = await showModifikatorenDialog(
                context: context,
                bezeichnung: 'LeP',
                schluesselPrefix: 'test',
                modifikatoren: const <HeroTalentModifier>[],
              );
            },
            child: const Text('öffnen'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('test-modifiers-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('test-modifiers-save')));
    await tester.pumpAndSettle();

    expect(ergebnis, isEmpty);
  });
}
