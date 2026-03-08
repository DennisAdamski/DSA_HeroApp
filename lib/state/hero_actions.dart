import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';

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
  /// leeren [HeroState]. Die effektiven Startwerte werden aus Herkunftsmods
  /// normalisiert gespeichert. Gibt die neue ID zurueck.
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
      unknownModifierFragments: parsed.unknownFragments,
    );

    await repo.saveHero(normalizedHero);
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
    final bundle = HeroTransferBundle(
      exportedAt: DateTime.now().toUtc(),
      hero: hero,
      state: state,
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
    _ref.read(selectedHeroIdProvider.notifier).state = heroId;
    return heroId;
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
