import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/held_importieren.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

const _attribute = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

HeroSheet _held({
  String id = 'alt',
  String name = 'Alrik',
  HeroAppearance appearance = const HeroAppearance(),
}) {
  return HeroSheet(
    id: id,
    name: name,
    level: 1,
    attributes: _attribute,
    appearance: appearance,
  );
}

const _zustand = HeroState(
  currentLep: 21,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 30,
);

final _uhr = DateTime.utc(2026, 10, 7, 12);

Map<String, dynamic> _galeriebild(AvatarGalleryEntry eintrag, String bytes) {
  return {...eintrag.toJson(), 'base64': base64Encode(utf8.encode(bytes))};
}

/// Bildablage wie `AvatarFileStorage` (IO): vergibt `{heroId}_{entryId}.png`
/// bzw. `{heroId}.png` und merkt sich die abgelegten Bytes.
class _Ablage {
  final Map<String, String> dateien = <String, String>{};
  final Set<String> scheitert = <String>{};
  bool leererName = false;

  Future<String> galerie({
    required String heroId,
    required String entryId,
    required List<int> bytes,
  }) async {
    if (scheitert.contains(entryId)) {
      throw Exception('Netzwerk weg');
    }
    if (leererName) {
      return '';
    }
    final name = '${heroId}_$entryId.png';
    dateien[name] = utf8.decode(bytes);
    return name;
  }

  Future<String> hauptbild({
    required String heroId,
    required List<int> bytes,
  }) async {
    if (scheitert.contains('haupt')) {
      throw Exception('Netzwerk weg');
    }
    final name = '$heroId.png';
    dateien[name] = utf8.decode(bytes);
    return name;
  }
}

class _Aufbau {
  _Aufbau({List<HeroSheet> helden = const <HeroSheet>[], this.maxHelden = 5})
    : repo = FakeRepository(heroes: List<HeroSheet>.of(helden));

  final FakeRepository repo;
  final int maxHelden;
  final _Ablage ablage = _Ablage();
  final List<String> ereignisse = <String>[];
  final List<HeroSheet> gespeichert = <HeroSheet>[];
  Object? speicherfehler;

  HeldImportieren get ablauf => HeldImportieren(
    repository: repo,
    speichere: (held) async {
      ereignisse.add('held');
      final fehler = speicherfehler;
      if (fehler != null) {
        throw fehler;
      }
      gespeichert.add(held);
      await repo.saveHero(held);
      return held;
    },
    uebernimmKatalog: (eintraege) async {
      ereignisse.add('katalog:${eintraege.length}');
    },
    speichereGaleriebild: ablage.galerie,
    speichereHauptbild: ablage.hauptbild,
    neueId: () => 'neu',
    uhr: () => _uhr,
    maxHelden: maxHelden,
  );
}

