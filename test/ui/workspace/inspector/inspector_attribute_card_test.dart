import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_attribute_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders label and value', (tester) async {
    await tester.pumpWidget(
      _wrap(InspectorAttributeCard(label: 'KL', value: 12, onTap: () {})),
    );

    expect(find.text('KL'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('tap fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        InspectorAttributeCard(label: 'KL', value: 12, onTap: () => taps++),
      ),
    );

    await tester.tap(find.byType(InspectorAttributeCard));
    expect(taps, 1);
  });

  testWidgets('scales down inside compact inspector constraints', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Center(
          child: SizedBox(
            width: 34,
            height: 36,
            child: InspectorAttributeCard(label: 'KL', value: 12, onTap: () {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
