import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_page_scaffold.dart';

void main() {
  for (final decorated in [true, false]) {
    testWidgets('ExpansionTile ink remains visible with decoration=$decorated', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) => Theme(
              data: Theme.of(context).copyWith(
                extensions: [
                  CodexTheme.of(context).copyWith(showDecoration: decorated),
                ],
              ),
              child: const Scaffold(
                body: CodexPageScaffold(
                  child: Column(
                    children: [
                      ExpansionTile(
                        tilePadding: EdgeInsets.symmetric(horizontal: 4),
                        title: Text('Abschnitt'),
                        children: [Text('Inhalt')],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Abschnitt'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Inhalt').hitTestable(), findsOneWidget);
    });
  }
}
