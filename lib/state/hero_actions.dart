import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/gruppen_snapshot_codec.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ritual_rules.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart'
    show avatarFileStorageProvider, avatarThumbnailEncoderProvider;
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gruppen_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart'
    show heroComputedProvider;
import 'package:dsa_heldenverwaltung/state/settings_providers.dart'
    show heroStorageLocationProvider;

/// Steuert, wie beim Import eines bereits vorhandenen Helden verfahren wird.
enum ImportConflictResolution {
  /// Ueberschreibt den vorhandenen Helden mit den importierten Daten.
  overwriteExisting,

  /// Legt den importierten Helden als neuen Eintrag mit einer neuen ID an.
  createNewHero,
}

/// Orchestriert alle schreibenden Heldenoperationen sowie Import und Export.
///
/// Greift ueber Riverpod-Provider auf [HeroRepository] und [HeroTransferCodec]
/// zu. Normalisiert AP-Werte, Level und Modifier-Fragmente vor dem Speichern.
/// Instanzen werden ausschliesslich ueber [heroActionsProvider] bezogen.
class HeroActions {
  HeroActions(this._ref);

  final Ref _ref;

  /// Legt einen neuen Helden mit Standardattributen an.
  ///
  /// Der Held erhaelt den uebergebenen Namen, Roh-Startwerte und einen initialen
  /// leeren [HeroState]. Standard-Talente und feste Meta-Talente werden direkt
  /// im Heldenmodell vorbelegt. Die effektiven Startwerte werden aus
  /// Herkunftsmods normalisiert gespeichert. Gibt die neue ID zurueck.
  Future<String> createHero({
    required String name,
    required Attributes rawStartAttributes,
  }) async {
    final repo = _ref.read(heroRepositoryProvider);
    const uuid = Uuid();
    final id = uuid.v4();
    final hero = HeroSheet(
      id: id,
      name: name.trim().isEmpty ? 'Neuer Held' : name.trim(),
      level: 1,
      attributes: rawStartAttributes,
      rawStartAttributes: rawStartAttributes,
      startAttributes: rawStartAttributes,
      talents: _buildDefaultTalents(),
      metaTalents: _buildDefaultMetaTalents(),
    );
    await saveHero(hero);
    await repo.saveHeroState(
      id,
      const HeroState(
        currentLep: 0,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 0,
      ),
    );
    _ref.read(selectedHeroIdProvider.notifier).state = id;
    return id;
  }

  /// Speichert einen Helden nach Normalisierung von AP, Level und Modifikatoren.
  ///
  /// Negative AP-Werte werden auf 0 gesetzt.
  /// [level] und [apAvailable] werden aus [apSpent] neu berechnet.
  /// Unbekannte Modifier-Fragmente werden in [HeroSheet.unknownModifierFragments]
  /// festgehalten.
  Future<void> saveHero(HeroSheet hero) async {
    final repo = _ref.read(heroRepositoryProvider);

    final normalizedApTotal = hero.apTotal < 0 ? 0 : hero.apTotal;
    final normalizedApSpent = hero.apSpent < 0 ? 0 : hero.apSpent;
    final calculatedLevel = computeLevelFromSpentAp(normalizedApSpent);
    final calculatedAvailable = computeAvailableAp(
      normalizedApTotal,
      normalizedApSpent,
    );
    final parsed = parseModifierTextsForHero(hero);
    final originAttributeModifiers = parseOriginAttributeModifiers(hero);
    final effectiveStartAttributes = computeEffectiveStartAttributes(
      hero.rawStartAttributes,
      originAttributeModifiers,
    );

    final normalizedHero = hero.copyWith(
      apTotal: normalizedApTotal,
      apSpent: normalizedApSpent,
      apAvailable: calculatedAvailable,
      level: calculatedLevel,
      startAttributes: effectiveStartAttributes,
      ritualCategories: normalizeRitualCategories(hero.ritualCategories),
      unknownModifierFragments: parsed.unknownFragments,
    );

    // Inventar mit Kampf-Tab synchronisieren (Waffen, Ruestung, Geschosse)
    final reconciledEntries = reconcileInventoryWithCombat(
      normalizedHero.inventoryEntries,
      normalizedHero.combatConfig,
    );
    final reconciledHero = normalizedHero.copyWith(
      inventoryEntries: reconciledEntries,
    );

    await repo.saveHero(reconciledHero);
  }

  /// Speichert den Laufzeitzustand (LeP, AsP, KaP, Au, temp. Mods) eines Helden.
  Future<void> saveHeroState(String heroId, HeroState state) async {
    final repo = _ref.read(heroRepositoryProvider);
    await repo.saveHeroState(heroId, state);
  }

  /// Loescht einen Helden und seinen Zustand dauerhaft aus dem Repository.
  ///
  /// Setzt [selectedHeroIdProvider] zurueck, wenn der geloeschte Held
  /// aktuell ausgewaehlt war.
  Future<void> deleteHero(String heroId) async {
    final repo = _ref.read(heroRepositoryProvider);
    await repo.deleteHero(heroId);
    final selected = _ref.read(selectedHeroIdProvider);
    if (selected == heroId) {
      _ref.read(selectedHeroIdProvider.notifier).state = null;
    }
  }

