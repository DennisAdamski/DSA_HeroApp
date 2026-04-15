import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_hero_header.dart';

void main() {
  HeroSheet buildHero({HeroAppearance appearance = const HeroAppearance()}) {
    return HeroSheet(
      id: 'demo',
      name: 'Gerajin Sirella von Tuzak',
      level: 7,
      attributes: const Attributes(
        mu: 13,
        kl: 12,
        inn: 16,
        ch: 16,
        ff: 10,
        ge: 14,
        ko: 12,
        kk: 12,
      ),
      background: const HeroBackground(
        rasse: 'Mensch',
        kultur: 'Mittelreich',
        profession: 'Hexe',
      ),
      apTotal: 2573,
      apSpent: 2571,
      apAvailable: 2,
      appearance: appearance,
    );
  }

  Future<void> pumpWorkspace(
    WidgetTester tester, {
    required Size size,
    HeroSheet? hero,
    List overrides = const [],
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeRepository(
      heroes: [hero ?? buildHero()],
      states: const <String, HeroState>{
        'demo': HeroState(
          currentLep: 27,
          currentAsp: 30,
          currentKap: 0,
          currentAu: 30,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          debugModusProvider.overrideWith((ref) => false),
          ...overrides,
        ],
        child: const MaterialApp(home: HeroWorkspaceScreen(heroId: 'demo')),
      ),
    );
    await tester.pump();
    if (settle) {
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'tablet and desktop layouts use one compact combined workspace header',
    (tester) async {
      final widths = <double>[744, 1024, 1366];

      for (final width in widths) {
        await pumpWorkspace(tester, size: Size(width, 1024));
        final header = find.byKey(
          const ValueKey<String>('workspace-hero-header'),
        );

        expect(header, findsOneWidget);
        expect(
          find.byKey(
            const ValueKey<String>('workspace-core-attributes-header'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('workspace-header-stat-rail')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: header,
            matching: find.text('Gerajin Sirella von Tuzak'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: header,
            matching: find.text('Hexe | Mittelreich | Mensch'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.textContaining('Stufe')),
          findsWidgets,
        );
        expect(
          find.descendant(of: header, matching: find.textContaining('AP frei')),
          findsWidgets,
        );

        final headerSize = tester.getSize(header);
        // Bei schmalem Tablet-Hochformat kann die Stat-Rail in zwei Zeilen
        // umbrechen, was den Header auf ca. 200 px anwachsen lässt.
        expect(headerSize.height, lessThan(220));
      }
    },
  );

  testWidgets(
    'workspace header falls back to initials when no primary image exists',
    (tester) async {
      await pumpWorkspace(tester, size: const Size(1024, 1024));

      expect(
        find.byKey(
          const ValueKey<String>('workspace-header-portrait-initials'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('workspace-header-portrait-image')),
        findsNothing,
      );
    },
  );

  testWidgets('workspace header shows the primary image when one is available', (
    tester,
  ) async {
    final imageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aJ0AAAAASUVORK5CYII=',
    );
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1024, 1024);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hero = buildHero(
      appearance: const HeroAppearance(
        primaerbildId: 'bild-1',
        avatarGallery: [
          AvatarGalleryEntry(
            id: 'bild-1',
            fileName: 'demo_bild-1.png',
            headerFocusX: 0.3,
            headerFocusY: 0.4,
          ),
        ],
      ),
    );
    final repo = FakeRepository(
      heroes: [hero],
      states: const <String, HeroState>{
        'demo': HeroState(
          currentLep: 27,
          currentAsp: 30,
          currentKap: 0,
          currentAu: 30,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          debugModusProvider.overrideWith((ref) => false),
          primaerbildBytesProvider.overrideWith(
            (ref, heroId) async => imageBytes,
          ),
          activeAvatarBytesProvider.overrideWith(
            (ref, heroId) async => imageBytes,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WorkspaceHeroHeader(
              heroId: 'demo',
              hero: hero,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey<String>('workspace-header-portrait-image')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-header-portrait-initials')),
      findsNothing,
    );
  });
}