void main() {
  group('Ziel-ID und Limit', () {
    test('behält die ID und speichert Held und Zustand', () async {
      final aufbau = _Aufbau();
      final ergebnis = await aufbau.ablauf.importiere(
        HeroTransferBundle(exportedAt: _uhr, hero: _held(), state: _zustand),
        neuAnlegen: false,
      );

      expect(ergebnis.heroId, 'alt');
      expect(ergebnis.fehlendeBilder, 0);
      expect(aufbau.gespeichert, hasLength(1));
      final zustand = (await aufbau.repo.loadHeroState('alt'))!;
      expect(zustand.currentLep, 21);
      expect(zustand.lastModified, _uhr);
    });

    test('vergibt beim Neuanlegen eine neue ID', () async {
      final aufbau = _Aufbau(helden: [_held()]);
      final ergebnis = await aufbau.ablauf.importiere(
        HeroTransferBundle(exportedAt: _uhr, hero: _held(), state: _zustand),
        neuAnlegen: true,
      );

      expect(ergebnis.heroId, 'neu');
      expect((await aufbau.repo.loadHeroById('neu'))!.name, 'Alrik');
      expect(await aufbau.repo.loadHeroById('alt'), isNotNull);
      expect((await aufbau.repo.loadHeroState('neu'))!.currentLep, 21);
    });

    for (final neuAnlegen in [false, true]) {
      test('das Limit gilt für eine unbekannte ID '
          '(neuAnlegen: $neuAnlegen)', () async {
        final aufbau = _Aufbau(
          helden: [
            _held(id: 'a'),
            _held(id: 'b'),
          ],
          maxHelden: 2,
        );
        await expectLater(
          aufbau.ablauf.importiere(
            HeroTransferBundle(
              exportedAt: _uhr,
              hero: _held(id: 'fremd'),
              state: _zustand,
            ),
            neuAnlegen: neuAnlegen,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => '$e',
              'Meldung',
              contains('Maximale Anzahl von 2 Helden erreicht'),
            ),
          ),
        );
        expect(aufbau.ereignisse, isEmpty);
        expect(await aufbau.repo.loadHeroState('fremd'), isNull);
      });
    }

    test('überschreiben eines vorhandenen Helden zählt nicht gegen das '
        'Limit', () async {
      final aufbau = _Aufbau(
        helden: [
          _held(id: 'a'),
          _held(id: 'alt', name: 'Vorher'),
        ],
        maxHelden: 2,
      );
      await aufbau.ablauf.importiere(
        HeroTransferBundle(exportedAt: _uhr, hero: _held(), state: _zustand),
        neuAnlegen: false,
      );
      expect((await aufbau.repo.loadHeroById('alt'))!.name, 'Alrik');
    });
  });

  test('übernimmt den Katalog vor dem Helden', () async {
    final aufbau = _Aufbau();
    await aufbau.ablauf.importiere(
      HeroTransferBundle(
        exportedAt: _uhr,
        hero: _held(),
        state: _zustand,
        catalogEntries: const [
          HeroTransferCatalogEntry(
            section: CatalogSectionId.talents,
            id: 'tal_eigen',
            data: {'id': 'tal_eigen'},
          ),
        ],
      ),
      neuAnlegen: false,
    );
    expect(aufbau.ereignisse, ['katalog:1', 'held']);
  });

  group('Bilder', () {
    const bildA = AvatarGalleryEntry(id: 'a', fileName: 'alt_a.png');
    const bildB = AvatarGalleryEntry(id: 'b', fileName: 'alt_b.png');
    final mitGalerie = _held(
      appearance: const HeroAppearance(
        avatarGallery: [bildA, bildB],
        aktivesBildId: 'b',
        primaerbildId: 'b',
      ),
    );

    test('Galerieeinträge tragen den Namen, den die Ablage vergibt, und der '
        'Held wird einmal gespeichert', () async {
      final aufbau = _Aufbau(helden: [mitGalerie]);
      final ergebnis = await aufbau.ablauf.importiere(
        HeroTransferBundle(
          exportedAt: _uhr,
          hero: mitGalerie,
          state: _zustand,
          avatarBase64: base64Encode(utf8.encode('B')),
          galleryImages: [_galeriebild(bildA, 'A'), _galeriebild(bildB, 'B')],
        ),
        neuAnlegen: true,
      );

      expect(ergebnis.fehlendeBilder, 0);
      expect(aufbau.gespeichert, hasLength(1));
      final galerie = aufbau.gespeichert.single.appearance.avatarGallery;
      // Früher blieb `alt_a.png`: die Kopie zeigte auf das Bild des
      // Originals, und Löschen in der Kopie entfernte es dort.
      expect(galerie.map((e) => e.fileName), ['neu_a.png', 'neu_b.png']);
      expect(aufbau.ablage.dateien['neu_a.png'], 'A');
      expect(aufbau.gespeichert.single.appearance.aktivesBildId, 'b');
      expect(aufbau.gespeichert.single.appearance.primaerbildId, 'b');
      // Das doppelt mitgelieferte Hauptbild wird nicht zusätzlich abgelegt.
      expect(aufbau.ablage.dateien.containsKey('neu.png'), isFalse);
    });

    test('ein Bild, das sich nicht speichern lässt, wird gezählt; unter '
        'neuer ID fehlt es, der Held wird trotzdem importiert', () async {
      final aufbau = _Aufbau();
      aufbau.ablage.scheitert.add('b');
      final ergebnis = await aufbau.ablauf.importiere(
        HeroTransferBundle(
          exportedAt: _uhr,
          hero: mitGalerie,
          state: _zustand,
          galleryImages: [_galeriebild(bildA, 'A'), _galeriebild(bildB, 'B')],
        ),
        neuAnlegen: true,
      );

      expect(ergebnis.fehlendeBilder, 1);
      final aussehen = aufbau.gespeichert.single.appearance;
      expect(aussehen.avatarGallery.map((e) => e.fileName), ['neu_a.png']);
      expect(aussehen.aktivesBildId, 'a');
      expect(aussehen.primaerbildId, isEmpty);
      expect(await aufbau.repo.loadHeroState('neu'), isNotNull);
    });

    test('unter derselben ID bleibt der bisherige Verweis eines nicht '
        'gespeicherten Bildes stehen', () async {
      final aufbau = _Aufbau();
      aufbau.ablage.scheitert.add('b');
      final ergebnis = await aufbau.ablauf.importiere(
        HeroTransferBundle(
          exportedAt: _uhr,
          hero: mitGalerie,
          state: _zustand,
          galleryImages: [_galeriebild(bildA, 'A'), _galeriebild(bildB, 'B')],
        ),
        neuAnlegen: false,
      );

      expect(ergebnis.fehlendeBilder, 1);
      final aussehen = aufbau.gespeichert.single.appearance;
      expect(aussehen.avatarGallery.map((e) => e.fileName), [
        'alt_a.png',
        'alt_b.png',
      ]);
      expect(aussehen.aktivesBildId, 'b');
      expect(aussehen.primaerbildId, 'b');
    });

    test('ein leerer Dateiname gilt als nicht gespeichert', () async {
      final aufbau = _Aufbau();
      aufbau.ablage.leererName = true;
      final ergebnis = await aufbau.ablauf.importiere(
        HeroTransferBundle(
          exportedAt: _uhr,
          hero: mitGalerie,
          state: _zustand,
          galleryImages: [_galeriebild(bildA, 'A'), _galeriebild(bildB, 'B')],
        ),
        neuAnlegen: true,
      );

      expect(ergebnis.fehlendeBilder, 2);
      final aussehen = aufbau.gespeichert.single.appearance;
      expect(aussehen.avatarGallery, isEmpty);
      expect(aussehen.aktivesBildId, isEmpty);
    });

    test('Einträge ohne Bilddaten bleiben unter derselben ID unverändert und '
        'fallen unter neuer ID weg', () async {
      final gleich = _Aufbau();
      final unveraendert = await gleich.ablauf.importiere(
        HeroTransferBundle(exportedAt: _uhr, hero: mitGalerie, state: _zustand),
        neuAnlegen: false,
      );
      expect(unveraendert.fehlendeBilder, 0);
      expect(
        gleich.gespeichert.single.appearance.toJson(),
        mitGalerie.appearance.toJson(),
      );

      final kopie = _Aufbau();
      final neu = await kopie.ablauf.importiere(
        HeroTransferBundle(exportedAt: _uhr, hero: mitGalerie, state: _zustand),
        neuAnlegen: true,
      );
      expect(neu.fehlendeBilder, 2);
      final aussehen = kopie.gespeichert.single.appearance;
      expect(aussehen.avatarGallery, isEmpty);
      expect(aussehen.aktivesBildId, isEmpty);
      expect(aussehen.primaerbildId, isEmpty);
    });

    test('ein alter Export ohne Galeriebilder legt das Hauptbild ab und '
        'benennt den Legacy-Eintrag um', () async {
      final altExport = HeroSheet.fromJson({
        ..._held().toJson(),
        'avatarFileName': 'alt.png',
        'avatarGallery': <Object>[],
        'aktivesBildId': '',
      });
      expect(altExport.appearance.avatarGallery.single.id, 'alt_legacy');

      final aufbau = _Aufbau();
      final ergebnis = await aufbau.ablauf.importiere(
        HeroTransferBundle(
          exportedAt: _uhr,
          hero: altExport,
          state: _zustand,
          avatarBase64: base64Encode(utf8.encode('H')),
        ),
        neuAnlegen: true,
      );

      expect(ergebnis.fehlendeBilder, 0);
      final aussehen = aufbau.gespeichert.single.appearance;
      expect(aussehen.avatarFileName, 'neu.png');
      expect(aussehen.avatarGallery.single.fileName, 'neu.png');
      expect(aussehen.aktivesBild?.fileName, 'neu.png');
      expect(aufbau.ablage.dateien['neu.png'], 'H');
    });
  });

  test('ein Speicherfehler erreicht den Aufrufer, der Zustand bleibt '
      'ungeschrieben', () async {
    final aufbau = _Aufbau()..speicherfehler = StateError('Speicher voll');
    await expectLater(
      aufbau.ablauf.importiere(
        HeroTransferBundle(exportedAt: _uhr, hero: _held(), state: _zustand),
        neuAnlegen: false,
      ),
      throwsA(isA<StateError>()),
    );
    expect(await aufbau.repo.loadHeroState('alt'), isNull);
  });
}