  /// Erstellt einen formatierten Export-JSON-String fuer den angegebenen Helden.
  ///
  /// Wirft [StateError] wenn kein Held mit [heroId] gefunden wird.
  Future<String> buildExportJson(String heroId) async {
    final repo = _ref.read(heroRepositoryProvider);
    final codec = _ref.read(heroTransferCodecProvider);
    final hero = await _loadHeroById(heroId);
    final state = (await repo.loadHeroState(heroId)) ?? const HeroState.empty();
    final runtimeData = await _ref.read(catalogRuntimeDataProvider.future);
    final transferCatalogEntries = _buildTransferCatalogEntries(
      hero: hero,
      runtimeData: runtimeData,
    );
    // Avatar-Bytes laden und base64-kodieren (falls vorhanden)
    String? avatarBase64;
    List<Map<String, dynamic>>? galleryImages;
    final hasAvatar = hero.appearance.avatarFileName.isNotEmpty;
    final hasGallery = hero.appearance.avatarGallery.isNotEmpty;

    if (hasAvatar || hasGallery) {
      final heroStoragePath = await _resolveHeroStoragePath();
      final storage = _ref.read(avatarFileStorageProvider);

      if (hasAvatar) {
        final bytes = await storage.loadAvatarBytes(
          heroStoragePath: heroStoragePath,
          avatarFileName: hero.appearance.avatarFileName,
        );
        if (bytes != null) {
          avatarBase64 = base64Encode(bytes);
        }
      }

      // Gallery-Bilder base64-kodiert einbetten
      if (hasGallery) {
        galleryImages = [];
        for (final entry in hero.appearance.avatarGallery) {
          final bytes = await storage.loadGalleryImageBytes(
            heroStoragePath: heroStoragePath,
            fileName: entry.fileName,
          );
          if (bytes != null) {
            galleryImages.add({
              ...entry.toJson(),
              'base64': base64Encode(bytes),
            });
          }
        }
      }
    }

    final bundle = HeroTransferBundle(
      exportedAt: DateTime.now().toUtc(),
      hero: hero,
      state: state,
      avatarBase64: avatarBase64,
      galleryImages: galleryImages,
      catalogEntries: transferCatalogEntries.isEmpty
          ? null
          : transferCatalogEntries,
    );
    return codec.encode(bundle);
  }

  /// Erstellt einen Gruppen-Snapshot-JSON-String fuer die angegebenen Helden.
  ///
  /// Laedt fuer jeden Helden Sheet, State und abgeleitete Werte und baut
  /// daraus kompakte [HeldVisitenkarte]-Eintraege.
  Future<String> buildGruppenExportJson({
    required String gruppenName,
    required List<String> heroIds,
  }) async {
    final repo = _ref.read(heroRepositoryProvider);
    final visitenkarten = <HeldVisitenkarte>[];

    for (final heroId in heroIds) {
      final hero = await repo.loadHeroById(heroId);
      if (hero == null) continue;
      final state =
          (await repo.loadHeroState(heroId)) ?? const HeroState.empty();
      final derivedStats = computeDerivedStats(hero, state);

      final avatarThumbnailBase64 = await _loadAvatarThumbnailBase64(hero);
      visitenkarten.add(
        HeldVisitenkarte.fromHeroComputed(
          hero,
          derivedStats,
          avatarThumbnailBase64: avatarThumbnailBase64,
        ),
      );
    }

    final snapshot = GruppenSnapshot(
      gruppenName: gruppenName.trim().isEmpty
          ? 'Meine Gruppe'
          : gruppenName.trim(),
      exportedAt: DateTime.now().toUtc(),
      helden: visitenkarten,
    );
    return const GruppenSnapshotCodec().encode(snapshot);
  }

  /// Parst einen Import-JSON-String zu einem [HeroTransferBundle].
  ///
  /// Wirft [FormatException] bei ungueltigem JSON oder falschem Format.
  Future<HeroTransferBundle> parseImportJson(String rawJson) async {
    final codec = _ref.read(heroTransferCodecProvider);
    return codec.decode(rawJson);
  }

