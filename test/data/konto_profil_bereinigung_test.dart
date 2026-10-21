import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/avatar_blob_cache.dart';
import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/data/hive_avatar_sync_marker_store.dart';
import 'package:dsa_heldenverwaltung/data/hive_externe_helden_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_offline_hero_review_store.dart';
import 'package:dsa_heldenverwaltung/data/hive_sync_basis_store.dart';
import 'package:dsa_heldenverwaltung/data/hive_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/hive_vorgangsjournal.dart';
import 'package:dsa_heldenverwaltung/data/konto_profil_bereinigung.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

const _uid = 'uid-1';

HeroSheet _held(String id, {String? bild}) {
  return HeroSheet(
    id: id,
    name: 'Held $id',
    level: 1,
    attributes: const Attributes(
      mu: 11,
      kl: 11,
      inn: 11,
      ch: 11,
      ff: 11,
      ge: 11,
      ko: 11,
      kk: 11,
    ),
    appearance: HeroAppearance(
      avatarGallery: <AvatarGalleryEntry>[
        if (bild != null) AvatarGalleryEntry(id: 'e-$id', fileName: bild),
      ],
    ),
  );
}

class _WebAvatarStorage extends Fake implements AvatarFileStorage {
  _WebAvatarStorage(this.cache);

  final InMemoryAvatarBlobCache cache;

  @override
  bool get isCloudBacked => true;

  @override
  AvatarBlobCache get blobCache => cache;
}

void main() {
  late Directory root;
  late AppStoragePaths paths;
  late String offlinePfad;
  late String kontoPfad;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dsa_konto_bereinigung_');
    paths = AppStoragePaths(appSupportPathLoader: () async => root.path);
    offlinePfad = await paths.prepareHeroStoragePath();
    kontoPfad = await paths.prepareHeroStoragePath(profileId: _uid);
  });

  tearDown(() async {
    await Hive.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<void> legeAvatar(String name) async {
    final datei = File(p.join(offlinePfad, 'avatare', name));
    await datei.parent.create(recursive: true);
    await datei.writeAsBytes(<int>[1, 2, 3]);
  }

  Future<List<String>> dateienIm(String pfad) async {
    final namen = await Directory(pfad)
        .list()
        .where((e) => e is File)
        .map((e) => p.basename(e.path))
        .toList();
    return namen..sort();
  }

  test(
    'entfernt Konto-Boxen und Avatare, Offline-Helden und externe bleiben',
    () async {
      final offline = await HiveHeroRepository.create(storagePath: offlinePfad);
      await offline.saveHero(_held('offline', bild: 'offline.png'));
      await offline.saveHero(_held('beide', bild: 'beide.png'));
      await offline.close();

      final konto = await HiveHeroRepository.create(storagePath: kontoPfad);
      await konto.saveHero(_held('online', bild: 'online.png'));
      await konto.saveHero(_held('beide', bild: 'beide.png'));
      await konto.saveHeroState('online', const HeroState.empty());
      await konto.close();
      // Jede Box des Kontoprofils anlegen, damit eine neue, vergessene Box
      // im Test auffaellt.
      await (await HiveSyncMetadataStore.create(storagePath: kontoPfad))
          .close();
      await (await HiveSyncBasisStore.create(storagePath: kontoPfad)).close();
      await (await HiveOfflineHeroReviewStore.create(storagePath: kontoPfad))
          .close();
      await (await HiveVorgangsjournal.create(storagePath: kontoPfad)).close();
      await (await HiveAvatarSyncMarkerStore.create(storagePath: kontoPfad))
          .close();
      await (await HiveExterneHeldenRepository.create(storagePath: kontoPfad))
          .close();
      for (final name in <String>['offline', 'beide', 'online']) {
        await legeAvatar('$name.png');
      }

      await KontoProfilBereinigung(
        storagePaths: paths,
        istWeb: false,
      ).bereinige(configuredPath: null, uid: _uid);

      final uebrig = await dateienIm(kontoPfad);
      expect(uebrig, isNotEmpty);
      expect(uebrig.every((n) => n.startsWith('externe_helden_v1')), isTrue);

      expect(
        File(p.join(offlinePfad, 'avatare', 'online.png')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(offlinePfad, 'avatare', 'offline.png')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(offlinePfad, 'avatare', 'beide.png')).existsSync(),
        isTrue,
      );

      final offlineNachher = await HiveHeroRepository.create(
        storagePath: offlinePfad,
      );
      expect((await offlineNachher.listHeroes()).map((h) => h.id).toSet(), {
        'offline',
        'beide',
      });
      await offlineNachher.close();
      final kontoNachher = await HiveHeroRepository.create(
        storagePath: kontoPfad,
      );
      expect(await kontoNachher.listHeroes(), isEmpty);
      await kontoNachher.close();
    },
  );

  test('ohne Kontoprofil passiert nichts', () async {
    await KontoProfilBereinigung(
      storagePaths: paths,
      istWeb: false,
    ).bereinige(configuredPath: null, uid: 'unbekannt');
    expect(Directory(kontoPfad).existsSync(), isTrue);
  });

  test(
    'Web: nur Helden mit Sync-Stand gehen, Offline-Helden bleiben',
    () async {
      final repository = await HiveHeroRepository.create(
        storagePath: kontoPfad,
      );
      await repository.saveHero(_held('online', bild: 'online.png'));
      await repository.saveHero(_held('offline', bild: 'offline.png'));
      await repository.saveHeroState('online', const HeroState.empty());
      await repository.close();
      final metadata = await HiveSyncMetadataStore.create(
        storagePath: kontoPfad,
      );
      await metadata.save(
        SyncMetadata(
          key: const SyncObjectKey(type: SyncObjectType.hero, id: 'online'),
          localHash: 'a',
          remoteHash: 'a',
          remoteRevision: '1',
          updatedAt: DateTime.utc(2026),
        ),
      );
      await metadata.close();
      final cache = InMemoryAvatarBlobCache()
        ..eintraege['online.png'] = Uint8List(1)
        ..eintraege['offline.png'] = Uint8List(1);

      await KontoProfilBereinigung(
        storagePaths: paths,
        avatarStorageFactory: () => _WebAvatarStorage(cache),
        istWeb: true,
      ).bereinige(configuredPath: null, uid: _uid);

      final nachher = await HiveHeroRepository.create(storagePath: kontoPfad);
      expect((await nachher.listHeroes()).map((h) => h.id), <String>[
        'offline',
      ]);
      expect(await nachher.loadHeroState('online'), isNull);
      await nachher.close();
      final metadataNachher = await HiveSyncMetadataStore.create(
        storagePath: kontoPfad,
      );
      expect(await metadataNachher.heldenIds(), isEmpty);
      await metadataNachher.close();
      expect(cache.eintraege.keys, <String>['offline.png']);
    },
  );
}
