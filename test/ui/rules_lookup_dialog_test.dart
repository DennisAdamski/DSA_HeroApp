import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/rules_lookup_dialog.dart';

void main() {
  testWidgets(
    'zeigt zunaechst einen Ladeindikator und wechselt danach in einen '
    'Endzustand (Suche, Desktop- oder Web-Leerzustand)',
    (tester) async {
      // ProviderScope ist seit dem Server-Sync-Feature Pflicht: der Dialog
      // ist ein ConsumerStatefulWidget geworden (Zugriff auf Settings-
      // Provider beim Sync-Button-Tap), auch wenn dieser Test den Button
      // nicht betätigt und daher keine Provider-Overrides benötigt.
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: RulesLookupDialog())),
        ),
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
