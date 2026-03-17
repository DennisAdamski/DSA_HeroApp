import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/widgets/edit_aware_table_cell.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Table(
          children: [
            TableRow(children: [child]),
          ],
        ),
      ),
    );
  }

  group('EditAwareTableCell', () {
    testWidgets('View-Modus rendert Plain Text ohne TextField',
        (tester) async {
      await tester.pumpWidget(
        wrap(const EditAwareTableCell(value: '14', isEditing: false)),
      );

      expect(find.text('14'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Edit-Modus rendert TextField mit Border', (tester) async {
      final controller = TextEditingController(text: '14');
      await tester.pumpWidget(
        wrap(
          EditAwareTableCell(
            value: '14',
            isEditing: true,
            controller: controller,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.border, isA<OutlineInputBorder>());

      controller.dispose();
    });

    testWidgets('Error-Modus zeigt roten Border', (tester) async {
      final controller = TextEditingController(text: '99');
      await tester.pumpWidget(
        wrap(
          EditAwareTableCell(
            value: '99',
            isEditing: true,
            isError: true,
            controller: controller,
            onChanged: (_) {},
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      final enabledBorder = textField.decoration?.enabledBorder;
      expect(enabledBorder, isA<OutlineInputBorder>());
      // Error-Border nutzt theme.colorScheme.error
      final outlineBorder = enabledBorder! as OutlineInputBorder;
      expect(outlineBorder.borderSide.color, isNot(Colors.transparent));

      controller.dispose();
    });

    testWidgets('Suffix-Icon wird im Edit-Modus angezeigt', (tester) async {
      final controller = TextEditingController(text: '10');
      await tester.pumpWidget(
        wrap(
          EditAwareTableCell(
            value: '10',
            isEditing: true,
            controller: controller,
            suffixIcon: const Icon(Icons.trending_up),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.trending_up), findsOneWidget);

      controller.dispose();
    });

    testWidgets('View-Modus zeigt kein Suffix-Icon', (tester) async {
      await tester.pumpWidget(
        wrap(
          const EditAwareTableCell(
            value: '10',
            isEditing: false,
            suffixIcon: Icon(Icons.trending_up),
          ),
        ),
      );

      expect(find.byIcon(Icons.trending_up), findsNothing);
    });
  });
}
