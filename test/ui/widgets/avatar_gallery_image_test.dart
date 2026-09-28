import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/avatar_load_failure.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_rahmung_rules.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/avatar_ausschnitt_bild.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/avatar_gallery_image.dart';

/// Kleinstmoegliches gueltiges PNG (1x1 Pixel).
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aJ0AAAAASUVORK5CYII=',
);

void main() {
  late InMemoryAvatarFileStorage storage;

  Future<void> pumpImage(WidgetTester tester, String fileName) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarFileStorageProvider.overrideWithValue(storage),
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
            body: AvatarGalleryImage(
              heroId: 'demo',
              fileName: fileName,
              placeholder: const Icon(
                Icons.person,
                key: ValueKey<String>('platzhalter'),
              ),
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

  testWidgets('zeigt das Bild, sobald die Bytes vorliegen', (tester) async {
    storage.files['demo_a.png'] = _pngBytes;

    await pumpImage(tester, 'demo_a.png');

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('platzhalter')), findsNothing);
  });

  testWidgets('zeigt den Platzhalter bei fehlendem Bild', (tester) async {
    await pumpImage(tester, 'fehlt.png');

    expect(find.byKey(const ValueKey<String>('platzhalter')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('zeigt den Platzhalter bei leerem Dateinamen', (tester) async {
    await pumpImage(tester, '');

    expect(find.byKey(const ValueKey<String>('platzhalter')), findsOneWidget);
  });

  testWidgets('zeigt einen Ladeindikator statt des Platzhalters', (
    tester,
  ) async {
    // Der Abruf wird bewusst offen gehalten, damit der Ladezustand pruefbar
    // ist — mit der In-Memory-Ablage waere er nach einem Microtask vorbei.
    final completer = Completer<Uint8List?>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarBytesProvider.overrideWith((ref, args) => completer.future),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AvatarGalleryImage(
              heroId: 'demo',
              fileName: 'demo_a.png',
              placeholder: Icon(
                Icons.person,
                key: ValueKey<String>('platzhalter'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('platzhalter')), findsNothing);

    completer.complete(_pngBytes);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('nennt bei einem Fehlschlag den Grund im Tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarBytesProvider.overrideWith(
            (ref, args) async => throw const AvatarLoadException(
              AvatarLoadFailure.nichtAngemeldet,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AvatarGalleryImage(
              heroId: 'demo',
              fileName: 'demo_a.png',
              placeholder: Icon(
                Icons.person,
                key: ValueKey<String>('platzhalter'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('Nicht angemeldet'));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('platzhalter')), findsOneWidget);
  });

  testWidgets('nennt die technischen Details im Tooltip', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarBytesProvider.overrideWith(
            (ref, args) async => throw const AvatarLoadException(
              AvatarLoadFailure.unbekannt,
              details: 'ClientException: XMLHttpRequest error',
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AvatarGalleryImage(heroId: 'demo', fileName: 'demo_a.png'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('ClientException'));
  });

  test('Sammelfall und Fallback sind unterscheidbar formuliert', () {
    // Waeren beide Texte gleich, koennte der Tooltip nicht sagen, ob eine
    // AvatarLoadException vorlag oder ein voellig unerwarteter Fehler.
    const sammelfall = AvatarLoadException(AvatarLoadFailure.unbekannt);
    expect(sammelfall.meldung, isNot('Unerwarteter Fehler.'));
  });

  testWidgets('reicht die Bytes unveraendert an Image.memory', (tester) async {
    storage.files['demo_a.png'] = _pngBytes;

    await pumpImage(tester, 'demo_a.png');

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as MemoryImage;
    expect(
      provider.bytes,
      same(storage.files['demo_a.png']),
      reason: 'eine Kopie wuerde den ImageCache bei jedem Rebuild verfehlen',
    );
  });

  group('mit Rahmung', () {
    const befund = AvatarGesichtsbefund(
      bildBreite: 400,
      bildHoehe: 600,
      gesicht: AvatarGesichtsrahmen(
        links: 0.4,
        oben: 0.2,
        breite: 0.2,
        hoehe: 0.15,
      ),
      konfidenz: 0.9,
    );

    Future<void> pumpGerahmt(
      WidgetTester tester, {
      required Future<AvatarGesichtsbefund?> Function() befundLaden,
    }) async {
      storage.files['demo_a.png'] = _pngBytes;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            avatarBytesProvider.overrideWith(
              (ref, args) async => storage.files[args.fileName],
            ),
            avatarGesichtProvider.overrideWith((ref, args) => befundLaden()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AvatarGalleryImage(
                  heroId: 'demo',
                  fileName: 'demo_a.png',
                  width: 100,
                  height: 100,
                  rahmung: AvatarRahmung.portraet,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('verschiebt das ganze Bild so, dass der Ausschnitt die '
        'Flaeche fuellt', (tester) async {
      await pumpGerahmt(tester, befundLaden: () async => befund);
      await tester.pumpAndSettle();

      final erwartet = berechneAvatarAusschnitt(
        bildBreite: 400,
        bildHoehe: 600,
        seitenverhaeltnis: 1,
        rahmung: AvatarRahmung.portraet,
        gesicht: befund.gesicht,
      );
      final bild = tester.getRect(find.byType(Image));
      final flaeche = tester.getRect(find.byType(AvatarAusschnittBild));
      expect(flaeche.size, const Size(100, 100));
      expect(bild.width, closeTo(100 / erwartet.breite, 1e-6));
      expect(bild.height, closeTo(100 / erwartet.hoehe, 1e-6));
      expect(
        flaeche.left - bild.left,
        closeTo(erwartet.links * bild.width, 1e-6),
      );
      expect(
        flaeche.top - bild.top,
        closeTo(erwartet.oben * bild.height, 1e-6),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as MemoryImage).bytes,
        same(storage.files['demo_a.png']),
      );
    });

    testWidgets('wartet mit der Anzeige auf den Befund', (tester) async {
      final befundCompleter = Completer<AvatarGesichtsbefund?>();
      addTearDown(() {
        if (!befundCompleter.isCompleted) befundCompleter.complete(null);
      });
      await pumpGerahmt(tester, befundLaden: () => befundCompleter.future);
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      befundCompleter.complete(befund);
      await tester.pumpAndSettle();

      expect(find.byType(AvatarAusschnittBild), findsOneWidget);
    });

    testWidgets('ohne Befund zeigt sie den Rueckfall-Ausschnitt', (
      tester,
    ) async {
      await pumpGerahmt(tester, befundLaden: () async => null);
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, kAvatarRueckfallAusrichtung);
    });
  });
}