  /// Importiert ein [HeroTransferBundle] gemaess der Konfliktloesung.
  ///
  /// Bei [ImportConflictResolution.createNewHero] wird eine neue UUID vergeben.
  /// Gibt die ID des importierten (ggf. neu erstellten) Helden zurueck.
  Future<String> importHeroBundle(
    HeroTransferBundle bundle, {
    required ImportConflictResolution resolution,
  }) async {
    const uuid = Uuid();

    var hero = bundle.hero;
    var heroId = hero.id;
    if (resolution == ImportConflictResolution.createNewHero) {
      heroId = uuid.v4();
      hero = hero.copyWith(id: heroId);
    }

    final transferCatalogEntries = bundle.catalogEntries;
    if (transferCatalogEntries != null && transferCatalogEntries.isNotEmpty) {
      final runtimeData = await _ref.read(catalogRuntimeDataProvider.future);
      final repository = _ref.read(customCatalogRepositoryProvider);
      await repository.importTransferEntries(
        catalogVersion: runtimeData.baseData.version,
        entries: transferCatalogEntries
            .map(
              (entry) => CustomCatalogEntryRecord(
                section: entry.section,
                id: entry.id,
                filePath: '',
                data: entry.data,
              ),
            )
            .toList(growable: false),
      );
      _ref.read(catalogActionsProvider).reloadCatalog();
    }

    await saveHero(hero);
    await saveHeroState(heroId, bundle.state);

    final hasGallery =
        bundle.galleryImages != null && bundle.galleryImages!.isNotEmpty;
    final hasLegacyAvatar =
        bundle.avatarBase64 != null && bundle.avatarBase64!.isNotEmpty;

    if (hasGallery || hasLegacyAvatar) {
      final heroStoragePath = await _resolveHeroStoragePath();
      final storage = _ref.read(avatarFileStorageProvider);

      // Gallery-Bilder aus Bundle importieren (falls vorhanden)
      if (hasGallery) {
        final restoredGallery = <AvatarGalleryEntry>[];
        for (final img in bundle.galleryImages!) {
          final b64 = img['base64'] as String?;
          if (b64 == null || b64.isEmpty) continue;
          final entryJson = Map<String, dynamic>.from(img)..remove('base64');
          final entry = AvatarGalleryEntry.fromJson(entryJson);
          final pngBytes = base64Decode(b64);
          await storage.saveGalleryImage(
            heroStoragePath: heroStoragePath,
            heroId: heroId,
            entryId: entry.id,
            pngBytes: pngBytes,
          );
          restoredGallery.add(entry);
        }
        if (restoredGallery.isNotEmpty) {
          final savedHero = await _loadHeroById(heroId);
          await saveHero(
            savedHero.copyWith(
              appearance: savedHero.appearance.copyWith(
                avatarGallery: restoredGallery,
              ),
            ),
          );
        }
      }

      // Legacy-Avatar aus Bundle importieren (falls vorhanden)
      if (hasLegacyAvatar) {
        final pngBytes = base64Decode(bundle.avatarBase64!);
        final fileName = await storage.saveAvatar(
          heroStoragePath: heroStoragePath,
          heroId: heroId,
          pngBytes: pngBytes,
        );
        final savedHero = await _loadHeroById(heroId);
        await saveHero(
          savedHero.copyWith(
            appearance: savedHero.appearance.copyWith(avatarFileName: fileName),
          ),
        );
      }
    }

    _ref.read(selectedHeroIdProvider.notifier).state = heroId;
    return heroId;
  }

