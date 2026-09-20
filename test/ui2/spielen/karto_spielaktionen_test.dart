import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';

void main() {
  Future<TestBestand> zeige(
    WidgetTester tester, {
    double breite = 1440,
    HeroSheet? held,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bestand = TestBestand();
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(heroes: [held ?? testHero()]),
        ),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(selectedHeroSelectionActionsProvider)
        .selectHero(held?.id ?? 'rondra');
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
    return bestand;
  }

  Future<void> modus(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip(name).first);
    await tester.pumpAndSettle();
  }

  testWidgets('„Probe suchen“ ruft genau einmal den offenen Helden auf', (
    tester,
  ) async {
    final bestand = await zeige(tester);
    await tester.tap(find.byKey(const ValueKey('karto-spiel-probe')));
    await tester.pumpAndSettle();
    expect(bestand.aufrufe, ['probeSuchen:rondra']);
  });

  testWidgets('„Rast“ ruft die vorhandene Rastbedienung auf', (tester) async {
    final bestand = await zeige(tester);
    await tester.tap(find.byKey(const ValueKey('karto-spiel-rast')));
    await tester.pumpAndSettle();
    expect(bestand.aufrufe, ['rast:rondra']);
  });

  testWidgets('Strg+K öffnet dieselbe Suche im Spielen-Bereich', (
    tester,
  ) async {
    final bestand = await zeige(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(bestand.aufrufe, ['probeSuchen:rondra']);
  });

  testWidgets('Strg+K greift außerhalb des Spielen-Bereichs nicht', (
    tester,
  ) async {
    final bestand = await zeige(tester);
    await modus(tester, 'Held verwalten');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(bestand.aufrufe, isEmpty);
  });

  testWidgets('Kürzel verschwindet mit dem Workspace', (tester) async {
    final bestand = await zeige(tester);
    await tester.tap(find.byTooltip('Heldenauswahl'));
    await tester.pumpAndSettle();
    expect(find.byType(KartoSpielansicht), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(bestand.aufrufe, isEmpty);
  });

  testWidgets('Kampf und Zustand stehen in der Seitenspalte', (tester) async {
    await zeige(tester);
    expect(find.text('Kampfproben rondra'), findsOneWidget);
    expect(find.text('Zustand rondra'), findsOneWidget);
    expect(find.text('Eigenschaftsproben rondra'), findsOneWidget);
  });

  testWidgets('schmales Fenster behält die Reihenfolge ohne zweite Spalte', (
    tester,
  ) async {
    await zeige(tester, breite: 390);
    final ressourcen = tester.getTopLeft(find.text('Ressourcen')).dy;
    final aktionen = tester.getTopLeft(find.text('Schnellaktionen')).dy;
    final eigenschaften = tester.getTopLeft(find.text('Eigenschaften')).dy;
    final kampf = tester.getTopLeft(find.text('Kampf')).dy;
    final zustand = tester.getTopLeft(find.text('Zustand')).dy;
    final protokoll = tester.getTopLeft(find.text('Würfelprotokoll')).dy;
    expect(ressourcen, lessThan(aktionen));
    expect(aktionen, lessThan(eigenschaften));
    expect(eigenschaften, lessThan(kampf));
    expect(kampf, lessThan(zustand));
    // Das Protokoll schliesst die Spalte ab; die Spezifikation nennt es
    // ausdruecklich als letzten Abschnitt der schmalen Reihenfolge.
    expect(zustand, lessThan(protokoll));
    expect(tester.takeException(), isNull);
  });
}
