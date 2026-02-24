import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import '../rules/derived/modifier_parser.dart';

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

final _heroesRevisionProvider = StateProvider<int>((ref) => 0);
final selectedHeroIdProvider = StateProvider<String?>((ref) => null);

/// Reaktive Heldenliste aus dem Repository.
final heroListProvider = FutureProvider<List<HeroSheet>>((ref) async {
  ref.watch(_heroesRevisionProvider);
  final repo = ref.watch(heroRepositoryProvider);
  return repo.listHeroes();
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
  final heroes = ref.watch(heroListProvider).valueOrNull ?? const <HeroSheet>[];
  return findHeroById(heroes, heroId);
});

/// Asynchrone Variante von `heroByIdProvider`.
final heroByIdFutureProvider = FutureProvider.family<HeroSheet?, String>((
  ref,
  heroId,
) async {
  final heroes = await ref.watch(heroListProvider.future);
  return findHeroById(heroes, heroId);
});

/// Ausgewaehlter Held fuer die Startansicht.
final selectedHeroProvider = Provider<HeroSheet?>((ref) {
  final heroes = ref.watch(heroListProvider).valueOrNull ?? const <HeroSheet>[];
  final selectedId = ref.watch(selectedHeroIdProvider);
  if (selectedId == null) {
    return heroes.isEmpty ? null : heroes.first;
  }
  return findHeroById(heroes, selectedId) ?? (heroes.isEmpty ? null : heroes.first);
});

/// Laufzeitzustand (Ressourcen, temp. Modifikatoren) je Held.
final heroStateProvider = FutureProvider.family<HeroState, String>((
  ref,
  heroId,
) async {
  final repo = ref.watch(heroRepositoryProvider);
  return (await repo.loadHeroState(heroId)) ?? const HeroState.empty();
});

/// Abgeleitete Werte je Held, berechnet aus Sheet + State.
final derivedStatsProvider = FutureProvider.family<DerivedStats, String>((
  ref,
  heroId,
) async {
  final hero = await ref.watch(heroByIdFutureProvider(heroId).future);
  if (hero == null) {
    throw StateError('Held mit ID "$heroId" wurde nicht gefunden.');
  }
  final state = await ref.watch(heroStateProvider(heroId).future);
  return computeDerivedStats(hero, state);
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
    _invalidateHeroes();
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
    _invalidateHeroes();
  }

  Future<void> saveHeroState(String heroId, HeroState state) async {
    final repo = _ref.read(heroRepositoryProvider);
    await repo.saveHeroState(heroId, state);
    _ref.invalidate(heroStateProvider(heroId));
    _ref.invalidate(derivedStatsProvider(heroId));
  }

  Future<void> deleteHero(String heroId) async {
    final repo = _ref.read(heroRepositoryProvider);
    await repo.deleteHero(heroId);
    final selected = _ref.read(selectedHeroIdProvider);
    if (selected == heroId) {
      _ref.read(selectedHeroIdProvider.notifier).state = null;
    }
    _invalidateHeroes();
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
    final heroes = await repo.listHeroes();
    for (final hero in heroes) {
      if (hero.id == heroId) {
        return hero;
      }
    }
    throw StateError('Held mit ID "$heroId" wurde nicht gefunden.');
  }

  void _invalidateHeroes() {
    _ref.read(_heroesRevisionProvider.notifier).state++;
    _ref.invalidate(heroListProvider);
  }
}
