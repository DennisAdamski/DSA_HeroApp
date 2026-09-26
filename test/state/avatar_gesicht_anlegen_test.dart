import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht/avatar_gesichtserkennung.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht_cache.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht_service.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';

/// Der Gesichtsbefund entsteht beim Anlegen und reist am Galerieeintrag mit.
class _ZaehlendesRepository extends FakeRepository {
  _ZaehlendesRepository({super.heroes});

  int speicherungen = 0;

  @override
  Future<void> saveHero(HeroSheet hero) {
    speicherungen++;
    return super.saveHero(hero);
  }
}

class _Erkennung implements AvatarGesichtserkennung {
  _Erkennung(this.antwort);

  final Future<AvatarGesichtsbefund> Function() antwort;
  int aufrufe = 0;

  @override
  Future<AvatarGesichtsbefund> erkenne(Uint8List bildBytes) {
    aufrufe++;
    return antwort();
  }
}

const _befund = AvatarGesichtsbefund(
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

void main() {
  final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));

  HeroSheet held({List<AvatarGalleryEntry> galerie = const []}) {
    return HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 1,
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
      appearance: HeroAppearance(avatarGallery: galerie),
    );
  }

  late _ZaehlendesRepository repo;
  late InMemoryAvatarFileStorage ablage;

  ProviderContainer container(
    _Erkennung erkennung, {
    HeroSheet? hero,
    List overrides = const [],
  }) {
    repo = _ZaehlendesRepository(heroes: [hero ?? held()]);
    ablage = InMemoryAvatarFileStorage();
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        avatarFileStorageProvider.overrideWithValue(ablage),
        avatarGesichtServiceProvider.overrideWithValue(
          AvatarGesichtService(
            erkennung: erkennung,
            cacheFuer: (_) => InMemoryAvatarGesichtCache(),
          ),
        ),
        heroStorageLocationProvider.overrideWith(
          (ref) async => const HeroStorageLocation(
            defaultPath: '/helden',
            effectivePath: '/helden',
            customPathSupported: false,
            usesCustomPath: false,
          ),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Wartet, bis `heroByIdProvider` den Helden aufloesen kann (Muster aus
  /// `avatar_bytes_provider_test.dart`; ein `read(...future)` ohne Listener
  /// wuerde nie fertig).
  Future<void> warteAufHeldenindex(ProviderContainer c) async {
    final sub = c.listen<AsyncValue<List<HeroSheet>>>(
      heroListProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    for (var versuch = 0; versuch < 20 && !sub.read().hasValue; versuch++) {
      await c.pump();
    }
    expect(sub.read().hasValue, isTrue);
  }

  group('beim Anlegen', () {
    test(
      'Hochladen legt den Eintrag mit Befund an, in einem Speichern',
      () async {
        final erkennung = _Erkennung(() async => _befund);
        final c = container(erkennung);

        await c
            .read(heroActionsProvider)
            .uploadHeroImage(heroId: 'demo', imageBytes: bytes);

        final eintrag = (await repo.loadHeroById('demo'))!
            .appearance
            .avatarGallery
            .single;
        expect(eintrag.gesichtsbefund, _befund);
        expect(eintrag.gesichtsbefundVersion, kAvatarGesichtDetektorVersion);
        expect(eintrag.toJson(), contains('gesicht'));
        expect(repo.speicherungen, 1);
        expect(erkennung.aufrufe, 1);
      },
    );

    test('Generieren legt den Eintrag mit Befund an', () async {
      final c = container(_Erkennung(() async => _befund));

      await c
          .read(heroActionsProvider)
          .saveHeroAvatar(heroId: 'demo', pngBytes: bytes, stilId: 'aquarell');

      final eintrag = (await repo.loadHeroById('demo'))!
          .appearance
          .avatarGallery
          .single;
      expect(eintrag.quelle, 'ki');
      expect(eintrag.gesichtsbefund, _befund);
      expect(repo.speicherungen, 1);
    });

    test('ohne Befund entsteht der Eintrag wie bisher', () async {
      final c = container(_Erkennung(() async => throw StateError('kaputt')));

      await c
          .read(heroActionsProvider)
          .uploadHeroImage(heroId: 'demo', imageBytes: bytes);

      final eintrag = (await repo.loadHeroById('demo'))!
          .appearance
          .avatarGallery
          .single;
      expect(eintrag.gesichtsbefund, isNull);
      expect(eintrag.toJson(), isNot(contains('gesicht')));
      expect(repo.speicherungen, 1);
    });

    test('eine haengende Erkennung haelt das Anlegen nicht auf', () async {
      final nie = Completer<AvatarGesichtsbefund>();
      final c = container(_Erkennung(() => nie.future));
      final service = c.read(avatarGesichtServiceProvider);

      final befund = await service.erkenneNeu(
        bytes,
        zeitlimit: const Duration(milliseconds: 20),
      );

      expect(befund, isNull);
    });
  });

  group('beim Anzeigen', () {
    test(
      'ein gespeicherter Befund braucht weder Bytes noch Erkennung',
      () async {
        final erkennung = _Erkennung(() async => _befund);
        var bytesGeladen = 0;
        final c = container(
          erkennung,
          hero: held(
            galerie: const [
              AvatarGalleryEntry(
                id: 'a',
                fileName: 'demo_a.png',
                gesichtsbefund: _befund,
                gesichtsbefundVersion: kAvatarGesichtDetektorVersion,
              ),
            ],
          ),
          overrides: [
            avatarBytesProvider.overrideWith((ref, args) async {
              bytesGeladen++;
              return bytes;
            }),
          ],
        );
        await warteAufHeldenindex(c);

        final befund = await c.read(
          avatarGesichtProvider((heroId: 'demo', fileName: 'demo_a.png'))
              .future,
        );

        expect(befund, _befund);
        expect(bytesGeladen, 0);
        expect(erkennung.aufrufe, 0);
      },
    );

    test('ein Befund aelterer Version wird lokal neu erkannt', () async {
      final erkennung = _Erkennung(
        () async => const AvatarGesichtsbefund(bildBreite: 8, bildHoehe: 8),
      );
      final c = container(
        erkennung,
        hero: held(
          galerie: const [
            AvatarGalleryEntry(
              id: 'a',
              fileName: 'demo_a.png',
              gesichtsbefund: _befund,
              gesichtsbefundVersion: kAvatarGesichtDetektorVersion - 1,
            ),
          ],
        ),
        overrides: [
          avatarBytesProvider.overrideWith((ref, args) async => bytes),
        ],
      );
      await warteAufHeldenindex(c);

      final befund = await c.read(
        avatarGesichtProvider((heroId: 'demo', fileName: 'demo_a.png')).future,
      );

      expect(befund!.bildBreite, 8);
      expect(erkennung.aufrufe, 1);
      // Der Held selbst wird dabei nie umgeschrieben.
      expect(repo.speicherungen, 0);
    });
  });
}
