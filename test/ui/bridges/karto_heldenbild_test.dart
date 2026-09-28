import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_rahmung_rules.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/avatar_ausschnitt_bild.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/avatar_gallery_image.dart';

/// Kleinstmoegliches gueltiges PNG (1x1 Pixel).
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aJ0AAAAASUVORK5CYII=',
);

void main() {
  testWidgets('die Heldenmarke rahmt das Bild am erkannten Gesicht', (
    tester,
  ) async {
    const befund = AvatarGesichtsbefund(
      bildBreite: 1024,
      bildHoehe: 1536,
      gesicht: AvatarGesichtsrahmen(
        links: 0.35,
        oben: 0.15,
        breite: 0.3,
        hoehe: 0.18,
      ),
      konfidenz: 0.93,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarBytesProvider.overrideWith((ref, args) async => _pngBytes),
          avatarGesichtProvider.overrideWith((ref, args) async => befund),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: const KartoBestandsAdapterImpl().heldenbild(
                heroId: 'rondra',
                dateiname: 'rondra_a1.png',
                groesse: 88,
                ersatz: const Text('R'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bild = tester.widget<AvatarGalleryImage>(
      find.byType(AvatarGalleryImage),
    );
    expect(bild.rahmung, AvatarRahmung.portraet);
    final ausschnitt = tester.widget<AvatarAusschnittBild>(
      find.byType(AvatarAusschnittBild),
    );
    expect(ausschnitt.befund, befund);
    expect(
      tester.getSize(find.byType(AvatarAusschnittBild)),
      const Size(88, 88),
    );
  });
}
