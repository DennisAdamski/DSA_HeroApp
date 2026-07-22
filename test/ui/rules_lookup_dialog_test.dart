import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/rules_lookup_dialog.dart';

void main() {
  testWidgets(
    'zeigt zunaechst einen Ladeindikator und wechselt danach in einen '
    'Endzustand (Suche, Desktop- oder Web-Leerzustand)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RulesLookupDialog())),
      );

      // Vor dem ersten Frame nach initState ist openRulesIndexSearch()
      // noch nicht abgeschlossen: der asynchrone Ladezustand muss sichtbar
      // sein statt eines synchronen Sofort-Ergebnisses wie vor der
      // Web-Erweiterung.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final hasSearchField = find
          .byKey(const ValueKey('rules-lookup-search-field'))
          .evaluate()
          .isNotEmpty;
      final hasUnavailableNotice = find
          .textContaining('nicht gefunden')
          .evaluate()
          .isNotEmpty;
      final hasImportNotice = find
          .textContaining('noch nicht importiert')
          .evaluate()
          .isNotEmpty;
      expect(hasSearchField || hasUnavailableNotice || hasImportNotice, isTrue);
    },
  );
}
