import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_papier.dart';

import 'karto_test_support.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required TestBestand bestand,
    required FakeRepository repository,
    double breite = 1024,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repository)],
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

  final alrik = testHero('alrik', 'Alrik Feuerstein').copyWith(
    apAvailable: 1375,
    background: const HeroBackground(
      rasse: 'Thorwaler',
      kultur: 'Thorwal',
      profession: 'Hetmann',
    ),
    appearance: const HeroAppearance(
      avatarGallery: <AvatarGalleryEntry>[
        AvatarGalleryEntry(id: 'b1', fileName: 'alrik_b1.png'),
      ],
      aktivesBildId: 'b1',
    ),
  );

  testWidgets('Helden stehen als Karten mit Herkunft und freien AP', (
    tester,
  ) async {
    final bestand = TestBestand();
    await pumpShell(
      tester,
      bestand: bestand,
      repository: FakeRepository(heroes: [testHero(), alrik]),
    );

    expect(find.text('Deine Helden'), findsOneWidget);
    expect(find.text('Heldenverwaltung'), findsOneWidget);
    expect(find.byType(KartoPapier), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('karto-heldenwahl-held-alrik')),
      findsOneWidget,
    );
    expect(find.text('Hetmann'), findsOneWidget);
    expect(find.text('Thorwaler · Thorwal'), findsOneWidget);
    expect(find.text('1375 AP frei'), findsOneWidget);
    // Bilder rendert nur die Bruecke, und nur fuer Helden mit Bild.
    expect(bestand.aufrufe, contains('heldenbild:alrik:alrik_b1.png'));
    expect(
      bestand.aufrufe.where((a) => a.startsWith('heldenbild:rondra')),
      isEmpty,
    );
    expect(find.text('R'), findsOneWidget);
    expect(find.byType(KartoKompassring), findsNWidgets(2));
  });

  testWidgets('eine Karte hebt sich unter dem Mauszeiger an', (tester) async {
    await pumpShell(
      tester,
      bestand: TestBestand(),
      repository: FakeRepository(heroes: [testHero()]),
    );
    final karte = find.byKey(
      const ValueKey<String>('karto-heldenwahl-held-rondra'),
    );
    List<BoxShadow> schatten() {
      final behaelter = tester.widget<AnimatedContainer>(
        find
            .ancestor(of: karte, matching: find.byType(AnimatedContainer))
            .first,
      );
      return (behaelter.decoration! as BoxDecoration).boxShadow ?? const [];
    }

    expect(schatten(), isEmpty);
    final maus = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await maus.addPointer(location: Offset.zero);
    addTearDown(maus.removePointer);
    await maus.moveTo(tester.getCenter(karte));
    await tester.pumpAndSettle();
    expect(schatten(), isNotEmpty);
  });

  testWidgets('Tippen waehlt den Helden', (tester) async {
    await pumpShell(
      tester,
      bestand: TestBestand(),
      repository: FakeRepository(heroes: [testHero(), alrik]),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('karto-heldenwahl-held-alrik')),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KartoShell)),
    );
    expect(container.read(selectedHeroIdProvider), 'alrik');
  });

  testWidgets('der leere Speicher zeigt die Kompassrose statt Leere', (
    tester,
  ) async {
    await pumpShell(
      tester,
      bestand: TestBestand(),
      repository: FakeRepository.empty(),
      breite: 390,
    );
    expect(find.text('Noch keine Helden vorhanden.'), findsOneWidget);
    // Wasserzeichen oben rechts und Bild des Leerzustands.
    expect(find.byType(KartoKompassrose), findsNWidgets(2));
    expect(find.text('Helden verwalten'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final breite in <double>[320, 390, 744, 1440]) {
    testWidgets('lange Namen laufen bei $breite dp und doppelter Schrift '
        'nicht ueber', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(breite, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heroRepositoryProvider.overrideWithValue(
              FakeRepository(
                heroes: [
                  testHero(
                    'lang',
                    'Rondra Alrike von Gareth und den Silberquellen',
                  ),
                  alrik,
                ],
              ),
            ),
          ],
          child: MaterialApp(
            theme: buildKartoTheme(
              brightness: Brightness.dark,
              centerAppBarTitle: false,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: KartoShell(bestand: TestBestand()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
