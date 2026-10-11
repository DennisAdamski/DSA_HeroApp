import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/ui_shared/magic_setup_dialog.dart';

void main() {
  const hero = HeroSheet(
    id: 'h',
    name: 'Held',
    level: 1,
    attributes: Attributes.zero(),
    apSpent: 42,
    vorteileText: 'Vollzauberer',
  );
  const catalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: [],
    weapons: [],
    spells: [],
  );
  for (final width in [390.0, 1440.0]) {
    testWidgets('Einrichtung bei $width bestätigt atomar ohne AP', (
      tester,
    ) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      HeroSheet? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showMagicSetupDialog(
                    context: context,
                    hero: hero,
                    catalog: catalog,
                  );
                },
                child: const Text('Einrichten'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Einrichten'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.byKey(const ValueKey('magic-setup-confirm')));
      await tester.pumpAndSettle();
      expect(result!.representationen, ['Mag']);
      expect(result!.ritualKnowledge['gildenmagier']!.value, 3);
      expect(result!.apSpent, 42);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Abbruch liefert keine Teiländerung', (tester) async {
    HeroSheet? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showMagicSetupDialog(
                  context: context,
                  hero: hero,
                  catalog: catalog,
                );
              },
              child: const Text('Einrichten'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Einrichten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
