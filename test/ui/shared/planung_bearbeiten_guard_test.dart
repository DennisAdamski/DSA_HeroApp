import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/planung_bearbeiten_guard.dart';

import '../../ui2/shell/karto_test_support.dart';

void main() {
  late ProviderContainer container;
  late int bearbeitungen;

  Future<void> zeige(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    bearbeitungen = 0;
    container
        .read(advancementSessionProvider('rondra').notifier)
        .start(hero: testHero(), catalog: testCatalog);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  if (await bestaetigeBearbeitungBeiPlanung(
                    context: context,
                    heroId: 'rondra',
                  )) {
                    bearbeitungen++;
                  }
                },
                child: const Text('Bearbeiten'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Doppelklick führt nach Bestätigung nur eine Bearbeitung aus', (
    tester,
  ) async {
    await zeige(tester);
    final button = tester.widget<TextButton>(find.byType(TextButton));
    // Zwei gleichzeitig ausgelöste Einstiege teilen nicht die Bearbeitung.
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Geplante Entwicklung verwerfen?'), findsOneWidget);
    expect(bearbeitungen, 0);
    await tester.tap(find.text('Planung verwerfen und bearbeiten'));
    await tester.pumpAndSettle();
    expect(bearbeitungen, 1);
    expect(container.read(advancementSessionProvider('rondra')), isNull);
  });

  testWidgets(
    'System-Zurück erhält die Sitzung und erlaubt eine neue Rückfrage',
    (tester) async {
      await zeige(tester);
      final session = container.read(advancementSessionProvider('rondra'));
      await tester.tap(find.text('Bearbeiten'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(bearbeitungen, 0);
      expect(
        container.read(advancementSessionProvider('rondra')),
        same(session),
      );
      await tester.tap(find.text('Bearbeiten'));
      await tester.pumpAndSettle();
      expect(find.text('Planung verwerfen und bearbeiten'), findsOneWidget);
    },
  );

  testWidgets('Bestätigung verwirft keine inzwischen neu gestartete Sitzung', (
    tester,
  ) async {
    await zeige(tester);
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    final controller = container.read(
      advancementSessionProvider('rondra').notifier,
    );
    controller.discard();
    controller.start(hero: testHero(), catalog: testCatalog);
    final neu = container.read(advancementSessionProvider('rondra'));
    await tester.tap(find.text('Planung verwerfen und bearbeiten'));
    await tester.pumpAndSettle();
    expect(bearbeitungen, 0);
    expect(container.read(advancementSessionProvider('rondra')), same(neu));
  });
}
