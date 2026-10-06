import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_editor.dart';

// Bei verknüpften Einträgen legt der Kampf-Slot fest, ob sie ausgerüstet
// sind; der Abgleich überschrieb den Schalter bisher still beim Speichern.

Future<void> _zeige(WidgetTester tester, HeroInventoryEntry eintrag) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InventoryItemEditor(
          entry: eintrag,
          showAppBar: false,
          onSaved: (_) async {},
          onCancelled: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SwitchListTile _schalter(WidgetTester tester) => tester.widget<SwitchListTile>(
  find.widgetWithText(SwitchListTile, 'Ausgerüstet'),
);

void main() {
  testWidgets('verknüpft: Schalter gesperrt mit Hinweis', (tester) async {
    await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Kettenhemd',
        itemType: InventoryItemType.ausruestung,
        source: InventoryItemSource.ruestung,
        sourceRef: 'a:Kettenhemd',
        istAusgeruestet: true,
      ),
    );

    expect(_schalter(tester).onChanged, isNull);
    expect(find.text('Wird im Kampf-Tab festgelegt.'), findsOneWidget);
  });

  testWidgets('manuell: Schalter bedienbar', (tester) async {
    await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Amulett',
        itemType: InventoryItemType.ausruestung,
      ),
    );

    expect(_schalter(tester).onChanged, isNotNull);
  });
}
