import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ritual_rules.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart'
    show avatarFileStorageProvider;
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
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
    );
    return codec.encode(bundle);
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
        await saveHero(savedHero.copyWith(
          appearance: savedHero.appearance.copyWith(
            avatarGallery: restoredGallery,
          ),
        ));
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
      await saveHero(savedHero.copyWith(
        appearance: savedHero.appearance.copyWith(avatarFileName: fileName),
      ));
    }
    } // end if (hasGallery || hasLegacyAvatar)

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
        avatarSnapshot: primaerbildId.isEmpty
            ? () => null
            : null,
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
