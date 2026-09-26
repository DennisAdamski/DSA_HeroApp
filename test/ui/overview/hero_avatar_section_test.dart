import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_avatar_gesichtserkennung.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_rahmung_rules.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/avatar_ausschnitt_bild.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/avatar_gallery_image.dart';

/// Kleinstmoegliches gueltiges PNG (1x1 Pixel).
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aJ0AAAAASUVORK5CYII=',
);

void main() {
  late InMemoryAvatarFileStorage storage;

  HeroSheet buildHero({HeroAppearance appearance = const HeroAppearance()}) {
    return HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 1,
      attributes: const Attributes(
        mu: 14,
        kl: 12,
        inn: 13,
        ch: 11,
        ff: 10,
        ge: 12,
        ko: 14,
        kk: 13,
      ),
      appearance: appearance,
    );
  }

  Future<void> pumpTab(
    WidgetTester tester,
    HeroSheet hero, {
    AvatarGesichtsbefund befund = const AvatarGesichtsbefund(
      bildBreite: 1,
      bildHoehe: 1,
    ),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(
            FakeRepository(
              heroes: <HeroSheet>[hero],
              states: <String, HeroState>{
                'demo': const HeroState(
                  currentLep: 10,
                  currentAsp: 0,
                  currentKap: 0,
                  currentAu: 10,
                ),
              },
            ),
          ),
          avatarFileStorageProvider.overrideWithValue(storage),
          avatarGesichtServiceProvider.overrideWithValue(
            festerAvatarGesichtService(befund: befund),
          ),
          heroStorageLocationProvider.overrideWith(
            (ref) async => const HeroStorageLocation(
              defaultPath: '/helden',
              effectivePath: '/helden',
              customPathSupported: false,
              usesCustomPath: false,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroOverviewTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    storage = InMemoryAvatarFileStorage();
  });

  testWidgets('zeigt das aktive Galeriebild in der Uebersicht', (tester) async {
    storage.files['demo_a.png'] = _pngBytes;

    await pumpTab(
      tester,
      buildHero(
        appearance: const HeroAppearance(
          aktivesBildId: 'a',
          avatarGallery: [AvatarGalleryEntry(id: 'a', fileName: 'demo_a.png')],
        ),
      ),
    );

    expect(find.byType(AvatarGalleryImage), findsWidgets);
    expect(find.text('Avatar Album (1)'), findsOneWidget);
  });

  testWidgets('zeigt ohne Galerie keine Avatar-Darstellung', (tester) async {
    await pumpTab(tester, buildHero());

    expect(find.byType(AvatarGalleryImage), findsNothing);
  });

  testWidgets('erkennt Bestandshelden ohne Galerie-Eintrag', (tester) async {
    storage.files['demo.png'] = _pngBytes;

    // `HeroAppearance.fromJson` synthetisiert fuer solche Helden den Eintrag
    // `demo_legacy`; der Dateiname bleibt dabei `demo.png`.
    final hero = HeroSheet.fromJson({
      ...buildHero().toJson(),
      'avatarFileName': 'demo.png',
    });

    await pumpTab(tester, hero);

    expect(hero.appearance.aktivesBild!.fileName, 'demo.png');
    expect(find.byType(AvatarGalleryImage), findsWidgets);
  });

  testWidgets('Header-Ausschnitt oeffnet sich ueber das Album', (tester) async {
    storage.files['demo_a.png'] = _pngBytes;

    await pumpTab(
      tester,
      buildHero(
        appearance: const HeroAppearance(
          aktivesBildId: 'a',
          avatarGallery: [AvatarGalleryEntry(id: 'a', fileName: 'demo_a.png')],
        ),
      ),
    );

    await tester.tap(find.text('Avatar Album (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Header-Ausschnitt'));
    await tester.pumpAndSettle();

    expect(find.text('Header-Ausschnitt'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Albumkacheln richten sich am Gesicht aus, die Uebersicht '
      'zeigt das ganze Bild', (tester) async {
    storage.files['demo_a.png'] = _pngBytes;

    await pumpTab(
      tester,
      buildHero(
        appearance: const HeroAppearance(
          aktivesBildId: 'a',
          avatarGallery: [AvatarGalleryEntry(id: 'a', fileName: 'demo_a.png')],
        ),
      ),
    );

    final uebersicht = tester.widget<AvatarGalleryImage>(
      find.byType(AvatarGalleryImage),
    );
    expect(uebersicht.rahmung, isNull);
    expect(uebersicht.fit, BoxFit.contain);

    await tester.tap(find.text('Avatar Album (1)'));
    await tester.pumpAndSettle();

    final kachel = tester.widget<AvatarGalleryImage>(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(AvatarGalleryImage),
      ),
    );
    expect(kachel.rahmung, AvatarRahmung.portraet);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(AvatarAusschnittBild),
      ),
      findsOneWidget,
    );
  });

  Future<Alignment> vorschauAusrichtung(
    WidgetTester tester,
    AvatarGalleryEntry entry,
  ) async {
    storage.files['demo_a.png'] = _pngBytes;
    await pumpTab(
      tester,
      buildHero(
        appearance: HeroAppearance(aktivesBildId: 'a', avatarGallery: [entry]),
      ),
      befund: const AvatarGesichtsbefund(
        bildBreite: 400,
        bildHoehe: 600,
        gesicht: AvatarGesichtsrahmen(
          links: 0.4,
          oben: 0.2,
          breite: 0.2,
          hoehe: 0.1,
        ),
        konfidenz: 0.9,
      ),
    );
    await tester.tap(find.text('Avatar Album (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Header-Ausschnitt'));
    await tester.pumpAndSettle();

    final vorschau = tester.widget<Image>(
      find.byWidgetPredicate((w) => w is Image && w.fit == BoxFit.cover),
    );
    return vorschau.alignment as Alignment;
  }

  testWidgets('Header-Ausschnitt startet ohne eigenen Fokus auf dem Gesicht', (
    tester,
  ) async {
    final ausrichtung = await vorschauAusrichtung(
      tester,
      const AvatarGalleryEntry(id: 'a', fileName: 'demo_a.png'),
    );

    // Gesichtsmitte (0,5 | 0,25) als Ausrichtung (0 | -0,5).
    expect(ausrichtung.x, closeTo(0, 1e-9));
    expect(ausrichtung.y, closeTo(-0.5, 1e-9));
  });

  testWidgets('Header-Ausschnitt behaelt einen gespeicherten Fokus', (
    tester,
  ) async {
    final ausrichtung = await vorschauAusrichtung(
      tester,
      const AvatarGalleryEntry(
        id: 'a',
        fileName: 'demo_a.png',
        headerFocusX: 0.8,
        headerFocusY: 0.9,
      ),
    );

    expect(ausrichtung.x, closeTo(0.6, 1e-9));
    expect(ausrichtung.y, closeTo(0.8, 1e-9));
  });
}
