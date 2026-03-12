// Re-Export fuer Rueckwaertskompatibilitaet: Alle Typen und Provider sind
// weiterhin durch Import dieser Datei erreichbar.
export 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
export 'package:dsa_heldenverwaltung/state/hero_actions.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_actions.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_index_snapshot.dart';

/// Temporaerer BE-Ueberschreibungswert fuer die Talentansicht je Held.
///
/// Wird vom Nutzer manuell gesetzt und uebersteuert den berechneten BE-Wert.
final talentBeOverrideProvider = StateProvider.family<int?, String>(
  (ref, heroId) => null,
);

/// Sichtbarkeitsmodus fuer ausgeblendete Talente je Held.
///
/// `true` bedeutet, alle Talente werden angezeigt (inklusive ausgeblendeter).
final talentsVisibilityModeProvider = StateProvider.family<bool, String>(
  (ref, heroId) => false,
);

/// Sichtbarkeitsmodus fuer Kampftalente je Held.
///
/// `true` bedeutet, alle Kampftalente werden angezeigt.
final combatTalentsVisibilityModeProvider = StateProvider.family<bool, String>(
  (ref, heroId) => false,
);

/// Sichtbarkeitsmodus fuer Kampftechniken je Held.
///
/// `true` bedeutet, alle Kampftechniken werden angezeigt.
final combatTechniquesVisibilityModeProvider =
    StateProvider.family<bool, String>((ref, heroId) => false);

/// Reaktiver, stream-basierter Heldenindex fuer O(1)-Lookup nach ID.
final heroIndexProvider = StreamProvider<HeroIndexSnapshot>((ref) {
  final repo = ref.watch(heroRepositoryProvider);
  return repo.watchHeroIndex().map(HeroIndexSnapshot.fromMap);
});

/// Reaktive Heldenliste aus dem sortierten Index.
final heroListProvider = StreamProvider<List<HeroSheet>>((ref) {
  final repo = ref.watch(heroRepositoryProvider);
  return repo.watchHeroIndex().map(
    (index) => HeroIndexSnapshot.fromMap(index).heroes,
  );
});

/// Sucht einen Helden in einer bereits geladenen Liste ueber seine ID.
///
/// Gibt `null` zurueck wenn kein Held mit [heroId] gefunden wird.
HeroSheet? findHeroById(List<HeroSheet> heroes, String heroId) {
  for (final hero in heroes) {
    if (hero.id == heroId) {
      return hero;
    }
  }
  return null;
}

/// Schneller Zugriff auf den aktuell geladenen Helden je ID.
final heroByIdProvider = Provider.family<HeroSheet?, String>((ref, heroId) {
  final snapshot = ref.watch(heroIndexProvider).valueOrNull;
  if (snapshot != null) {
    return snapshot.byId[heroId];
  }
  final heroes = ref.watch(heroListProvider).valueOrNull ?? const <HeroSheet>[];
  return findHeroById(heroes, heroId);
});

/// Asynchrone Variante fuer direkten Repository-Zugriff je ID.
final heroByIdFutureProvider = FutureProvider.family<HeroSheet?, String>((
  ref,
  heroId,
) async {
  final repo = ref.watch(heroRepositoryProvider);
  return repo.loadHeroById(heroId);
});

/// Ausgewaehlter Held fuer die Startansicht.
///
/// Faellt auf den ersten Helden im Index zurueck, wenn keine Auswahl gesetzt.
final selectedHeroProvider = Provider<HeroSheet?>((ref) {
  final snapshot = ref.watch(heroIndexProvider).valueOrNull;
  if (snapshot == null || snapshot.sortedIds.isEmpty) {
    return null;
  }
  final selectedId = ref.watch(selectedHeroIdProvider);
  if (selectedId == null) {
    return snapshot.byId[snapshot.sortedIds.first];
  }
  return snapshot.byId[selectedId] ?? snapshot.byId[snapshot.sortedIds.first];
});

/// Laufzeitzustand (Ressourcen, temp. Modifikatoren) je Held.
final heroStateProvider = StreamProvider.family<HeroState, String>((
  ref,
  heroId,
) {
  final repo = ref.watch(heroRepositoryProvider);
  return repo.watchHeroState(heroId);
});

