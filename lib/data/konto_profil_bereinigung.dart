import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Entfernt nach dem Abmelden die lokal vorliegenden Online-Helden.
///
/// Die Helden bleiben in der Cloud und kommen beim naechsten Anmelden zurueck.
/// Es wird nie ueber `SyncingHeroRepository` geloescht: Das wuerde Tombstones
/// in die Cloud schreiben. Offline-Helden bleiben unberuehrt. Die Boxen des
/// Kontoprofils muessen vor dem Aufruf geschlossen sein.
///
/// - Desktop/Mobil: Das Kontoprofil `<base>/accounts/<uid>` ist vom
///   Offline-Profil getrennt; seine Helden-, Zustands- und Sync-Boxen werden
///   geloescht.
/// - Web: Beide Profile teilen sich dieselben Boxen. Dort gelten Helden mit
///   Sync-Stand als Online-Helden; reine Offline-Helden bleiben.
///
/// Die Box `externe_helden_v1` bleibt bewusst erhalten: Manuell angelegte
/// externe Helden existieren nur lokal.
class KontoProfilBereinigung {
  /// Erstellt die Bereinigung mit den Test-Hooks fuer Plattform und Ablage.
  KontoProfilBereinigung({
    required this.storagePaths,
    AvatarFileStorage Function()? avatarStorageFactory,
    bool? istWeb,
  }) : _avatarStorageFactory = avatarStorageFactory ?? createAvatarFileStorage,
       _istWeb = istWeb ?? kIsWeb;

  /// Zentrale Pfadlogik des Heldenspeichers.
  final AppStoragePaths storagePaths;

  final AvatarFileStorage Function() _avatarStorageFactory;
  final bool _istWeb;

  static const String _heldenBox = 'heroes_v1';

  /// Boxen des Kontoprofils, die beim Abmelden entfernt werden.
  ///
  /// Muss zu den Box-Namen der Hive-Speicher passen (Test
  /// `konto_profil_bereinigung_test.dart` prueft das).
  static const List<String> kontoBoxen = <String>[
    'heroes_v1',
    'hero_states_v1',
    'sync_metadata_v1',
    'sync_basis_v1',
    'offline_hero_review_v1',
    'vorgaenge_v1',
    'avatar_sync_v1',
  ];

  /// Entfernt die lokalen Daten des Kontos [uid].
  Future<void> bereinige({
    required String? configuredPath,
    required String uid,
  }) async {
    final kontoPfad = await storagePaths.resolveProfileStoragePath(
      configuredPath: configuredPath,
      profileId: uid,
    );
    final avatarPfad = (await storagePaths.describeHeroStorageLocation(
      configuredPath: configuredPath,
    )).effectivePath;

    final kontoHelden = await _liesHelden(kontoPfad);
    if (_istWeb) {
      await _bereinigeWeb(kontoPfad, avatarPfad, kontoHelden);
      return;
    }
    final offlinePfad = await storagePaths.resolveProfileStoragePath(
      configuredPath: configuredPath,
    );
    final offlineIds = (await _liesHelden(offlinePfad))
        .map((held) => held.id)
        .toSet();
    await _entferneAvatare(
      avatarPfad,
      kontoHelden.where((held) => !offlineIds.contains(held.id)),
    );
    for (final box in kontoBoxen) {
      await Hive.deleteBoxFromDisk(box, path: kontoPfad);
    }
  }

  Future<List<HeroSheet>> _liesHelden(String pfad) async {
    if (!await Hive.boxExists(_heldenBox, path: pfad)) {
      return const <HeroSheet>[];
    }
    final repository = await HiveHeroRepository.create(storagePath: pfad);
    try {
      return await repository.listHeroes();
    } finally {
      await repository.close();
    }
  }

  // Web: Nur Helden mit Sync-Stand loeschen, danach die Sync-Boxen leeren.
  Future<void> _bereinigeWeb(
    String pfad,
    String avatarPfad,
    List<HeroSheet> helden,
  ) async {
    final metadata = await HiveSyncMetadataStore.create(storagePath: pfad);
    final Set<String> onlineIds;
    try {
      onlineIds = await metadata.heldenIds();
    } finally {
      await metadata.close();
    }
    final online = helden.where((held) => onlineIds.contains(held.id)).toList();
    if (online.isNotEmpty) {
      final repository = await HiveHeroRepository.create(storagePath: pfad);
      try {
        for (final held in online) {
          await repository.deleteHero(held.id);
        }
      } finally {
        await repository.close();
      }
    }
    await _entferneAvatare(avatarPfad, online);
    for (final box in kontoBoxen) {
      if (box == _heldenBox || box == 'hero_states_v1') {
        continue;
      }
      await Hive.deleteBoxFromDisk(box, path: pfad);
    }
  }

  // Entfernt nur lokale Kopien: Web-Zwischenspeicher bzw. Dateien. Die Cloud
  // bleibt unberuehrt, deshalb nie ueber `SyncingAvatarStorage`.
  Future<void> _entferneAvatare(
    String avatarPfad,
    Iterable<HeroSheet> helden,
  ) async {
    final dateien = <String>{
      for (final held in helden) ...[
        for (final eintrag in held.appearance.avatarGallery) eintrag.fileName,
        held.appearance.avatarFileName,
      ],
    }..remove('');
    if (dateien.isEmpty) {
      return;
    }
    final storage = _avatarStorageFactory();
    for (final datei in dateien) {
      try {
        if (storage.isCloudBacked) {
          await storage.blobCache?.remove(datei);
        } else {
          await storage.deleteGalleryImage(
            heroStoragePath: avatarPfad,
            fileName: datei,
          );
        }
      } on Object catch (error) {
        debugPrint('[logout] Avatar $datei nicht entfernt: $error');
      }
    }
  }
}