  /// Speichert ein KI-generiertes Avatar-Bild und legt einen Gallery-Eintrag an.
  ///
  /// [stilId] und [promptAuszug] werden am Gallery-Eintrag hinterlegt.
  Future<void> saveHeroAvatar({
    required String heroId,
    required List<int> pngBytes,
    String stilId = '',
    String promptAuszug = '',
  }) async {
    final hero = await _loadHeroById(heroId);
    final heroStoragePath = await _resolveHeroStoragePath();
    final storage = _ref.read(avatarFileStorageProvider);
    const uuid = Uuid();
    final entryId = uuid.v4();

    final fileName = await storage.saveGalleryImage(
      heroStoragePath: heroStoragePath,
      heroId: heroId,
      entryId: entryId,
      pngBytes: pngBytes,
    );

    // Legacy-Kompatibilitaet: auch als Haupt-Avatar speichern
    await storage.saveAvatar(
      heroStoragePath: heroStoragePath,
      heroId: heroId,
      pngBytes: pngBytes,
    );

    final entry = AvatarGalleryEntry(
      id: entryId,
      fileName: fileName,
      quelle: 'ki',
      stilId: stilId,
      erstelltAm: DateTime.now().toUtc().toIso8601String(),
      promptAuszug: promptAuszug.length > 200
          ? promptAuszug.substring(0, 200)
          : promptAuszug,
    );

    final updatedGallery = [...hero.appearance.avatarGallery, entry];
    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(
        avatarFileName: '$heroId.png',
        avatarGallery: updatedGallery,
      ),
    );
    await saveHero(updated);
  }

  /// Laedt ein eigenes Bild hoch und fuegt es zur Gallery hinzu.
  Future<void> uploadHeroImage({
    required String heroId,
    required List<int> imageBytes,
  }) async {
    final hero = await _loadHeroById(heroId);
    final heroStoragePath = await _resolveHeroStoragePath();
    final storage = _ref.read(avatarFileStorageProvider);
    const uuid = Uuid();
    final entryId = uuid.v4();

    final fileName = await storage.saveGalleryImage(
      heroStoragePath: heroStoragePath,
      heroId: heroId,
      entryId: entryId,
      pngBytes: imageBytes,
    );

    // Auch als aktiven Avatar setzen
    await storage.saveAvatar(
      heroStoragePath: heroStoragePath,
      heroId: heroId,
      pngBytes: imageBytes,
    );

    final entry = AvatarGalleryEntry(
      id: entryId,
      fileName: fileName,
      quelle: 'upload',
      erstelltAm: DateTime.now().toUtc().toIso8601String(),
    );

    final updatedGallery = [...hero.appearance.avatarGallery, entry];
    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(
        avatarFileName: '$heroId.png',
        avatarGallery: updatedGallery,
      ),
    );
    await saveHero(updated);
  }

  /// Setzt ein Gallery-Bild als Primaerbild und erstellt einen Snapshot.
  Future<void> setPrimaerbild({
    required String heroId,
    required String galleryEntryId,
  }) async {
    final hero = await _loadHeroById(heroId);

    final snapshot = AvatarSnapshot(
      erstelltAm: DateTime.now().toUtc().toIso8601String(),
      attributes: {
        'MU': hero.attributes.mu,
        'KL': hero.attributes.kl,
        'IN': hero.attributes.inn,
        'CH': hero.attributes.ch,
        'FF': hero.attributes.ff,
        'GE': hero.attributes.ge,
        'KO': hero.attributes.ko,
        'KK': hero.attributes.kk,
      },
      alter: hero.appearance.alter,
      vorteileText: hero.vorteileText,
      nachteileText: hero.nachteileText,
      rasse: hero.background.rasse,
      geschlecht: hero.appearance.geschlecht,
      haarfarbe: hero.appearance.haarfarbe,
      augenfarbe: hero.appearance.augenfarbe,
    );

    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(
        primaerbildId: galleryEntryId,
        avatarSnapshot: () => snapshot,
      ),
    );
    await saveHero(updated);
  }

  /// Setzt ein Gallery-Bild als aktiv angezeigten Avatar.
  Future<void> setActiveAvatar({
    required String heroId,
    required String galleryEntryId,
  }) async {
    final hero = await _loadHeroById(heroId);
    final entry = hero.appearance.avatarGallery
        .where((e) => e.id == galleryEntryId)
        .firstOrNull;
    if (entry == null) return;

    final heroStoragePath = await _resolveHeroStoragePath();
    final storage = _ref.read(avatarFileStorageProvider);

    // Gallery-Bild als Haupt-Avatar kopieren
    final bytes = await storage.loadGalleryImageBytes(
      heroStoragePath: heroStoragePath,
      fileName: entry.fileName,
    );
    if (bytes != null) {
      await storage.saveAvatar(
        heroStoragePath: heroStoragePath,
        heroId: heroId,
        pngBytes: bytes,
      );
    }

    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(avatarFileName: '$heroId.png'),
    );
    await saveHero(updated);
  }

  /// Entfernt ein einzelnes Bild aus der Gallery.
  Future<void> removeGalleryImage({
    required String heroId,
    required String galleryEntryId,
  }) async {
    final hero = await _loadHeroById(heroId);
    final entry = hero.appearance.avatarGallery
        .where((e) => e.id == galleryEntryId)
        .firstOrNull;
    if (entry == null) return;

    final heroStoragePath = await _resolveHeroStoragePath();
    final storage = _ref.read(avatarFileStorageProvider);
    await storage.deleteGalleryImage(
      heroStoragePath: heroStoragePath,
      fileName: entry.fileName,
    );

    final updatedGallery = hero.appearance.avatarGallery
        .where((e) => e.id != galleryEntryId)
        .toList();

    // Primaerbild-Referenz aufraeuemen falls betroffen
    final primaerbildId = hero.appearance.primaerbildId == galleryEntryId
        ? ''
        : hero.appearance.primaerbildId;

    // Wenn letztes Bild entfernt → auch Haupt-Avatar loeschen
    var avatarFileName = hero.appearance.avatarFileName;
    if (updatedGallery.isEmpty && avatarFileName.isNotEmpty) {
      await storage.deleteAvatar(
        heroStoragePath: heroStoragePath,
        avatarFileName: avatarFileName,
      );
      avatarFileName = '';
    }

    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(
        avatarFileName: avatarFileName,
        avatarGallery: updatedGallery,
        primaerbildId: primaerbildId,
        avatarSnapshot: primaerbildId.isEmpty ? () => null : null,
      ),
    );
    await saveHero(updated);
  }

  /// Entfernt den Avatar eines Helden (Legacy-Methode, entfernt alle Bilder).
  Future<void> removeHeroAvatar(String heroId) async {
    final hero = await _loadHeroById(heroId);
    if (hero.appearance.avatarFileName.isEmpty &&
        hero.appearance.avatarGallery.isEmpty) {
      return;
    }
    final heroStoragePath = await _resolveHeroStoragePath();
    final storage = _ref.read(avatarFileStorageProvider);

    // Haupt-Avatar loeschen
    if (hero.appearance.avatarFileName.isNotEmpty) {
      await storage.deleteAvatar(
        heroStoragePath: heroStoragePath,
        avatarFileName: hero.appearance.avatarFileName,
      );
    }

    // Alle Gallery-Bilder loeschen
    for (final entry in hero.appearance.avatarGallery) {
      await storage.deleteGalleryImage(
        heroStoragePath: heroStoragePath,
        fileName: entry.fileName,
      );
    }

    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(
        avatarFileName: '',
        avatarGallery: const [],
        primaerbildId: '',
        avatarSnapshot: () => null,
      ),
    );
    await saveHero(updated);
  }

  // ---------------------------------------------------------------------------
  // Gruppen-Verwaltung
  // ---------------------------------------------------------------------------

  /// Erstellt eine neue Gruppe fuer einen Helden (Firebase + lokal).
  ///
  /// Gibt den generierten Gruppencode zurueck.
  Future<String> erstelleGruppe({
    required String heroId,
    required String gruppenName,
  }) async {
    final syncService = _ref.read(gruppenSyncServiceProvider);
    final gruppenCode = await syncService.erstelleGruppe(gruppenName);

    final hero = await _loadHeroById(heroId);
    final neueGruppen = List<HeroGruppenMitgliedschaft>.from(hero.gruppen)
      ..add(
        HeroGruppenMitgliedschaft(
          gruppenCode: gruppenCode,
          gruppenName: gruppenName,
        ),
      );
    await saveHero(hero.copyWith(gruppen: neueGruppen));

    // Eigene Visitenkarte direkt pushen.
    await _pushEigeneVisitenkarte(heroId: heroId, gruppenCode: gruppenCode);

    return gruppenCode;
  }

  /// Tritt einer bestehenden Gruppe bei (via Code).
  Future<void> trittGruppeBei({
    required String heroId,
    required String gruppenCode,
  }) async {
    final syncService = _ref.read(gruppenSyncServiceProvider);
    final existiert = await syncService.gruppeExistiert(gruppenCode);
    if (!existiert) {
      throw StateError('Gruppe mit Code "$gruppenCode" existiert nicht.');
    }

    final gruppenName = await syncService.ladeGruppenName(gruppenCode);
    final hero = await _loadHeroById(heroId);

    // Doppelten Beitritt verhindern.
    if (hero.gruppen.any((g) => g.gruppenCode == gruppenCode)) return;

    final neueGruppen = List<HeroGruppenMitgliedschaft>.from(hero.gruppen)
      ..add(
        HeroGruppenMitgliedschaft(
          gruppenCode: gruppenCode,
          gruppenName: gruppenName,
        ),
      );
    await saveHero(hero.copyWith(gruppen: neueGruppen));

    // Eigene Visitenkarte pushen.
    await _pushEigeneVisitenkarte(heroId: heroId, gruppenCode: gruppenCode);
  }

  /// Verlaesst eine Gruppe.
  Future<void> verlasseGruppe({
    required String heroId,
    required String gruppenCode,
  }) async {
    final syncService = _ref.read(gruppenSyncServiceProvider);
    await syncService.leaveGruppe(gruppenCode, heroId);
    await syncService.stopListenerFuerGruppe(gruppenCode);

    final hero = await _loadHeroById(heroId);
    final neueGruppen = hero.gruppen
        .where((g) => g.gruppenCode != gruppenCode)
        .toList(growable: false);
    await saveHero(hero.copyWith(gruppen: neueGruppen));
  }

  /// Fuegt einen manuell erstellten externen Helden zu einer Gruppe hinzu.
  Future<void> addManuellerHeld({
    required String heroId,
    required String gruppenCode,
    required ExternerHeld held,
  }) async {
    // Externen Helden persistieren.
    final externeRepo = _ref.read(externeHeldenRepositoryProvider);
    await externeRepo.save(held);

    // Referenz in der Gruppenconfig des Helden hinzufuegen.
    final hero = await _loadHeroById(heroId);
    final neueGruppen = List<HeroGruppenMitgliedschaft>.from(hero.gruppen);
    final index = neueGruppen.indexWhere((g) => g.gruppenCode == gruppenCode);
    if (index < 0) return;

    final mitgliedschaft = neueGruppen[index];
    if (mitgliedschaft.externeHeldIds.contains(held.id)) return;

    neueGruppen[index] = mitgliedschaft.copyWith(
      externeHeldIds: [...mitgliedschaft.externeHeldIds, held.id],
    );
    await saveHero(hero.copyWith(gruppen: neueGruppen));

    // Manuellen Helden direkt nach Firestore pushen.
    final syncService = _ref.read(gruppenSyncServiceProvider);
    final karte = HeldVisitenkarte.fromExternerHeld(held);
    await syncService.pushVisitenkarte(gruppenCode, karte);
  }

  /// Entfernt einen externen Helden aus einer Gruppe.
  Future<void> removeExternerHeld({
    required String heroId,
    required String gruppenCode,
    required String externerHeldId,
  }) async {
    final hero = await _loadHeroById(heroId);
    final neueGruppen = List<HeroGruppenMitgliedschaft>.from(hero.gruppen);
    final index = neueGruppen.indexWhere((g) => g.gruppenCode == gruppenCode);
    if (index < 0) return;

    final mitgliedschaft = neueGruppen[index];
    neueGruppen[index] = mitgliedschaft.copyWith(
      externeHeldIds: mitgliedschaft.externeHeldIds
          .where((id) => id != externerHeldId)
          .toList(growable: false),
    );
    await saveHero(hero.copyWith(gruppen: neueGruppen));
  }

  /// Aktualisiert die eigene Visitenkarte in allen Gruppen des Helden.
  Future<void> syncVisitenkarten(String heroId) async {
    final hero = await _loadHeroById(heroId);
    if (hero.gruppen.isEmpty) return;

    for (final gruppe in hero.gruppen) {
      await _pushEigeneVisitenkarte(
        heroId: heroId,
        gruppenCode: gruppe.gruppenCode,
      );
    }
  }

  /// Fuehrt einen vollstaendigen Sync fuer alle Gruppen des Helden durch:
  /// 1. Eigene Visitenkarte pushen
  /// 2. Manuell angelegte Helden pushen
  /// 3. Fremde Mitglieder abholen und lokal ueberschreiben
  Future<void> syncGruppen(String heroId) async {
    final hero = await _loadHeroById(heroId);
    if (hero.gruppen.isEmpty) return;

    final syncService = _ref.read(gruppenSyncServiceProvider);
    final externeRepo = _ref.read(externeHeldenRepositoryProvider);

    for (final gruppe in hero.gruppen) {
      final gruppenCode = gruppe.gruppenCode;

      // 1. Eigene Visitenkarte pushen.
      await _pushEigeneVisitenkarte(heroId: heroId, gruppenCode: gruppenCode);

      // 2. Manuelle Helden dieser Gruppe pushen.
      for (final extId in gruppe.externeHeldIds) {
        final ext = externeRepo.loadById(extId);
        if (ext != null && ext.istManuell) {
          final karte = HeldVisitenkarte.fromExternerHeld(ext);
          await syncService.pushVisitenkarte(gruppenCode, karte);
        }
      }

      // 3. Alle Mitglieder abholen und lokal aktualisieren.
      final remoteMitglieder = await syncService.fetchMitglieder(gruppenCode);
      final neueExterneIds = <String>[...gruppe.externeHeldIds];

      // IDs lokal verwalteter manueller Helden — nicht ueberschreiben.
      final lokaleManuelleIds = <String>{
        for (final extId in gruppe.externeHeldIds)
          if (externeRepo.loadById(extId)?.istManuell ?? false) extId,
      };

      for (final karte in remoteMitglieder) {
        // Eigenen Helden ueberspringen.
        if (karte.heroId == heroId) continue;

        // Lokal manuell angelegte Helden nicht mit Remote-Daten
        // ueberschreiben — sie werden nur gepusht, nie gepullt.
        if (lokaleManuelleIds.contains(karte.heroId)) continue;

        final externer = ExternerHeld.fromVisitenkarte(karte);
        await externeRepo.save(externer);

        if (!neueExterneIds.contains(karte.heroId)) {
          neueExterneIds.add(karte.heroId);
        }
      }

      // Aktualisierte externeHeldIds speichern, falls neue Mitglieder.
      if (neueExterneIds.length != gruppe.externeHeldIds.length) {
        final aktualisierterHero = await _loadHeroById(heroId);
        final neueGruppen = List<HeroGruppenMitgliedschaft>.from(
          aktualisierterHero.gruppen,
        );
        final idx = neueGruppen.indexWhere((g) => g.gruppenCode == gruppenCode);
        if (idx >= 0) {
          neueGruppen[idx] = neueGruppen[idx].copyWith(
            externeHeldIds: neueExterneIds,
          );
          await saveHero(aktualisierterHero.copyWith(gruppen: neueGruppen));
        }
      }
    }
  }

  Future<void> _pushEigeneVisitenkarte({
    required String heroId,
    required String gruppenCode,
  }) async {
    final hero = await _loadHeroById(heroId);
    final computed = _ref.read(heroComputedProvider(heroId));
    final derivedStats = computed.valueOrNull?.derivedStats;
    if (derivedStats == null) return;

    final avatarThumbnailBase64 = await _loadAvatarThumbnailBase64(hero);

    final karte = HeldVisitenkarte.fromHeroComputed(
      hero,
      derivedStats,
      avatarThumbnailBase64: avatarThumbnailBase64,
    );

    final syncService = _ref.read(gruppenSyncServiceProvider);
    await syncService.pushVisitenkarte(gruppenCode, karte);
  }

  /// Laedt das aktive Avatarbild und reduziert es auf ein kompaktes
  /// Gruppen-Thumbnail fuer Export und Firestore-Sync.
  Future<String?> _loadAvatarThumbnailBase64(HeroSheet hero) async {
    if (hero.appearance.avatarFileName.isEmpty) return null;

    try {
      final heroStoragePath = await _resolveHeroStoragePath();
      final storage = _ref.read(avatarFileStorageProvider);
      final avatarBytes = await storage.loadAvatarBytes(
        heroStoragePath: heroStoragePath,
        avatarFileName: hero.appearance.avatarFileName,
      );
      if (avatarBytes == null) return null;

      final encoder = _ref.read(avatarThumbnailEncoderProvider);
      return encoder.createThumbnailBase64(imageBytes: avatarBytes);
    } on Exception {
      // Avatar-Fehler ignorieren, damit der Sync nicht blockiert.
      return null;
    }
  }

  /// Ermittelt den aktuell wirksamen Heldenspeicherpfad.
  Future<String> _resolveHeroStoragePath() async {
    final location = await _ref.read(heroStorageLocationProvider.future);
    return location.effectivePath;
  }

  /// Laedt einen Helden aus dem Repository.
  ///
  /// Wirft [StateError] wenn kein Held mit [heroId] gefunden wird.
  Future<HeroSheet> _loadHeroById(String heroId) async {
    final repo = _ref.read(heroRepositoryProvider);
    final hero = await repo.loadHeroById(heroId);
    if (hero != null) {
      return hero;
    }
    throw StateError('Held mit ID "$heroId" wurde nicht gefunden.');
  }
}

