import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';

void main() {
  test('roundtrip stores optional header focus values', () {
    const entry = AvatarGalleryEntry(
      id: 'bild-1',
      fileName: 'bild.png',
      quelle: 'upload',
      headerFocusX: 0.2,
      headerFocusY: 0.8,
      headerZoom: 1.75,
    );

    final restored = AvatarGalleryEntry.fromJson(entry.toJson());

    expect(restored.headerFocusX, 0.2);
    expect(restored.headerFocusY, 0.8);
    expect(restored.headerZoom, 1.75);
  });

  test('fromJson clamps header focus values into normalized range', () {
    final restored = AvatarGalleryEntry.fromJson(const {
      'id': 'bild-1',
      'fileName': 'bild.png',
      'headerFocusX': -3,
      'headerFocusY': 9,
      'headerZoom': 42,
    });

    expect(restored.headerFocusX, 0);
    expect(restored.headerFocusY, 1);
    expect(restored.headerZoom, 8);
  });

  test('fromJson clamps header zoom below 1 to 1', () {
    final restored = AvatarGalleryEntry.fromJson(const {
      'id': 'bild-1',
      'fileName': 'bild.png',
      'headerZoom': 0.25,
    });

    expect(restored.headerZoom, 1);
  });

  test('fromJson tolerates missing headerZoom (legacy data)', () {
    final restored = AvatarGalleryEntry.fromJson(const {
      'id': 'bild-1',
      'fileName': 'bild.png',
    });

    expect(restored.headerZoom, isNull);
  });

  group('Gesichtsbefund', () {
    test('ein Bestandseintrag serialisiert unveraendert', () {
      // Jede zusaetzliche Taste aenderte `heroContentHash` aller
      // Bestandshelden und loeste beim Konto-Sync Konflikte aus.
      const bestand = <String, dynamic>{
        'id': 'bild-1',
        'fileName': 'demo_bild-1.png',
        'quelle': 'ki',
        'stilId': 'aquarell',
        'erstelltAm': '2026-01-01T00:00:00.000Z',
        'promptAuszug': 'Elfe',
        'headerFocusX': 0.4,
        'headerFocusY': 0.3,
      };

      expect(AvatarGalleryEntry.fromJson(bestand).toJson(), bestand);
      expect(
        const AvatarGalleryEntry(id: 'a', fileName: 'a.png').toJson(),
        isNot(contains('gesicht')),
      );
    });

    test('Befund und Version ueberstehen die Serialisierung', () {
      const befund = AvatarGesichtsbefund(
        bildBreite: 1024,
        bildHoehe: 1536,
        gesicht: AvatarGesichtsrahmen(
          links: 0.35,
          oben: 0.18,
          breite: 0.3,
          hoehe: 0.2,
        ),
        konfidenz: 0.93,
      );
      const entry = AvatarGalleryEntry(
        id: 'a',
        fileName: 'a.png',
        gesichtsbefund: befund,
        gesichtsbefundVersion: 1,
      );

      final restored = AvatarGalleryEntry.fromJson(entry.toJson());

      expect(restored.gesichtsbefund, befund);
      expect(restored.gesichtsbefundVersion, 1);
    });

    test('auch ein Bild ohne Gesicht behaelt seine Groesse', () {
      const entry = AvatarGalleryEntry(
        id: 'a',
        fileName: 'a.png',
        gesichtsbefund: AvatarGesichtsbefund(bildBreite: 800, bildHoehe: 600),
        gesichtsbefundVersion: 1,
      );

      final restored = AvatarGalleryEntry.fromJson(entry.toJson());

      expect(restored.gesichtsbefund!.gesicht, isNull);
      expect(restored.gesichtsbefund!.bildBreite, 800);
    });

    test('kaputte Werte ergeben keinen Befund', () {
      for (final roh in <Object?>[
        'kaputt',
        const {'v': 1},
        const {'v': 1, 'w': 0, 'h': 10},
      ]) {
        final restored = AvatarGalleryEntry.fromJson({
          'id': 'a',
          'fileName': 'a.png',
          'gesicht': roh,
        });
        expect(restored.gesichtsbefund, isNull, reason: '$roh');
        expect(restored.gesichtsbefundVersion, isNull, reason: '$roh');
      }
    });
  });
}
