import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/widgets/erwerb_dialog.dart';

void main() {
  testWidgets('vorbelegte AP-Kosten werden übernommen und bestätigt', (
    tester,
  ) async {
    ErwerbErgebnis? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showErwerbDialog(
                    context: context,
                    bezeichnung: 'Wachsamkeit',
                    kostenHinweis: '400 AP',
                    vorgeschlageneApKosten: 400,
                    verfuegbareAp: 999,
                  );
                },
                child: const Text('Öffnen'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    expect(find.text('Katalog: 400 AP'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'AP-Kosten'), findsOneWidget);

    await tester.tap(find.text('Erwerben'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.apKosten, 400);
  });

  testWidgets('Epos-Aufschlag wird auf eingegebene Kosten angewendet', (
    tester,
  ) async {
    ErwerbErgebnis? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showErwerbDialog(
                    context: context,
                    bezeichnung: 'Kraftlinienmagie',
                    vorgeschlageneApKosten: 100,
                    verfuegbareAp: 999,
                    episch: true,
                  );
                },
                child: const Text('Öffnen'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Epos-Aufschlag (+25 %): +25 AP'), findsOneWidget);

    await tester.tap(find.text('Erwerben'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.apKosten, 125);
  });

  testWidgets('nicht genug AP verhindert Bestätigung', (tester) async {
    ErwerbErgebnis? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showErwerbDialog(
                    context: context,
                    bezeichnung: 'Wachsamkeit',
                    vorgeschlageneApKosten: 400,
                    verfuegbareAp: 100,
                  );
                },
                child: const Text('Öffnen'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    expect(find.text('Nicht genug AP für diesen Erwerb.'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Erwerben'),
    );
    expect(button.onPressed, isNull);
    expect(result, isNull);
  });
}
