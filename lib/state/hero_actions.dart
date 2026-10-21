import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/held_importieren.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/hero_trait_text.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/gruppen_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/domain/gruppen_beitrittscode.dart';
import 'package:dsa_heldenverwaltung/domain/held_visitenkarte.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_instanz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_slot_instanz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_rahmung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht/avatar_gesichtserkennung.dart'
    show kAvatarGesichtDetektorVersion;
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ritual_rules.dart';
import 'package:dsa_heldenverwaltung/data/cloud_avatar_storage.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart'
    show
        avatarFileStorageProvider,
        avatarGesichtServiceProvider,
        avatarThumbnailEncoderProvider,
        gespeicherterGesichtsbefund;
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart'
    show heroComputedProvider;
import 'package:dsa_heldenverwaltung/state/settings_providers.dart'
    show heroStorageLocationProvider;

/// Höchstdauer, die das Speichern eines Helden auf den Regelkatalog wartet.
///
/// Wie beim Öffnen eines Helden im Home-Screen; danach wird ohne
/// Katalogfilter der Parser-Restfragmente gespeichert.
const Duration kKatalogWartezeitBeimSpeichern = Duration(seconds: 20);

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
  /// Erzeugt die Aktionen; [katalogWartezeit] begrenzt das Warten auf den
  /// Regelkatalog beim Speichern (Tests setzen sie herab).
  HeroActions(
    this._ref, {
    this.katalogWartezeit = kKatalogWartezeitBeimSpeichern,
  });

  final Ref _ref;

  /// Höchstdauer, die [saveHero] auf einen noch ladenden Regelkatalog wartet.
  final Duration katalogWartezeit;

  /// Legt einen neuen Helden mit Standardattributen an.
  ///
  /// Der Held erhaelt den uebergebenen Namen, Roh-Startwerte und einen initialen
  /// leeren [HeroState]. Standard-Talente und feste Meta-Talente werden direkt
  /// im Heldenmodell vorbelegt. Die effektiven Startwerte werden aus
  /// Herkunftsmods normalisiert gespeichert. Gibt die neue ID zurueck.
  ///
  /// Wirft eine Exception, wenn das Helden-Limit von [maxHeldenProNutzer]
  /// erreicht ist.
  Future<String> createHero({
    required String name,
    required Attributes rawStartAttributes,
  }) async {
    final repo = _ref.read(heroRepositoryProvider);
    final existingHeroes = await repo.listHeroes();
    if (existingHeroes.length >= maxHeldenProNutzer) {
      throw Exception(
        'Maximale Anzahl von $maxHeldenProNutzer Helden erreicht. '
        'Bitte lösche einen bestehenden Helden, bevor du einen neuen erstellst.',
      );
    }
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
    // Eingereiht und gestempelt (ARCH-06). Bricht die App vor diesem
    // Schritt ab, gilt der fehlende Zustand ohnehin als leer.
    await aendereGespeichertenZustand(
      repository: repo,
      heroId: id,
      aenderung: (_) => const HeroState.empty(),
      uhr: DateTime.now,
    );
    await _ref.read(selectedHeroSelectionActionsProvider).selectHero(id);
    return id;
  }

  /// Speichert einen Helden nach Normalisierung von AP, Level und Modifikatoren.
  ///
  /// Negative AP-Werte werden auf 0 gesetzt.
  /// [level] und [apAvailable] werden aus [apSpent] neu berechnet.
  /// Unbekannte Modifier-Fragmente werden in [HeroSheet.unknownModifierFragments]
  /// festgehalten.
  /// [expectedContentHash] verhindert, dass eine Steigerungsrunde Änderungen
  /// überschreibt, die während ihrer Planung oder Normalisierung gespeichert wurden.
  /// [validationCatalog] hält die Katalogprüfung einer Steigerungsrunde stabil
  /// und vermeidet ein erneutes asynchrones Laden beim Übernehmen.
  ///
  /// Das Speichern reiht sich hinter laufende Bogenänderungen desselben
  /// Helden ein (`reiheBogenvorgangEin`, ARCH-05): Ein Editorentwurf landet so
  /// nie zwischen Laden und Schreiben einer frischen Änderung, und die
  /// Hash-Prüfung sieht jede vorher eingereihte Änderung. Liefert den
  /// normalisierten, gespeicherten Helden.
  Future<HeroSheet> saveHero(
    HeroSheet hero, {
    String? expectedContentHash,
    RulesCatalog? validationCatalog,
  }) {
    final repo = _ref.read(heroRepositoryProvider);
    return reiheBogenvorgangEin(
      repository: repo,
      heroId: hero.id,
      vorgang: () => _speichereNormalisiert(
        repo,
        hero,
        expectedContentHash: expectedContentHash,
        validationCatalog: validationCatalog,
      ),
    );
  }

  // Normalisiert und speichert ohne Warteschlange. Nur aus einem bereits
  // eingereihten Bogenvorgang aufrufen; ein erneutes Einreihen darin wartete
  // auf sich selbst.
  Future<HeroSheet> _speichereNormalisiert(
    HeroRepository repo,
    HeroSheet hero, {
    String? expectedContentHash,
    RulesCatalog? validationCatalog,
  }) async {
    final normalizedApTotal = hero.apTotal < 0 ? 0 : hero.apTotal;
    final normalizedApSpent = hero.apSpent < 0 ? 0 : hero.apSpent;
    final calculatedLevel = computeLevelFromSpentAp(normalizedApSpent);
    final calculatedAvailable = computeAvailableAp(
      normalizedApTotal,
      normalizedApSpent,
    );
    // Vor-/Nachteile: Alttext beim ersten Speichern migrieren, sonst den
    // Text als Projektion der Liste schreiben (ARCH-02). Ohne geladenen
    // Katalog wird nicht migriert; gewartet wird darauf bewusst nicht.
    final profil = _verstandenesProfil(hero);
    final catalog = validationCatalog ?? _katalogDesHelden(profil);
    final heroMitMerkmalen =
        merkmaleZumSpeichern(
          hero,
          katalog: catalog == null ? null : MerkmalKatalog.von(catalog),
        ).copyWith(
          // Herkunftstexte einmalig in den Container ueberfuehren (ARCH-02);
          // ein vorhandener Container bleibt unangetastet, auch bei Abweichung.
          background: herkunftZumSpeichern(hero.background),
        );
    final parsed = parseModifierTextsForHero(
      heroMitMerkmalen,
      catalog: catalog,
    );
    final unknownModifierFragments = await _filterKnownTraitWarnings(
      parsed.unknownFragments,
      catalog: catalog,
      profil: profil,
    );
    final effectiveStartAttributes = computeHeroEffectiveStartAttributes(
      heroMitMerkmalen,
      catalog: catalog,
    );

    // Neue Slots bekommen eine zufaellige ID, damit sie nie die Inventardaten
    // eines gerade entfernten Slots erben; geladene tragen ihre schon.
    final combatConfigMitIds = hero.combatConfig.withStableIds(
      neueId: () => const Uuid().v4(),
    );
    final normalizedHero = heroMitMerkmalen.copyWith(
      combatConfig: combatConfigMitIds,
      apTotal: normalizedApTotal,
      apSpent: normalizedApSpent,
      apAvailable: calculatedAvailable,
      level: calculatedLevel,
      // Neu errechnet; `uebernimmWerte` behaelt unbekannte Felder.
      startAttributes: hero.startAttributes.uebernimmWerte(
        effectiveStartAttributes,
      ),
      ritualCategories: normalizeRitualCategories(hero.ritualCategories),
      unknownModifierFragments: unknownModifierFragments,
    );

    // Inventar mit Kampf-Tab synchronisieren (Waffen, Ruestung, Geschosse)
    final reconciledEntries = reconcileInventoryWithCombat(
      normalizedHero.inventoryEntries,
      normalizedHero.combatConfig,
    );
    // Jede Nutzeraenderung bekommt einen frischen Stempel. Hive ergaenzt ihn
    // nur, wenn er fehlt; ein geladener Held braechte sonst seinen alten mit,
    // und ohne Konto bliebe der Zeitpunkt des ersten Speicherns stehen
    // (Befund ARCH-07-B4). Inhalts-Hashes ignorieren das Feld.
    // Menge und Instanz-IDs erst hier, nie beim Laden (ARCH-03, Hash-Pins).
    final entriesMitInstanzen = vergibInstanzIds(
      ueberfuehreInventarMengen(reconciledEntries),
      neueId: () => const Uuid().v4(),
    );
    final reconciledHero = normalizedHero.copyWith(
      inventoryEntries: entriesMitInstanzen,
      // Verweis Slot → Instanz aus dem abgeglichenen Inventar (ARCH-03).
      combatConfig: bindeSlotsAnInstanzen(
        normalizedHero.combatConfig,
        entriesMitInstanzen,
      ),
      lastModified: DateTime.now().toUtc(),
    );

    if (expectedContentHash != null) {
      final current = await repo.loadHeroById(hero.id);
      if (current == null || heroContentHash(current) != expectedContentHash) {
        throw StateError(
          'Der Held wurde inzwischen geändert. Die Steigerungen wurden '
          'nicht übernommen.',
        );
      }
    }
    await repo.saveHero(reconciledHero);
    return reconciledHero;
  }

  /// Wendet eine gezielte Änderung auf den frisch geladenen Helden an.
  ///
  /// Kompatibilitätseinstieg für [aendereGespeichertenHelden] (ARCH-05),
  /// Gegenstück zu [updateHeroState]: Felder, die seit dem letzten UI-Aufbau
  /// anderswo gespeichert wurden, bleiben erhalten, weil [update] den Stand
  /// aus dem Repository bekommt statt eines beim Rendern erfassten Snapshots.
  /// Die Normalisierung ist dieselbe wie bei [saveHero]. Aufrufe laufen je
  /// Held nacheinander, auch gegenüber [saveHero]; liefert [update] dasselbe
  /// Objekt zurück, wird nichts gespeichert. Liefert den gespeicherten Helden.
  ///
  /// [update] darf selbst weder [saveHero] noch [updateHero] aufrufen: beide
  /// warten auf den laufenden Vorgang und damit auf sich selbst.
  ///
  /// [validationCatalog] ersetzt wie bei [saveHero] den Katalog der
  /// Normalisierung; ein Wechsel des Regelprofils gibt hier den Katalog des
  /// neuen Profils mit, statt sich darauf zu verlassen, dass er schon geladen ist.
  Future<HeroSheet> updateHero(
    String heroId,
    HeroSheet Function(HeroSheet current) update, {
    RulesCatalog? validationCatalog,
  }) {
    final repo = _ref.read(heroRepositoryProvider);
    return aendereGespeichertenHelden(
      repository: repo,
      heroId: heroId,
      aenderung: update,
      speichere: (geaendert) => _speichereNormalisiert(
        repo,
        geaendert,
        validationCatalog: validationCatalog,
      ),
    );
  }

  /// Speichert den Laufzeitzustand (LeP, AsP, KaP, Au, temp. Mods) eines Helden.
  Future<void> saveHeroState(String heroId, HeroState state) async {
    final repo = _ref.read(heroRepositoryProvider);
    await repo.saveHeroState(
      heroId,
      mitAenderungszeitpunkt(state, DateTime.now()),
    );
  }

  /// Wendet eine gezielte Änderung auf den frisch geladenen Laufzeitzustand an.
  ///
  /// Kompatibilitätseinstieg für [aendereGespeichertenZustand] (ARCH-05).
  /// Erhält Felder, die seit dem letzten UI-Aufbau geändert wurden. Dies ist
  /// keine Transaktion gegenüber gleichzeitig laufenden Repository-Schreibwegen;
  /// Aufrufe über diesen Einstieg laufen je Held aber nacheinander. Liefert
  /// den gespeicherten Zustand.
  Future<HeroState> updateHeroState(
    String heroId,
    HeroState Function(HeroState current) update,
  ) {
    return aendereGespeichertenZustand(
      repository: _ref.read(heroRepositoryProvider),
      heroId: heroId,
      aenderung: update,
      uhr: DateTime.now,
    );
  }

  // Katalogisierte Vor-/Nachteile sollen nicht als Parser-Restfragmente
  // erscheinen. Ohne Katalog (Fehler, Zeitüberschreitung, Test- oder
  // Bootstrap-Kontext) bleiben die Fragmente ungefiltert.
  Future<List<String>> _filterKnownTraitWarnings(
    List<String> fragments, {
    RulesCatalog? catalog,
    HeroRegelProfil? profil,
  }) async {
    if (fragments.isEmpty) {
      return fragments;
    }
    try {
      final resolvedCatalog =
          catalog ?? await _warteAufRegelkatalog(profil: profil);
      if (resolvedCatalog == null) {
        return fragments;
      }
      return filterKnownHeroTraitFragments(
        fragments: fragments,
        advantages: resolvedCatalog.advantages,
        disadvantages: resolvedCatalog.disadvantages,
      );
    } on Object {
      return fragments;
    }
  }

  // Wartet auf den Regelkatalog, liefert bei Fehler oder nach
  // [katalogWartezeit] aber `null`. Bewusst über ein Abo statt über
  // `rulesCatalogProvider.future`: jene Future endet in Riverpod 3 nicht
  // immer (CLAUDE.md), und ein hängendes Laden ließe jedes Speichern hängen.
  // Das Abo hält die Katalogkette zugleich am Leben.
  Future<RulesCatalog?> _warteAufRegelkatalog({HeroRegelProfil? profil}) {
    final ergebnis = Completer<RulesCatalog?>();
    void pruefe(AsyncValue<RulesCatalog> naechster) {
      if (ergebnis.isCompleted) {
        return;
      }
      if (naechster.hasValue) {
        ergebnis.complete(naechster.value);
      } else if (naechster.hasError) {
        ergebnis.complete(null);
      }
    }

    // Ein Held mit Regelprofil rechnet nach dessen Katalog (ARCH-04).
    final abo = profil == null
        ? _ref.listen<AsyncValue<RulesCatalog>>(
            rulesCatalogProvider,
            (_, naechster) => pruefe(naechster),
            fireImmediately: true,
          )
        : _ref.listen<AsyncValue<RulesCatalog>>(
            regelProfilAufloesungProvider(profil)
                .select((a) => a.whenData((r) => r.katalog)),
            (_, naechster) => pruefe(naechster),
            fireImmediately: true,
          );
    return ergebnis.future
        .timeout(katalogWartezeit, onTimeout: () => null)
        .whenComplete(abo.close);
  }

  // Das Profil des Helden, falls diese App-Version es versteht.
  HeroRegelProfil? _verstandenesProfil(HeroSheet hero) {
    final profil = hero.regelProfil;
    return profil != null && profil.istVerstanden ? profil : null;
  }

  // Der bereits geladene Katalog, nach dem der Held rechnet; `null` solange er
  // noch lädt (gewartet wird beim Speichern bewusst nicht).
  RulesCatalog? _katalogDesHelden(HeroRegelProfil? profil) {
    if (profil == null) {
      return _ref.read(rulesCatalogProvider).valueOrNull;
    }
    return _ref
        .read(regelProfilAufloesungProvider(profil))
        .valueOrNull
        ?.katalog;
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
      await _ref.read(selectedHeroSelectionActionsProvider).clearSelection();
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
    final aktivesBild = hero.appearance.aktivesBild;
    final hasGallery = hero.appearance.avatarGallery.isNotEmpty;

    if (hasGallery) {
      final heroStoragePath = await _resolveHeroStoragePath();
      final storage = _ref.read(avatarFileStorageProvider);

      // Ein nicht ladbares Bild darf den Export nie abbrechen: Der Held
      // selbst ist wichtiger als sein Portraet.
      Future<List<int>?> loadOrNull(String fileName) async {
        try {
          return await storage.loadGalleryImageBytes(
            heroStoragePath: heroStoragePath,
            fileName: fileName,
          );
        } on Object {
          return null;
        }
      }

      // `avatarBase64` bleibt fuer aeltere Importer befuellt; die Galerie
      // unten traegt dieselben Bytes noch einmal mit ihren Metadaten.
      if (aktivesBild != null) {
        final bytes = await loadOrNull(aktivesBild.fileName);
        if (bytes != null) {
          avatarBase64 = base64Encode(bytes);
        }
      }

      // Gallery-Bilder base64-kodiert einbetten
      galleryImages = [];
      for (final entry in hero.appearance.avatarGallery) {
        final bytes = await loadOrNull(entry.fileName);
        if (bytes != null) {
          galleryImages.add({...entry.toJson(), 'base64': base64Encode(bytes)});
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

  /// Parst einen Import-JSON-String zu einem [HeroTransferBundle].
  ///
  /// Wirft [FormatException] bei ungueltigem JSON oder falschem Format.
  Future<HeroTransferBundle> parseImportJson(String rawJson) async {
    final codec = _ref.read(heroTransferCodecProvider);
    return codec.decode(rawJson);
  }

  /// Importiert ein [HeroTransferBundle] gemaess der Konfliktloesung.
  ///
  /// Kompatibilitätseinstieg für [importiereHeld]; liefert nur die ID des
  /// importierten (ggf. neu erstellten) Helden.
  Future<String> importHeroBundle(
    HeroTransferBundle bundle, {
    required ImportConflictResolution resolution,
  }) async {
    final ergebnis = await importiereHeld(bundle, resolution: resolution);
    return ergebnis.heroId;
  }

  /// Importiert ein [HeroTransferBundle] über den Ablauf [HeldImportieren]
  /// (ARCH-05) und wählt den Helden aus.
  ///
  /// Bei [ImportConflictResolution.createNewHero] wird eine neue UUID
  /// vergeben. Wirft eine Exception, wenn die Ziel-ID noch nicht existiert
  /// und das Helden-Limit von [maxHeldenProNutzer] erreicht ist. Bilder, die
  /// sich nicht speichern lassen, fehlen im Helden und werden im Ergebnis
  /// gezählt.
  Future<HeldImportErgebnis> importiereHeld(
    HeroTransferBundle bundle, {
    required ImportConflictResolution resolution,
  }) async {
    final repo = _ref.read(heroRepositoryProvider);
    final storage = _ref.read(avatarFileStorageProvider);
    Future<String>? speicherpfad;
    Future<String> heroStoragePath() =>
        speicherpfad ??= _resolveHeroStoragePath();

    final ablauf = HeldImportieren(
      repository: repo,
      speichere: saveHero,
      uebernimmKatalog: _uebernimmTransferKatalog,
      speichereGaleriebild:
          ({required heroId, required entryId, required bytes}) async =>
              storage.saveGalleryImage(
                heroStoragePath: await heroStoragePath(),
                heroId: heroId,
                entryId: entryId,
                pngBytes: bytes,
              ),
      speichereHauptbild: ({required heroId, required bytes}) async =>
          storage.saveAvatar(
            heroStoragePath: await heroStoragePath(),
            heroId: heroId,
            pngBytes: bytes,
          ),
      loescheBild: (dateiname) async => storage.deleteGalleryImage(
        heroStoragePath: await heroStoragePath(),
        fileName: dateiname,
      ),
      journal: _ref.read(vorgangsjournalProvider),
      neueId: () => const Uuid().v4(),
      uhr: DateTime.now,
      maxHelden: maxHeldenProNutzer,
    );
    final ergebnis = await ablauf.importiere(
      bundle,
      neuAnlegen: resolution == ImportConflictResolution.createNewHero,
    );
    await _ref
        .read(selectedHeroSelectionActionsProvider)
        .selectHero(ergebnis.heroId);
    return ergebnis;
  }

  // Legt eingebettete eigene Katalogeinträge eines Exports an und lädt den
  // Katalog neu.
  Future<void> _uebernimmTransferKatalog(
    List<HeroTransferCatalogEntry> eintraege,
  ) async {
    final runtimeData = await _ref.read(catalogRuntimeDataProvider.future);
    final repository = _ref.read(customCatalogRepositoryProvider);
    await repository.importTransferEntries(
      catalogVersion: runtimeData.baseData.version,
      entries: eintraege
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

  /// Speichert ein KI-generiertes Avatar-Bild und legt einen Gallery-Eintrag an.
  ///
  /// [stilId] und [promptAuszug] werden am Gallery-Eintrag hinterlegt.
  /// Wirft eine Exception, wenn das Online-Limit von [maxKiBilderOnline]
  /// erreicht ist.
  Future<void> saveHeroAvatar({
    required String heroId,
    required List<int> pngBytes,
    String stilId = '',
    String promptAuszug = '',
  }) async {
    final hero = await _loadHeroById(heroId);
    final kiCount = hero.appearance.avatarGallery
        .where((e) => e.quelle == 'ki')
        .length;
    if (kiCount >= maxKiBilderProHeld) {
      throw Exception(
        'Maximale Anzahl von $maxKiBilderProHeld KI-Bildern pro Held erreicht. '
        'Bitte lösche ein bestehendes KI-Bild, bevor du ein neues generierst.',
      );
    }
    final heroStoragePath = await _resolveHeroStoragePath();
    final storage = _ref.read(avatarFileStorageProvider);
    const uuid = Uuid();
    final entryId = uuid.v4();
    final gesichtsbefund = _erkenneGesichtBeimAnlegen(pngBytes);

    final fileName = await storage.saveGalleryImage(
      heroStoragePath: heroStoragePath,
      heroId: heroId,
      entryId: entryId,
      pngBytes: pngBytes,
    );
    _requireStoredFileName(fileName);

    final befund = await gesichtsbefund;
    final entry = AvatarGalleryEntry(
      id: entryId,
      fileName: fileName,
      gesichtsbefund: befund,
      gesichtsbefundVersion: befund == null
          ? null
          : kAvatarGesichtDetektorVersion,
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
        avatarGallery: updatedGallery,
        aktivesBildId: entryId,
      ),
    );
    await saveHero(updated);
  }

  /// Laedt ein eigenes Bild hoch und fuegt es zur Gallery hinzu.
  Future<void> uploadHeroImage({
    required String heroId,
    required List<int> imageBytes,
  }) async {
    if (imageBytes.length > maxAvatarBildBytes) {
      final megabytes = (maxAvatarBildBytes / (1024 * 1024)).round();
      throw Exception(
        'Das Bild ist zu gross (maximal $megabytes MB). Bitte verkleinere es '
        'und versuche es erneut.',
      );
    }
    final hero = await _loadHeroById(heroId);
    final heroStoragePath = await _resolveHeroStoragePath();
    final storage = _ref.read(avatarFileStorageProvider);
    const uuid = Uuid();
    final entryId = uuid.v4();
    final gesichtsbefund = _erkenneGesichtBeimAnlegen(imageBytes);

    final fileName = await storage.saveGalleryImage(
      heroStoragePath: heroStoragePath,
      heroId: heroId,
      entryId: entryId,
      pngBytes: imageBytes,
    );
    _requireStoredFileName(fileName);

    final befund = await gesichtsbefund;
    final entry = AvatarGalleryEntry(
      id: entryId,
      fileName: fileName,
      gesichtsbefund: befund,
      gesichtsbefundVersion: befund == null
          ? null
          : kAvatarGesichtDetektorVersion,
      quelle: 'upload',
      erstelltAm: DateTime.now().toUtc().toIso8601String(),
    );

    final updatedGallery = [...hero.appearance.avatarGallery, entry];
    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(
        avatarGallery: updatedGallery,
        aktivesBildId: entryId,
      ),
    );
    await saveHero(updated);
  }

  /// Startet die Gesichtserkennung fuer ein gerade angelegtes Bild.
  ///
  /// Laeuft parallel zum Speichern der Bilddatei. Der Befund wandert an den
  /// neuen Galerieeintrag und damit in den `saveHero`, der ohnehin folgt —
  /// ein eigener Schreibvorgang entsteht nicht. Liefert der Service `null`
  /// (Fehler, Zeitlimit), entsteht der Eintrag ohne Befund.
  Future<AvatarGesichtsbefund?> _erkenneGesichtBeimAnlegen(List<int> bytes) {
    return _ref
        .read(avatarGesichtServiceProvider)
        .erkenneNeu(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
  }

  /// Stellt sicher, dass die Ablage einen gueltigen Dateinamen geliefert hat.
  ///
  /// Im Web gibt die Ablage ohne angemeldeten Nutzer einen leeren Namen
  /// zurueck. Ohne diesen Guard entstuende ein Galerie-Eintrag, der auf keine
  /// Datei zeigt und nie wieder reparierbar waere.
  void _requireStoredFileName(String fileName) {
    if (fileName.isNotEmpty) return;
    throw Exception(
      'Das Bild konnte nicht gespeichert werden. Bitte melde dich an und '
      'versuche es erneut.',
    );
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

  /// Speichert einen Fokuspunkt fuer den kompakten Workspace-Header.
  Future<void> setAvatarHeaderFocus({
    required String heroId,
    required String galleryEntryId,
    required double focusX,
    required double focusY,
    double? zoom,
  }) async {
    final hero = await _loadHeroById(heroId);
    final normalizedFocusX = focusX.clamp(0.0, 1.0).toDouble();
    final normalizedFocusY = focusY.clamp(0.0, 1.0).toDouble();
    final normalizedZoom = zoom?.clamp(1.0, 8.0).toDouble();
    var didUpdate = false;
    final updatedGallery = hero.appearance.avatarGallery
        .map((entry) {
          if (entry.id != galleryEntryId) {
            return entry;
          }
          didUpdate = true;
          return entry.copyWith(
            headerFocusX: normalizedFocusX,
            headerFocusY: normalizedFocusY,
            headerZoom: normalizedZoom,
          );
        })
        .toList(growable: false);

    if (!didUpdate) {
      return;
    }

    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(avatarGallery: updatedGallery),
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

    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(aktivesBildId: galleryEntryId),
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

    // Aktiv-Referenz aufraeumen falls betroffen
    var aktivesBildId = hero.appearance.aktivesBildId == galleryEntryId
        ? ''
        : hero.appearance.aktivesBildId;

    // Wenn letztes Bild entfernt → auch Haupt-Avatar loeschen
    var avatarFileName = hero.appearance.avatarFileName;
    if (updatedGallery.isEmpty && avatarFileName.isNotEmpty) {
      await storage.deleteAvatar(
        heroStoragePath: heroStoragePath,
        avatarFileName: avatarFileName,
      );
      avatarFileName = '';
      aktivesBildId = '';
    }

    final updated = hero.copyWith(
      appearance: hero.appearance.copyWith(
        avatarFileName: avatarFileName,
        avatarGallery: updatedGallery,
        primaerbildId: primaerbildId,
        aktivesBildId: aktivesBildId,
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

    // Alle Gallery-Bilder loeschen; die Cloud-Seite erledigt der Decorator.
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
        aktivesBildId: '',
        avatarSnapshot: () => null,
      ),
    );
    await saveHero(updated);
  }

  // ---------------------------------------------------------------------------
  // Gruppen-Verwaltung (groups_v2)
  // ---------------------------------------------------------------------------

  /// Erstellt eine neue Gruppe fuer einen Helden (Firebase + lokal).
  ///
  /// Gibt die Gruppen-ID zurueck. Den teilbaren Beitrittscode liefert
  /// [ladeBeitrittscode].
  Future<String> erstelleGruppe({
    required String heroId,
    required String gruppenName,
  }) async {
    _requireGruppenSyncAvailable();
    final syncService = _ref.read(gruppenSyncServiceProvider);
    final info = await syncService.erstelleGruppe(gruppenName);
    await _traegeMitgliedschaftEin(heroId, info);
    await _pushEigeneVisitenkarteBestEffort(heroId, info.groupId);
    return info.groupId;
  }

  /// Tritt einer bestehenden Gruppe bei (mit dem geteilten Beitrittscode).
  ///
  /// Gibt die Gruppen-ID zurueck.
  Future<String> trittGruppeBei({
    required String heroId,
    required String beitrittscode,
  }) async {
    _requireGruppenSyncAvailable();
    final code = GruppenBeitrittscode.parse(beitrittscode);
    if (code == null) {
      throw const GruppenException(
        'Der Beitrittscode ist unvollständig. Bitte den ganzen Code '
        'einfügen, den dir ein Gruppenmitglied geschickt hat.',
      );
    }
    final syncService = _ref.read(gruppenSyncServiceProvider);
    final info = await syncService.tritteBei(code);
    await _traegeMitgliedschaftEin(heroId, info);
    await _pushEigeneVisitenkarteBestEffort(heroId, info.groupId);
    return info.groupId;
  }

  /// Liest den teilbaren Beitrittscode einer Gruppe (nur Mitglieder koennen es).
  Future<String> ladeBeitrittscode(String gruppenCode) async {
    _requireGruppenSyncAvailable();
    final info = await _ref
        .read(gruppenSyncServiceProvider)
        .ladeGruppe(gruppenCode);
    return info.beitrittscode.text;
  }

  /// Speichert die gemeinsamen Gruppennotizen; alle Mitglieder duerfen das.
  Future<void> speichereGruppenNotizen({
    required String gruppenCode,
    required String text,
  }) async {
    _requireGruppenSyncAvailable();
    await _ref
        .read(gruppenSyncServiceProvider)
        .speichereNotizen(gruppenCode, text);
  }

  /// Erneuert den Beitrittscode (nur Besitzer) und gibt die neue Form zurueck.
  Future<String> erneuereBeitrittscode(String gruppenCode) async {
    _requireGruppenSyncAvailable();
    final code = await _ref
        .read(gruppenSyncServiceProvider)
        .erneuereBeitrittscode(gruppenCode);
    return code.text;
  }

  /// Verlaesst eine Gruppe. Altgruppen (gesperrter Legacy-Pfad) werden nur
  /// lokal vom Helden entfernt.
  Future<void> verlasseGruppe({
    required String heroId,
    required String gruppenCode,
  }) async {
    final hero = await _loadHeroById(heroId);
    final mitgliedschaft = hero.gruppen
        .where((g) => g.gruppenCode == gruppenCode)
        .firstOrNull;
    if (mitgliedschaft != null && mitgliedschaft.kontoGruppe) {
      _requireGruppenSyncAvailable();
      await _ref.read(gruppenSyncServiceProvider).verlasseGruppe(gruppenCode);
    }
    await _entferneMitgliedschaft(heroId, gruppenCode);
  }

  /// Loescht eine Gruppe fuer alle Mitglieder (nur Besitzer).
  Future<void> loescheGruppe({
    required String heroId,
    required String gruppenCode,
  }) async {
    _requireGruppenSyncAvailable();
    await _ref.read(gruppenSyncServiceProvider).loescheGruppe(gruppenCode);
    await _entferneMitgliedschaft(heroId, gruppenCode);
  }

  /// Fuegt einen manuell erstellten Eintrag zu einer Gruppe hinzu.
  ///
  /// Der Eintrag wird als geteilte Gruppeninfo geschrieben: Alle Mitglieder
  /// sehen und pflegen ihn. Erst nach dem erfolgreichen Upload landet er lokal.
  Future<void> addManuellerHeld({
    required String heroId,
    required String gruppenCode,
    required ExternerHeld held,
  }) async {
    _requireGruppenSyncAvailable();
    final hero = await _loadHeroById(heroId);
    final mitgliedschaft = hero.gruppen
        .where((g) => g.gruppenCode == gruppenCode)
        .firstOrNull;
    if (mitgliedschaft == null) return;
    if (!mitgliedschaft.kontoGruppe) {
      throw const GruppenException(_altgruppeMeldung);
    }

    await _ref
        .read(gruppenSyncServiceProvider)
        .pushGeteilterHeld(
          gruppenCode,
          HeldVisitenkarte.fromExternerHeld(held),
        );
    await _ref.read(externeHeldenRepositoryProvider).save(held);

    // Frisch laden: Der Upload kann lange gedauert haben.
    final aktuell = await _loadHeroById(heroId);
    final neueGruppen = List<HeroGruppenMitgliedschaft>.from(aktuell.gruppen);
    final index = neueGruppen.indexWhere((g) => g.gruppenCode == gruppenCode);
    if (index < 0) return;
    final aktuelleMitgliedschaft = neueGruppen[index];
    if (aktuelleMitgliedschaft.externeHeldIds.contains(held.id)) return;
    neueGruppen[index] = aktuelleMitgliedschaft.copyWith(
      externeHeldIds: [...aktuelleMitgliedschaft.externeHeldIds, held.id],
    );
    await saveHero(aktuell.copyWith(gruppen: neueGruppen));
  }

  /// Entfernt einen externen Helden aus einer Gruppe.
  ///
  /// Manuelle Eintraege einer Konto-Gruppe werden fuer alle Mitglieder
  /// geloescht. Verknuepfte Mitglieder kehren beim naechsten Sync zurueck.
  Future<void> removeExternerHeld({
    required String heroId,
    required String gruppenCode,
    required String externerHeldId,
  }) async {
    final hero = await _loadHeroById(heroId);
    final mitgliedschaft = hero.gruppen
        .where((g) => g.gruppenCode == gruppenCode)
        .firstOrNull;
    if (mitgliedschaft == null) return;

    final extern = _ref
        .read(externeHeldenRepositoryProvider)
        .loadById(externerHeldId);
    if (mitgliedschaft.kontoGruppe && (extern?.istManuell ?? false)) {
      _requireGruppenSyncAvailable();
      await _ref
          .read(gruppenSyncServiceProvider)
          .entferneGeteiltenHeld(gruppenCode, externerHeldId);
    }

    final aktuell = await _loadHeroById(heroId);
    final neueGruppen = List<HeroGruppenMitgliedschaft>.from(aktuell.gruppen);
    final index = neueGruppen.indexWhere((g) => g.gruppenCode == gruppenCode);
    if (index < 0) return;
    neueGruppen[index] = neueGruppen[index].copyWith(
      externeHeldIds: neueGruppen[index].externeHeldIds
          .where((id) => id != externerHeldId)
          .toList(growable: false),
    );
    await saveHero(aktuell.copyWith(gruppen: neueGruppen));
  }

  /// Aktualisiert die eigene Visitenkarte in allen Konto-Gruppen des Helden.
  Future<void> syncVisitenkarten(String heroId) async {
    _requireGruppenSyncAvailable();
    final hero = await _loadHeroById(heroId);
    for (final gruppe in hero.gruppen.where((g) => g.kontoGruppe)) {
      await _pushEigeneVisitenkarte(
        heroId: heroId,
        gruppenCode: gruppe.gruppenCode,
      );
    }
  }

  /// Fuehrt einen vollstaendigen Sync fuer alle Konto-Gruppen des Helden durch:
  /// 1. Gruppenname auffrischen
  /// 2. Eigene Visitenkarte pushen
  /// 3. Mitglieder und gemeinsame Eintraege abholen; neuere lokale gemeinsame
  ///    Eintraege hochladen
  /// 4. Nicht mehr vorhandene Eintraege aus der Gruppe des Helden entfernen
  ///
  /// Altgruppen (gesperrter Legacy-Pfad) bleiben unberuehrt. Schlaegt eine
  /// Gruppe fehl, laufen die uebrigen weiter; der Fehler wird danach gesammelt
  /// gemeldet.
  Future<void> syncGruppen(String heroId) async {
    _requireGruppenSyncAvailable();
    final hero = await _loadHeroById(heroId);
    final fehler = <String>[];
    for (final gruppe in hero.gruppen.where((g) => g.kontoGruppe)) {
      try {
        await _syncGruppe(heroId, gruppe.gruppenCode);
      } on GruppenException catch (error) {
        final name = gruppe.gruppenName.isEmpty ? 'Gruppe' : gruppe.gruppenName;
        fehler.add(
          error.keinZugriff && !error.message.contains(name)
              ? '$name: Kein Zugriff mehr (nicht mehr Mitglied?)'
              : '$name: ${error.message}',
        );
      }
    }
    if (fehler.isNotEmpty) {
      throw GruppenException(fehler.join('\n'));
    }
  }

  /// Gleicht vor einem Gefecht die Konto-Gruppen des Helden ab, damit die
  /// externen Gefaehrten (INI, Werte) aktuell sind.
  ///
  /// Beste Anstrengung mit Zeitlimit: Das Gefecht darf nie an der Cloud
  /// scheitern. Gibt `null` zurueck, wenn nichts abzugleichen war oder alles
  /// gelang, sonst eine Warnung fuer die Oberflaeche.
  Future<String?> syncGruppenVorGefecht(
    String heroId, {
    Duration zeitlimit = const Duration(seconds: 8),
  }) async {
    if (!_ref.read(firebaseBootstrapProvider).isFirestoreAvailable) {
      return null;
    }
    try {
      final hero = await _loadHeroById(heroId);
      if (!hero.gruppen.any((g) => g.kontoGruppe)) {
        return null;
      }
      await syncGruppen(heroId).timeout(zeitlimit);
      return null;
    } on TimeoutException {
      return 'Der Gruppenabgleich dauerte zu lange.';
    } on Object catch (error) {
      return '$error';
    }
  }

  Future<void> _syncGruppe(String heroId, String gruppenCode) async {
    final syncService = _ref.read(gruppenSyncServiceProvider);
    final externeRepo = _ref.read(externeHeldenRepositoryProvider);

    final info = await syncService.ladeGruppe(gruppenCode);
    await _pushEigeneVisitenkarte(heroId: heroId, gruppenCode: gruppenCode);
    final inhalt = await syncService.ladeInhalt(gruppenCode);
    final eigeneUid = syncService.eigeneUid;

    final gesehen = <String>[];

    // Gemeinsame Eintraege: der neuere Stand gewinnt, in beide Richtungen.
    for (final karte in inhalt.geteilte) {
      final lokal = externeRepo.loadById(karte.heroId);
      if (lokal == null || lokal.updatedAt.isBefore(karte.exportedAt)) {
        await externeRepo.save(
          ExternerHeld.fromVisitenkarte(karte, id: karte.heroId),
        );
      } else if (lokal.updatedAt.isAfter(karte.exportedAt) &&
          lokal.istManuell) {
        await syncService.pushGeteilterHeld(
          gruppenCode,
          HeldVisitenkarte.fromExternerHeld(lokal),
        );
      }
      gesehen.add(karte.heroId);
    }

    // Heldenkarten der anderen Mitglieder.
    for (final mitglied in inhalt.mitglieder) {
      if (mitglied.uid == eigeneUid) continue;
      await externeRepo.save(ExternerHeld.fromVisitenkarte(mitglied.karte));
      gesehen.add(mitglied.karte.heroId);
    }

    // Frisch laden und nur die eigenen Felder aendern.
    final aktuell = await _loadHeroById(heroId);
    final neueGruppen = List<HeroGruppenMitgliedschaft>.from(aktuell.gruppen);
    final index = neueGruppen.indexWhere((g) => g.gruppenCode == gruppenCode);
    if (index < 0) return;
    final bisher = neueGruppen[index];
    final behalten = bisher.externeHeldIds.where(gesehen.contains).toList();
    final neueIds = <String>[
      ...behalten,
      for (final id in gesehen)
        if (!behalten.contains(id)) id,
    ];
    final idsGeaendert =
        neueIds.length != bisher.externeHeldIds.length ||
        !neueIds.every(bisher.externeHeldIds.contains);
    if (!idsGeaendert && info.name == bisher.gruppenName) return;
    neueGruppen[index] = bisher.copyWith(
      gruppenName: info.name,
      externeHeldIds: neueIds,
    );
    await saveHero(aktuell.copyWith(gruppen: neueGruppen));
  }

  // Haengt die Konto-Gruppe an den Helden, sofern er sie noch nicht kennt.
  Future<void> _traegeMitgliedschaftEin(String heroId, GruppenInfo info) async {
    final hero = await _loadHeroById(heroId);
    final neueGruppen = List<HeroGruppenMitgliedschaft>.from(hero.gruppen);
    final index = neueGruppen.indexWhere((g) => g.gruppenCode == info.groupId);
    if (index >= 0) {
      if (neueGruppen[index].kontoGruppe) return;
      neueGruppen[index] = neueGruppen[index].copyWith(
        kontoGruppe: true,
        gruppenName: info.name,
      );
    } else {
      neueGruppen.add(
        HeroGruppenMitgliedschaft(
          gruppenCode: info.groupId,
          gruppenName: info.name,
          kontoGruppe: true,
        ),
      );
    }
    await saveHero(hero.copyWith(gruppen: neueGruppen));
  }

  Future<void> _entferneMitgliedschaft(
    String heroId,
    String gruppenCode,
  ) async {
    final hero = await _loadHeroById(heroId);
    final neueGruppen = hero.gruppen
        .where((g) => g.gruppenCode != gruppenCode)
        .toList(growable: false);
    await saveHero(hero.copyWith(gruppen: neueGruppen));
  }

  // Die Mitgliedschaft steht bereits; ein Fehler hier heilt der naechste Sync.
  Future<void> _pushEigeneVisitenkarteBestEffort(
    String heroId,
    String gruppenCode,
  ) async {
    try {
      await _pushEigeneVisitenkarte(heroId: heroId, gruppenCode: gruppenCode);
    } on Exception {
      // Nicht abbrechen: Beitritt bzw. Erstellung sind erfolgt.
    }
  }

  static const String _altgruppeMeldung =
      'Diese Gruppe stammt aus dem alten, gesperrten Format. Bitte erstelle '
      'eine neue Gruppe und lade die Mitglieder erneut ein.';

  Future<void> _pushEigeneVisitenkarte({
    required String heroId,
    required String gruppenCode,
  }) async {
    _requireGruppenSyncAvailable();
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
    final entry = hero.appearance.aktivesBild;
    if (entry == null) return null;

    try {
      final heroStoragePath = await _resolveHeroStoragePath();
      final storage = _ref.read(avatarFileStorageProvider);
      final avatarBytes = await storage.loadGalleryImageBytes(
        heroStoragePath: heroStoragePath,
        fileName: entry.fileName,
      );
      if (avatarBytes == null) return null;

      // Der Befund kommt direkt vom Service statt ueber
      // `ref.read(avatarGesichtProvider(...).future)`: jene Future wird bei
      // einem Fehler nie erfuellt (siehe CLAUDE.md). Der Service wirft nie.
      final befund =
          gespeicherterGesichtsbefund(entry) ??
          await _ref
              .read(avatarGesichtServiceProvider)
              .befund(
                heroStoragePath: heroStoragePath,
                fileName: entry.fileName,
                bytes: avatarBytes,
              );
      final ausschnitt = befund == null
          ? null
          : berechneAvatarAusschnitt(
              bildBreite: befund.bildBreite,
              bildHoehe: befund.bildHoehe,
              seitenverhaeltnis: 1,
              rahmung: AvatarRahmung.portraet,
              gesicht: befund.gesicht,
            );

      final encoder = _ref.read(avatarThumbnailEncoderProvider);
      // `await` ist hier zwingend: ohne das laeuft eine Exception aus dem
      // Encoder am `on Exception`-Zweig vorbei und blockiert den Sync doch.
      return await encoder.createThumbnailBase64(
        imageBytes: avatarBytes,
        ausschnitt: ausschnitt == null
            ? null
            : (
                links: ausschnitt.links,
                oben: ausschnitt.oben,
                breite: ausschnitt.breite,
                hoehe: ausschnitt.hoehe,
              ),
      );
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

  /// Stellt sicher, dass optionale Cloud-Funktionen aktuell verfügbar sind.
  void _requireGruppenSyncAvailable() {
    final firebaseBootstrap = _ref.read(firebaseBootstrapProvider);
    if (firebaseBootstrap.isFirestoreAvailable) {
      return;
    }
    throw StateError(
      firebaseBootstrap.firestoreUserMessage ??
          firebaseBootstrap.userMessage ??
          'Gruppen-Sync ist derzeit nicht verfügbar.',
    );
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
