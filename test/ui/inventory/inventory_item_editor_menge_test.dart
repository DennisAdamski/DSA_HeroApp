import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_editor.dart';

// Menge im Inventareditor (ARCH-03): eine reine Zahl wird zur Menge, eine
// Abweichung durch eine ältere Version ist sichtbar und wird beim Speichern
// mit der Anzahl übernommen.

Future<List<HeroInventoryEntry>> _zeige(
  WidgetTester tester,
  HeroInventoryEntry eintrag,
) async {
  final gespeichert = <HeroInventoryEntry>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InventoryItemEditor(
          entry: eintrag,
          showAppBar: false,
          onSaved: (neu) async => gespeichert.add(neu),
          onCancelled: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return gespeichert;
}

Future<void> _speichere(WidgetTester tester) async {
  final knopf = find.widgetWithText(FilledButton, 'Speichern');
  await tester.ensureVisible(knopf);
  await tester.tap(knopf);
  await tester.pumpAndSettle();
}

final Finder _anzahl = find.byKey(
  const ValueKey<String>('inventory-editor-quantity'),
);
final Finder _hinweis = find.byKey(
  const ValueKey<String>('inventory-editor-quantity-hint'),
);

void main() {
  testWidgets('eine eingegebene Zahl wird zur Menge', (tester) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(gegenstand: 'Fackel', anzahl: 'ein paar'),
    );
    expect(_hinweis, findsNothing);

    await tester.enterText(_anzahl, ' 4 ');
    await _speichere(tester);

    expect(gespeichert.single.menge, 4);
    expect(gespeichert.single.anzahl, '4');
  });

  testWidgets('Freitext bleibt offen', (tester) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(gegenstand: 'Nüsse', anzahl: '3', menge: 3),
    );

    await tester.enterText(_anzahl, 'ein paar');
    await _speichere(tester);

    expect(gespeichert.single.menge, isNull);
    expect(gespeichert.single.anzahl, 'ein paar');
  });

  testWidgets('eine Abweichung wird angezeigt und mit der Anzahl gespeichert', (
    tester,
  ) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(gegenstand: 'Heiltrank', anzahl: '3', menge: 5),
    );
    expect(_hinweis, findsOneWidget);
    expect(find.textContaining('gespeicherte Menge: 5'), findsOneWidget);

    await _speichere(tester);

    expect(gespeichert.single.menge, 3);
    expect(gespeichert.single.anzahl, '3');
  });
}
