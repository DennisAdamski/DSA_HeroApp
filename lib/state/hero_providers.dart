import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_index_snapshot.dart';

/// Repository-Abstraktion (wird beim App-Start ueberschrieben).
final heroRepositoryProvider = Provider<HeroRepository>((ref) {
  throw UnimplementedError(
    'HeroRepository muss beim App-Start uebersteuert werden.',
  );
});

/// Codec fuer Transfer-JSON (Import/Export).
final heroTransferCodecProvider = Provider<HeroTransferCodec>((ref) {
  return const HeroTransferCodec();
});

/// Plattformabhaengiger Dateigateway fuer Transferdateien.
final heroTransferFileGatewayProvider = Provider<HeroTransferFileGateway>((
  ref,
) {
  return createHeroTransferFileGateway();
});

final selectedHeroIdProvider = StateProvider<String?>((ref) => null);
final talentBeOverrideProvider = StateProvider.family<int?, String>(
  (ref, heroId) => null,
);

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

      final parsed = parseModifierTextsForHero(hero);
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
        parsedModifiers: parsed,
        effectiveAttributes: effective,
        derivedStats: derived,
      );

      return AsyncValue<HeroComputedSnapshot>.data(
        HeroComputedSnapshot(
          hero: hero,
          state: state,
          modifierParse: parsed,
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

final heroActionsProvider = Provider<HeroActions>((ref) => HeroActions(ref));

enum ImportConflictResolution { overwriteExisting, createNewHero }

/// Schreiboperationen und Import/Export-Orchestrierung fuer Helden.
class HeroActions {
  HeroActions(this._ref);

  final Ref _ref;

  Future<String> createHero() async {
    final repo = _ref.read(heroRepositoryProvider);
    const uuid = Uuid();
    final id = uuid.v4();
    final hero = HeroSheet(
      id: id,
      name: 'Neuer Held',
      level: 1,
      attributes: const Attributes(
        mu: 8,
        kl: 8,
        inn: 8,
        ch: 8,
        ff: 8,
        ge: 8,
        ko: 8,
        kk: 8,
      ),
    );
    await repo.saveHero(hero);
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

    final normalizedHero = hero.copyWith(
      apTotal: normalizedApTotal,
      apSpent: normalizedApSpent,
      apAvailable: calculatedAvailable,
      level: calculatedLevel,
      unknownModifierFragments: parsed.unknownFragments,
    );

    await repo.saveHero(normalizedHero);
  }

  Future<void> saveHeroState(String heroId, HeroState state) async {
    final repo = _ref.read(heroRepositoryProvider);
    await repo.saveHeroState(heroId, state);
  }

  Future<void> deleteHero(String heroId) async {
    final repo = _ref.read(heroRepositoryProvider);
    await repo.deleteHero(heroId);
    final selected = _ref.read(selectedHeroIdProvider);
    if (selected == heroId) {
      _ref.read(selectedHeroIdProvider.notifier).state = null;
    }
  }

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

  Future<HeroTransferBundle> parseImportJson(String rawJson) async {
    final codec = _ref.read(heroTransferCodecProvider);
    return codec.decode(rawJson);
  }

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

  Future<HeroSheet> _loadHeroById(String heroId) async {
    final repo = _ref.read(heroRepositoryProvider);
    final hero = await repo.loadHeroById(heroId);
    if (hero != null) {
      return hero;
    }
    throw StateError('Held mit ID "$heroId" wurde nicht gefunden.');
  }
}