Map<String, HeroTalentEntry> _buildDefaultTalents() {
  return Map<String, HeroTalentEntry>.unmodifiable({
    for (final talentId in _defaultTalentIds) talentId: const HeroTalentEntry(),
  });
}

List<HeroMetaTalent> _buildDefaultMetaTalents() {
  return List<HeroMetaTalent>.unmodifiable(const <HeroMetaTalent>[
    HeroMetaTalent(
      id: 'meta_kraeutersuchen',
      name: 'Kräutersuchen',
      componentTalentIds: <String>[
        'tal_sinnesschaerfe',
        'tal_wildnisleben',
        'tal_pflanzenkunde',
      ],
      attributes: <String>['MU', 'IN', 'FF'],
      be: '',
    ),
  ]);
}

const Set<String> _defaultTalentIds = <String>{
  'tal_dolche',
  'tal_hiebwaffen',
  'tal_raufen',
  'tal_ringen',
  'tal_saebel',
  'tal_wurfmesser',
  'tal_athletik',
  'tal_klettern',
  'tal_koerperbeherrschung',
  'tal_schleichen',
  'tal_schwimmen',
  'tal_selbstbeherrschung',
  'tal_sich_verstecken',
  'tal_singen',
  'tal_sinnesschaerfe',
  'tal_tanzen',
  'tal_zechen',
  'tal_menschenkenntnis',
  'tal_ueberreden',
  'tal_faehrtensuchen',
  'tal_orientierung',
  'tal_wildnisleben',
  'tal_goetter_kulte',
  'tal_rechnen',
  'tal_sagen_legenden',
  'tal_heilkunde_wunden',
  'tal_holzbearbeitung',
  'tal_kochen',
  'tal_lederarbeiten',
  'tal_malen_zeichnen',
  'tal_schneidern',
  'tal_pflanzenkunde',
};

