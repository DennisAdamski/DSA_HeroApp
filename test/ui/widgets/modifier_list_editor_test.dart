import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/modifier_list_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ModifierListController> pumpEditor(
    WidgetTester tester,
    List<HeroTalentModifier> initial,
  ) async {
    final controller = ModifierListController(initial);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModifierListEditor(
            controller: controller,
            keyPrefix: 'test-modifier',
            addButtonKey: const ValueKey<String>('test-modifiers-add'),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('zeigt Platzhalter bei leerer Liste', (tester) async {
    await pumpEditor(tester, const <HeroTalentModifier>[]);
    expect(find.text('Keine Modifikatoren vorhanden.'), findsOneWidget);
  });

  testWidgets('rendert vorhandene Eintraege mit stabilen Keys', (tester) async {
    await pumpEditor(tester, <HeroTalentModifier>[
      HeroTalentModifier(modifier: 2, description: 'Werkzeug'),
    ]);
    expect(
      find.byKey(const ValueKey<String>('test-modifier-value-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('test-modifier-description-0')),
      findsOneWidget,
    );
  });

  testWidgets('Add-Button fuegt eine neue Zeile hinzu', (tester) async {
    final controller = await pumpEditor(tester, const <HeroTalentModifier>[]);
    await tester.tap(find.byKey(const ValueKey<String>('test-modifiers-add')));
    await tester.pump();
    expect(controller.length, 1);
    expect(
      find.byKey(const ValueKey<String>('test-modifier-value-0')),
      findsOneWidget,
    );
  });

  testWidgets('Loeschen entfernt die Zeile', (tester) async {
    final controller = await pumpEditor(tester, <HeroTalentModifier>[
      HeroTalentModifier(modifier: 1, description: 'A'),
    ]);
    await tester.tap(find.byTooltip('Modifikator entfernen'));
    await tester.pump();
    expect(controller.length, 0);
    expect(find.text('Keine Modifikatoren vorhanden.'), findsOneWidget);
  });

  testWidgets('buildModifiers verwirft Zeilen ohne Beschreibung', (
    tester,
  ) async {
    final controller = await pumpEditor(tester, <HeroTalentModifier>[
      HeroTalentModifier(modifier: 3, description: 'Bleibt'),
    ]);
    await tester.tap(find.byKey(const ValueKey<String>('test-modifiers-add')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('test-modifier-value-1')),
      '5',
    );

    final result = controller.buildModifiers();
    expect(result, hasLength(1));
    expect(result.single.modifier, 3);
    expect(result.single.description, 'Bleibt');
  });
}
