import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'karto_acceptance_support.dart';
import 'karto_test_support.dart';

void main() {
  testWidgets('Tastaturfokus, Suchkürzel und Escape erhalten den Workspace', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = AcceptanceRepository(heroes: [testHero()]);
    await pumpAcceptanceWorkspace(
      tester,
      repository: repository,
      selectedHeroId: 'rondra',
    );
    expect(
      tester.getSemantics(find.byTooltip('Heldenauswahl')).tooltip,
      contains('Heldenauswahl'),
    );
    for (final label in ['Spielen', 'Held verwalten', 'Entwicklung planen']) {
      expect(find.byTooltip(label), findsOneWidget);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(FocusManager.instance.primaryFocus!.context, isNotNull);
    final firstFocus = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(same(firstFocus)));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(repository.stateWrites, isEmpty);

    await selectAcceptanceMode(tester, 'Held verwalten');
    await pressAcceptanceAction(tester, 'Bearbeiten');
    final nameField = find.byKey(const ValueKey('overview-field-name'));
    await tester.enterText(nameField, 'Eingabe bleibt erhalten');
    await selectAcceptanceMode(tester, 'Spielen');
    expect(find.textContaining('Ungespeicherte Änderungen'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Eingabe bleibt erhalten'), findsOneWidget);
    expect(find.textContaining('Ungespeicherte Änderungen'), findsNothing);
    expect(repository.heroWrites, isEmpty);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Ressourcenblatt ist per Zurück schließbar ohne Schreibzugriff', (
    tester,
  ) async {
    final repository = AcceptanceRepository(heroes: [testHero()]);
    await pumpAcceptanceWorkspace(
      tester,
      repository: repository,
      selectedHeroId: 'rondra',
      size: const Size(390, 844),
    );
    await tester.tap(find.byTooltip('Lebenspunkte ändern'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('karto-ressource-schliessen')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('karto-ressource-schliessen')),
      findsNothing,
    );
    expect(repository.stateWrites, isEmpty);
    expect(repository.heroWrites, isEmpty);
  });
}
