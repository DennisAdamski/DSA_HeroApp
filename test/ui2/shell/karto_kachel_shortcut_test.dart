import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_verwaltungs_ziel.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielraster_ordnung.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../../test_support/fake_repository.dart';
import 'karto_test_support.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, TestBestand bestand) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(heroes: [testHero()]),
        ),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(selectedHeroSelectionActionsProvider)
        .selectHero('rondra');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          home: KartoShell(bestand: bestand),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder oeffnen(String kachel) =>
      find.byKey(ValueKey<String>('karto-kachel-$kachel-oeffnen'));

  test('jede Kachel mit Seite im Bestand nennt ihren Abschnitt', () {
    expect(
      KartoSpielkachelArt.dabei.verwaltungsAbschnitt,
      KartoVerwaltungsAbschnitt.inventar,
    );
    expect(
      KartoSpielkachelArt.kampf.verwaltungsAbschnitt,
      KartoVerwaltungsAbschnitt.kampf,
    );
    expect(
      KartoSpielkachelArt.abenteuer.verwaltungsAbschnitt,
      KartoVerwaltungsAbschnitt.notizen,
    );
    // Rein spielseitige Kacheln haben keine Seite und damit keinen Knopf.
    for (final art in [
      KartoSpielkachelArt.marker,
      KartoSpielkachelArt.standort,
      KartoSpielkachelArt.wildnis,
      KartoSpielkachelArt.protokoll,
    ]) {
      expect(art.verwaltungsAbschnitt, isNull, reason: art.name);
    }
  });

  testWidgets('Dabei springt ins Inventar der Verwaltung', (tester) async {
    await pumpShell(tester, TestBestand());
    expect(find.text('Verwaltungsinhalt'), findsNothing);

    await tester.ensureVisible(oeffnen('dabei'));
    await tester.tap(oeffnen('dabei'));
    await tester.pumpAndSettle();

    expect(find.text('Verwaltungsinhalt'), findsOneWidget);
    expect(find.text('Abschnitt inventar'), findsOneWidget);
  });

  testWidgets('der Knopf nennt die Zielseite im Tooltip', (tester) async {
    await pumpShell(tester, TestBestand());
    expect(find.byTooltip('Inventar in der Verwaltung öffnen'), findsOneWidget);
  });

  testWidgets('Kacheln ohne Seite im Bestand tragen keinen Knopf', (
    tester,
  ) async {
    await pumpShell(tester, TestBestand());
    expect(oeffnen('marker'), findsNothing);
    expect(oeffnen('protokoll'), findsNothing);
  });

  testWidgets('abgelehnte Editorprüfung hält die Spielansicht', (tester) async {
    final bestand = TestBestand();
    await pumpShell(tester, bestand);
    // Erst nach einem Besuch hat die Verwaltung einen Guard registriert.
    await tester.tap(find.byTooltip('Held verwalten').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Spielen').first);
    await tester.pumpAndSettle();
    bestand.pruefung = () async => false;

    await tester.ensureVisible(oeffnen('dabei'));
    await tester.tap(oeffnen('dabei'));
    await tester.pumpAndSettle();

    expect(find.text('Abschnitt inventar'), findsNothing);
    expect(find.text('Am Spieltisch'), findsOneWidget);
  });

  testWidgets('zweiter Besuch wechselt ebenfalls auf den Abschnitt', (
    tester,
  ) async {
    await pumpShell(tester, TestBestand());
    await tester.tap(find.byTooltip('Held verwalten').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Spielen').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(oeffnen('kampf'));
    await tester.tap(oeffnen('kampf'));
    await tester.pumpAndSettle();

    expect(find.text('Abschnitt kampf'), findsOneWidget);
  });
}
