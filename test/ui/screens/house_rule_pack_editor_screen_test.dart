import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/house_rule_pack_editor_screen.dart';

void main() {
  testWidgets('new pack drafts open even with empty id and title', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HouseRulePackEditorScreen(
            initialManifestJson: <String, dynamic>{
              'id': '',
              'title': '',
              'description': '',
              'patches': <Map<String, dynamic>>[],
            },
            screenTitle: 'Hausregelpaket anlegen',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final idField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('house-rule-pack-id')),
    );
    final titleField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('house-rule-pack-title')),
    );

    expect(idField.controller!.text, isEmpty);
    expect(titleField.controller!.text, isEmpty);

    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();

    final jsonField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('house-rule-pack-json')),
    );
    expect(jsonField.controller!.text, contains('"id": ""'));
    expect(jsonField.controller!.text, contains('"patches": []'));
  });

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

  testWidgets('incomplete patches can switch between structured and json', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HouseRulePackEditorScreen(
            initialManifestJson: <String, dynamic>{
              'id': 'draft_pack',
              'title': 'Draft Pack',
              'description': '',
              'patches': <Map<String, dynamic>>[],
            },
            screenTitle: 'Hausregelpaket bearbeiten',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Patch'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();

    final jsonField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('house-rule-pack-json')),
    );
    expect(jsonField.controller!.text, contains('"section": "talents"'));

    await tester.tap(find.text('Strukturiert'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('house-rule-pack-id')),
      findsOneWidget,
    );
  });
}
