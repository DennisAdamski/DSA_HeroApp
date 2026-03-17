import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/widgets/edit_aware_field.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('EditAwareField', () {
    testWidgets('View-Modus rendert Plain Text ohne TextField', (tester) async {
      await tester.pumpWidget(
        wrap(
          const EditAwareField(
            label: 'Name',
            value: 'Alrik',
            isEditing: false,
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Alrik'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('View-Modus zeigt Platzhalter bei leerem Wert',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const EditAwareField(
            label: 'Titel',
            value: '',
            isEditing: false,
          ),
        ),
      );

      expect(find.text('Titel'), findsOneWidget);
      expect(find.text('–'), findsOneWidget);
    });

    testWidgets('Edit-Modus rendert TextFormField mit Border',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          EditAwareField(
            label: 'Name',
            value: 'Alrik',
            isEditing: true,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      // Pruefe, dass das zugrunde liegende TextField die erwartete Decoration hat.
      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration!;
      expect(decoration.labelText, 'Name');
      expect(decoration.border, isA<OutlineInputBorder>());
    });

    testWidgets('Controller-Variante nutzt Controller-Text im View-Modus',
        (tester) async {
      final controller = TextEditingController(text: 'Controllerwert');

      await tester.pumpWidget(
        wrap(
          EditAwareField(
            label: 'Feld',
            isEditing: false,
            controller: controller,
          ),
        ),
      );

      expect(find.text('Controllerwert'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      controller.dispose();
    });

    testWidgets('Controller-Variante nutzt Controller im Edit-Modus',
        (tester) async {
      final controller = TextEditingController(text: '42');

      await tester.pumpWidget(
        wrap(
          EditAwareField(
            label: 'Wert',
            isEditing: true,
            controller: controller,
          ),
        ),
      );

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller, same(controller));

      controller.dispose();
    });
  });

  group('EditAwareIntField', () {
    testWidgets('View-Modus rendert Plain Text ohne TextField',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const EditAwareIntField(
            label: 'MU',
            value: 13,
            isEditing: false,
          ),
        ),
      );

      expect(find.text('MU'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('View-Modus zeigt Platzhalter bei null', (tester) async {
      await tester.pumpWidget(
        wrap(
          const EditAwareIntField(
            label: 'AsP',
            value: null,
            isEditing: false,
          ),
        ),
      );

      expect(find.text('–'), findsOneWidget);
    });

    testWidgets('Edit-Modus rendert TextFormField mit Zahlentastatur',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          EditAwareIntField(
            label: 'KL',
            value: 12,
            isEditing: true,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, TextInputType.number);
    });

    testWidgets('Suffix-Icon wird im Edit-Modus angezeigt', (tester) async {
      await tester.pumpWidget(
        wrap(
          EditAwareIntField(
            label: 'GE',
            value: 11,
            isEditing: true,
            onChanged: (_) {},
            suffixIcon: const Icon(Icons.trending_up),
          ),
        ),
      );

      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });
  });
}
