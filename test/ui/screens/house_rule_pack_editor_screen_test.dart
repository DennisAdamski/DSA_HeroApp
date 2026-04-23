import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/house_rule_pack_editor_screen.dart';

void main() {
  testWidgets('json tab syncs changes back into the structured form', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HouseRulePackEditorScreen(
            initialManifestJson: <String, dynamic>{
              'id': 'initial_pack',
              'title': 'Initial Pack',
              'description': 'Initial description',
              'patches': <Map<String, dynamic>>[],
            },
            screenTitle: 'Hausregelpaket bearbeiten',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('house-rule-pack-json')),
      '''
{
  "id": "json_pack",
  "title": "JSON Paket",
  "description": "Aus dem JSON-Tab",
  "patches": []
}
''',
    );

    await tester.tap(find.text('Strukturiert'));
    await tester.pumpAndSettle();

    final idField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('house-rule-pack-id')),
    );
    final titleField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('house-rule-pack-title')),
    );

    expect(idField.controller!.text, 'json_pack');
    expect(titleField.controller!.text, 'JSON Paket');
  });
}