List<HeroTransferCatalogEntry> _buildTransferCatalogEntries({
  required HeroSheet hero,
  required CatalogRuntimeData runtimeData,
}) {
  final effectiveCustomEntries = _effectiveCustomEntryMaps(runtimeData);
  final referencedIds = <CatalogSectionId, Set<String>>{
    for (final section in editableCatalogSections) section: <String>{},
  };

  void addId(CatalogSectionId section, String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return;
    }
    referencedIds[section]!.add(normalized);
  }

  for (final talentId in hero.talents.keys) {
    addId(CatalogSectionId.talents, talentId);
    addId(CatalogSectionId.combatTalents, talentId);
  }
  for (final talentId in hero.hiddenTalentIds) {
    addId(CatalogSectionId.talents, talentId);
    addId(CatalogSectionId.combatTalents, talentId);
  }
  for (final metaTalent in hero.metaTalents) {
    for (final componentId in metaTalent.componentTalentIds) {
      addId(CatalogSectionId.talents, componentId);
      addId(CatalogSectionId.combatTalents, componentId);
    }
  }
  for (final spellId in hero.spells.keys) {
    addId(CatalogSectionId.spells, spellId);
  }
  for (final spracheId in hero.sprachen.keys) {
    addId(CatalogSectionId.sprachen, spracheId);
  }
  for (final schriftId in hero.schriften.keys) {
    addId(CatalogSectionId.schriften, schriftId);
  }
  addId(CatalogSectionId.sprachen, hero.muttersprache);

  for (final spracheId in referencedIds[CatalogSectionId.sprachen]!) {
    final sprache =
        effectiveCustomEntries[CatalogSectionId.sprachen]![spracheId];
    if (sprache == null) {
      continue;
    }
    final rawSchriftIds = (sprache['schriftIds'] as List?) ?? const [];
    for (final schriftId in rawSchriftIds) {
      addId(CatalogSectionId.schriften, schriftId.toString());
    }
  }

  for (final weapon in hero.combatConfig.weaponSlots) {
    addId(CatalogSectionId.talents, weapon.talentId);
    addId(CatalogSectionId.combatTalents, weapon.talentId);
  }
  for (final mastery in hero.combatConfig.waffenmeisterschaften) {
    addId(CatalogSectionId.talents, mastery.talentId);
    addId(CatalogSectionId.combatTalents, mastery.talentId);
  }
  for (final maneuverId in hero.combatConfig.specialRules.activeManeuvers) {
    addId(CatalogSectionId.maneuvers, maneuverId);
  }
  for (final abilityId
      in hero.combatConfig.specialRules.activeCombatSpecialAbilityIds) {
    addId(CatalogSectionId.combatSpecialAbilities, abilityId);
  }

  final customCombatTalentsByName = <String, String>{};
  for (final entry
      in effectiveCustomEntries[CatalogSectionId.combatTalents]!.values) {
    final name = (entry['name'] as String? ?? '').trim().toLowerCase();
    final id = (entry['id'] as String? ?? '').trim();
    if (name.isNotEmpty && id.isNotEmpty) {
      customCombatTalentsByName[name] = id;
    }
  }
  final customManeuversByName = <String, String>{};
  for (final entry
      in effectiveCustomEntries[CatalogSectionId.maneuvers]!.values) {
    final name = (entry['name'] as String? ?? '').trim().toLowerCase();
    final id = (entry['id'] as String? ?? '').trim();
    if (name.isNotEmpty && id.isNotEmpty) {
      customManeuversByName[name] = id;
    }
  }

  for (final abilityId
      in referencedIds[CatalogSectionId.combatSpecialAbilities]!) {
    final ability =
        effectiveCustomEntries[CatalogSectionId
            .combatSpecialAbilities]![abilityId];
    if (ability == null) {
      continue;
    }
    final rawManeuverIds =
        (ability['aktiviert_manoever_ids'] as List?) ?? const [];
    final maneuverIds = rawManeuverIds.map((entry) => entry.toString());
    for (final maneuverId in maneuverIds) {
      addId(CatalogSectionId.maneuvers, maneuverId);
    }
  }

  for (final weaponEntry
      in effectiveCustomEntries[CatalogSectionId.weapons]!.values) {
    final weaponName = (weaponEntry['name'] as String? ?? '').trim();
    if (weaponName.isEmpty) {
      continue;
    }

    final matchesWeapon = hero.combatConfig.weaponSlots.any((slot) {
      return slot.name.trim() == weaponName ||
          slot.weaponType.trim() == weaponName;
    });
    final matchesMastery = hero.combatConfig.waffenmeisterschaften.any(
      (mastery) => mastery.weaponType.trim() == weaponName,
    );
    if (!matchesWeapon && !matchesMastery) {
      continue;
    }

    addId(
      CatalogSectionId.weapons,
      (weaponEntry['id'] as String? ?? '').trim(),
    );

    final combatSkillName = (weaponEntry['combatSkill'] as String? ?? '')
        .trim()
        .toLowerCase();
    if (combatSkillName.isNotEmpty) {
      final customTalentId = customCombatTalentsByName[combatSkillName];
      if (customTalentId != null) {
        addId(CatalogSectionId.combatTalents, customTalentId);
      }
    }

    final rawManeuvers =
        (weaponEntry['possibleManeuvers'] as List?) ?? const [];
    final rawActiveManeuvers =
        (weaponEntry['activeManeuvers'] as List?) ?? const [];
    for (final raw in <dynamic>[...rawManeuvers, ...rawActiveManeuvers]) {
      final value = raw.toString().trim();
      if (value.isEmpty) {
        continue;
      }
      addId(CatalogSectionId.maneuvers, value);
      final maneuverId = customManeuversByName[value.toLowerCase()];
      if (maneuverId != null) {
        addId(CatalogSectionId.maneuvers, maneuverId);
      }
    }
  }

  final entries = <HeroTransferCatalogEntry>[];
  for (final section in editableCatalogSections) {
    final entryMap = effectiveCustomEntries[section]!;
    final sortedIds = referencedIds[section]!.toList()..sort();
    for (final entryId in sortedIds) {
      final entry = entryMap[entryId];
      if (entry == null) {
        continue;
      }
      entries.add(
        HeroTransferCatalogEntry(section: section, id: entryId, data: entry),
      );
    }
  }
  return List<HeroTransferCatalogEntry>.unmodifiable(entries);
}

Map<CatalogSectionId, Map<String, Map<String, dynamic>>>
_effectiveCustomEntryMaps(CatalogRuntimeData runtimeData) {
  final baseIds = <CatalogSectionId, Set<String>>{
    for (final section in editableCatalogSections)
      section: runtimeData.baseData
          .entriesFor(section)
          .map((entry) => (entry['id'] as String? ?? '').trim())
          .where((id) => id.isNotEmpty)
          .toSet(),
  };
  final result = <CatalogSectionId, Map<String, Map<String, dynamic>>>{
    for (final section in editableCatalogSections)
      section: <String, Map<String, dynamic>>{},
  };
  for (final section in editableCatalogSections) {
    for (final entry in runtimeData.effectiveData.entriesFor(section)) {
      final id = (entry['id'] as String? ?? '').trim();
      if (id.isEmpty || baseIds[section]!.contains(id)) {
        continue;
      }
      result[section]![id] = entry;
    }
  }
  return result;
}
