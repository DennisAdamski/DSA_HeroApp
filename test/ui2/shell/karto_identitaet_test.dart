import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import 'karto_test_support.dart';

/// Prueft den Identitaetsbereich der Bereichsnavigation und seine Anbindung
/// an die Bestandsbruecke.
void main() {
  Future<TestBestand> pumpShell(
    WidgetTester tester, {
    required HeroSheet held,
    double width = 1440,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 950);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bestand = TestBestand();
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(heroes: [held]),
        ),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(selectedHeroSelectionActionsProvider)
        .selectHero(held.id);
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

  HeroSheet heldMitBild() => testHero().copyWith(
    appearance: const HeroAppearance(
      avatarGallery: <AvatarGalleryEntry>[
        AvatarGalleryEntry(id: 'a1', fileName: 'rondra_a1.png'),
      ],
      aktivesBildId: 'a1',
    ),
  );

  testWidgets('die Spalte nennt Held und Profession', (tester) async {
    await pumpShell(
      tester,
      held: testHero().copyWith(
        background: const HeroBackground(profession: 'Geweihte'),
      ),
    );
    expect(find.text('Rondra'), findsOneWidget);
    expect(find.text('Geweihte'), findsOneWidget);
  });

  testWidgets('ohne Profession springt die Kultur ein', (tester) async {
    // Die Zeile darf nicht leer bleiben, sonst verliert die Marke ihre Hoehe
    // und der Kopfbereich wirkt abgeschnitten.
    await pumpShell(
      tester,
      held: testHero().copyWith(
        background: const HeroBackground(kultur: 'Mittelreich'),
      ),
    );
    expect(find.text('Mittelreich'), findsOneWidget);
  });

  testWidgets('ein vorhandenes Bild laeuft ueber die Bestandsbruecke', (
    tester,
  ) async {
    final bestand = await pumpShell(tester, held: heldMitBild());
    // Avatare rendert ausschliesslich `AvatarGalleryImage`; UI2 baut dafuer
    // kein eigenes Bildwidget auf `avatarBytesProvider`.
    expect(bestand.aufrufe, contains('heldenbild:rondra:rondra_a1.png'));
    expect(find.text('Bild rondra_a1.png'), findsOneWidget);
  });

  testWidgets('ohne Bild fragt die Spalte die Bruecke gar nicht', (
    tester,
  ) async {
    final bestand = await pumpShell(tester, held: testHero());
    expect(bestand.aufrufe.where((a) => a.startsWith('heldenbild:')), isEmpty);
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('schmale Fenster tragen die Identitaet in der AppBar', (
    tester,
  ) async {
    // Dort gibt es keine Spalte; Marke und Fussbereich entfallen, damit die
    // untere Navigationsleiste nicht zur halben Seite waechst.
    await pumpShell(tester, held: heldMitBild(), width: 390);
    expect(find.text('Bild rondra_a1.png'), findsNothing);
    expect(find.byTooltip('Heldenauswahl'), findsOneWidget);
    expect(find.byTooltip('Workspace-Menü'), findsOneWidget);
  });

  testWidgets('breite Fenster fuehren die globalen Wege genau einmal', (
    tester,
  ) async {
    // Sie wandern aus der AppBar in den Fussbereich der Spalte. Doppelt
    // vorhanden waeren sie fuer Bedienung und Pruefungen mehrdeutig.
    await pumpShell(tester, held: testHero());
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Heldenauswahl'), findsOneWidget);
    expect(find.byTooltip('Workspace-Menü'), findsOneWidget);
  });
}