/// Zentraler Compute-Snapshot fuer alle abgeleiteten Werte.
///
/// Kombiniert Sheet, State, Modifikatoren, effektive Attribute, abgeleitete
/// Werte und Kampfvorschau zu einem unveraenderlichen Snapshot.
final heroComputedProvider =
    Provider.family<AsyncValue<HeroComputedSnapshot>, String>((ref, heroId) {
      final hero = ref.watch(heroByIdProvider(heroId));
      if (hero == null) {
        return AsyncValue<HeroComputedSnapshot>.error(
          StateError('Held mit ID "$heroId" wurde nicht gefunden.'),
          StackTrace.current,
        );
      }

      final stateAsync = ref.watch(heroStateProvider(heroId));
      if (stateAsync.hasError) {
        return AsyncValue<HeroComputedSnapshot>.error(
          stateAsync.error!,
          stateAsync.stackTrace ?? StackTrace.current,
        );
      }

      final state = stateAsync.valueOrNull;
      if (state == null) {
        return const AsyncValue<HeroComputedSnapshot>.loading();
      }
      final catalogTalents =
          ref.watch(rulesCatalogProvider).valueOrNull?.talents ??
          const <TalentDef>[];
      final catalogManeuvers =
          ref.watch(rulesCatalogProvider).valueOrNull?.maneuvers ??
          const <ManeuverDef>[];
      final catalogCombatSpecialAbilities =
          ref.watch(rulesCatalogProvider).valueOrNull?.combatSpecialAbilities ??
          const <CombatSpecialAbilityDef>[];

      final parsed = parseModifierTextsForHero(hero);
      final effectiveStartAttributes = computeEffectiveStartAttributes(
        hero.rawStartAttributes,
        parseOriginAttributeModifiers(hero),
      );
      final attributeMaximums = computeAttributeMaximums(
        effectiveStartAttributes,
      );
      final effective = applyAttributeModifiers(
        hero.attributes,
        parsed.attributeMods + state.tempAttributeMods,
      );
      final derived = computeDerivedStatsFromInputs(
        sheet: hero,
        state: state,
        parsedModifiers: parsed,
        effectiveAttributes: effective,
      );
      final combat = computeCombatPreviewStats(
        hero,
        state,
        catalogTalents: catalogTalents,
        catalogManeuvers: catalogManeuvers,
        catalogCombatSpecialAbilities: catalogCombatSpecialAbilities,
        parsedModifiers: parsed,
        effectiveAttributes: effective,
        derivedStats: derived,
      );

      return AsyncValue<HeroComputedSnapshot>.data(
        HeroComputedSnapshot(
          hero: hero,
          state: state,
          modifierParse: parsed,
          effectiveStartAttributes: effectiveStartAttributes,
          attributeMaximums: attributeMaximums,
          effectiveAttributes: effective,
          derivedStats: derived,
          combatPreviewStats: combat,
        ),
      );
    });

/// Effektive Eigenschaften inklusive Text- und Zustand-Modifikatoren.
final effectiveAttributesProvider =
    Provider.family<AsyncValue<Attributes>, String>((ref, heroId) {
      final computedAsync = ref.watch(heroComputedProvider(heroId));
      return computedAsync.whenData((snapshot) => snapshot.effectiveAttributes);
    });

/// Abgeleitete Werte je Held, berechnet aus Sheet + State.
final derivedStatsProvider = Provider.family<AsyncValue<DerivedStats>, String>((
  ref,
  heroId,
) {
  final computedAsync = ref.watch(heroComputedProvider(heroId));
  return computedAsync.whenData((snapshot) => snapshot.derivedStats);
});

/// Kampfvorschau je Held auf Basis des zentralen Compute-Snapshots.
final combatPreviewProvider =
    Provider.family<AsyncValue<CombatPreviewStats>, String>((ref, heroId) {
      final computedAsync = ref.watch(heroComputedProvider(heroId));
      return computedAsync.whenData((snapshot) => snapshot.combatPreviewStats);
    });

/// Provider fuer alle schreibenden Heldenoperationen und Import/Export.
///
/// Gibt eine [HeroActions]-Instanz zurueck, die ueber `ref.read` bezogen wird.
final heroActionsProvider = Provider<HeroActions>((ref) => HeroActions(ref));
