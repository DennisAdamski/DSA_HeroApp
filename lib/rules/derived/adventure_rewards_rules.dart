import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';

/// Ergebnis der Abschlusspruefung fuer Abenteuer-Belohnungen.
class AdventureRewardApplyCheck {
  /// Erzeugt ein unveraenderliches Pruefergebnis.
  const AdventureRewardApplyCheck({required this.isAllowed, this.reason = ''});

  /// Gibt an, ob der Abschluss aktuell fachlich erlaubt ist.
  final bool isAllowed;

  /// Erklaert die Sperre fuer die UI.
  final String reason;
}

/// Ergebnis der Ruecknahmepruefung fuer Abenteuer-Belohnungen.
class AdventureRewardRevokeCheck {
  /// Erzeugt ein unveraenderliches Pruefergebnis.
  const AdventureRewardRevokeCheck({required this.isAllowed, this.reason = ''});

  /// Gibt an, ob die Ruecknahme aktuell fachlich erlaubt ist.
  final bool isAllowed;

  /// Erklaert die Sperre fuer die UI.
  final String reason;
}

/// Prueft, ob ein Abenteuer mit den aktuell hinterlegten Abschlussdaten
/// abgeschlossen werden kann.
AdventureRewardApplyCheck canApplyAdventureRewards({
  required HeroSheet hero,
  required String adventureId,
}) {
  final adventureIndex = _findAdventureIndex(hero, adventureId);
  if (adventureIndex < 0) {
    return const AdventureRewardApplyCheck(
      isAllowed: false,
      reason: 'Abenteuer nicht gefunden.',
    );
  }

  final adventure = hero.adventures[adventureIndex];
  if (adventure.rewardsApplied) {
    return const AdventureRewardApplyCheck(
      isAllowed: false,
      reason: 'Das Abenteuer wurde bereits abgeschlossen.',
    );
  }

  if (_requiresNumericDukaten(adventure)) {
    final currentDukaten = _parseDukatenValue(hero.dukaten);
    if (currentDukaten == null) {
      return const AdventureRewardApplyCheck(
        isAllowed: false,
        reason: 'Der aktuelle Dukatenstand ist nicht numerisch lesbar.',
      );
    }
  }

  for (final loot in adventure.lootRewards.where((entry) => entry.hasContent)) {
    final sourceRef = _adventureLootRef(adventure.id, loot.id);
    final hasConflict = hero.inventoryEntries.any(
      (entry) => entry.sourceRef == sourceRef,
    );
    if (hasConflict) {
      return AdventureRewardApplyCheck(
        isAllowed: false,
        reason:
            'Für ${_lootLabel(loot)} existiert bereits ein Abschluss-Eintrag.',
      );
    }
  }

  return const AdventureRewardApplyCheck(isAllowed: true);
}

/// Wendet die Belohnungen eines Abenteuers einmalig auf den Helden an und
/// markiert das Abenteuer dabei als abgeschlossen.
HeroSheet applyAdventureRewards({
  required HeroSheet hero,
  required String adventureId,
}) {
  final check = canApplyAdventureRewards(hero: hero, adventureId: adventureId);
  if (!check.isAllowed) {
    return hero;
  }

  final adventureIndex = _findAdventureIndex(hero, adventureId);
  if (adventureIndex < 0) {
    return hero;
  }

  final adventure = hero.adventures[adventureIndex];
  var nextApTotal = hero.apTotal + _normalizeNonNegative(adventure.apReward);
  var nextTalents = Map<String, HeroTalentEntry>.of(hero.talents);
  var nextAttributeSePool = hero.attributeSePool;
  var nextStatSePool = hero.statSePool;
  final nextInventoryEntries = List<HeroInventoryEntry>.from(
    hero.inventoryEntries,
  );

  for (final reward in adventure.seRewards.where((entry) => entry.hasContent)) {
    switch (reward.targetType) {
      case HeroAdventureSeTargetType.talent:
        final entry = nextTalents[reward.targetId] ?? const HeroTalentEntry();
        nextTalents[reward.targetId] = entry.copyWith(
          specialExperiences: entry.specialExperiences + reward.count,
        );
        break;
      case HeroAdventureSeTargetType.grundwert:
        nextStatSePool = nextStatSePool.adjust(reward.targetId, reward.count);
        break;
      case HeroAdventureSeTargetType.eigenschaft:
        final code = parseAttributeCode(reward.targetId);
        if (code != null) {
          nextAttributeSePool = nextAttributeSePool.adjust(code, reward.count);
        }
        break;
    }
  }

  final currentDukaten = _parseDukatenValue(hero.dukaten) ?? 0;
  final nextDukaten =
      currentDukaten + _normalizeNonNegativeDukaten(adventure.dukatenReward);
  final nextDukatenValue = _requiresNumericDukaten(adventure)
      ? _formatDukatenValue(nextDukaten)
      : hero.dukaten;
  for (final loot in adventure.lootRewards.where((entry) => entry.hasContent)) {
    nextInventoryEntries.add(
      _buildAdventureLootInventoryEntry(adventure: adventure, loot: loot),
    );
  }

  final updatedAdventure = adventure.copyWith(
    status: HeroAdventureStatus.completed,
    rewardsApplied: true,
  );
  return hero.copyWith(
    apTotal: nextApTotal,
    dukaten: nextDukatenValue,
    talents: nextTalents,
    adventures: _replaceAdventureAt(
      hero.adventures,
      adventureIndex,
      updatedAdventure,
    ),
    attributeSePool: nextAttributeSePool,
    statSePool: nextStatSePool,
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(
      nextInventoryEntries,
    ),
  );
}

/// Prueft, ob die Belohnungen eines Abenteuers sicher zurueckgenommen werden
/// koennen.
AdventureRewardRevokeCheck canRevokeAdventureRewards({
  required HeroSheet hero,
  required String adventureId,
}) {
  final adventureIndex = _findAdventureIndex(hero, adventureId);
  if (adventureIndex < 0) {
    return const AdventureRewardRevokeCheck(
      isAllowed: false,
      reason: 'Abenteuer nicht gefunden.',
    );
  }

  final adventure = hero.adventures[adventureIndex];
  if (!adventure.rewardsApplied) {
    return const AdventureRewardRevokeCheck(
      isAllowed: false,
      reason: 'Belohnungen wurden noch nicht angewendet.',
    );
  }

  if (hero.apAvailable < _normalizeNonNegative(adventure.apReward)) {
    return const AdventureRewardRevokeCheck(
      isAllowed: false,
      reason: 'Die vergebenen AP wurden bereits ausgegeben.',
    );
  }

  for (final reward in adventure.seRewards.where((entry) => entry.hasContent)) {
    final label = _rewardLabel(reward);
    switch (reward.targetType) {
      case HeroAdventureSeTargetType.talent:
        final remaining =
            hero.talents[reward.targetId]?.specialExperiences ?? 0;
        if (remaining < reward.count) {
          return AdventureRewardRevokeCheck(
            isAllowed: false,
            reason: 'Die SE für $label wurden bereits verbraucht.',
          );
        }
        break;
      case HeroAdventureSeTargetType.grundwert:
        final remaining = hero.statSePool.valueFor(reward.targetId);
        if (remaining < reward.count) {
          return AdventureRewardRevokeCheck(
            isAllowed: false,
            reason: 'Die SE für $label wurden bereits verbraucht.',
          );
        }
        break;
      case HeroAdventureSeTargetType.eigenschaft:
        final code = parseAttributeCode(reward.targetId);
        final remaining = code == null
            ? 0
            : hero.attributeSePool.valueFor(code);
        if (remaining < reward.count) {
          return AdventureRewardRevokeCheck(
            isAllowed: false,
            reason: 'Die SE für $label wurden bereits verbraucht.',
          );
        }
        break;
    }
  }

  if (_requiresNumericDukaten(adventure)) {
    final currentDukaten = _parseDukatenValue(hero.dukaten);
    if (currentDukaten == null) {
      return const AdventureRewardRevokeCheck(
        isAllowed: false,
        reason: 'Der aktuelle Dukatenstand ist nicht numerisch lesbar.',
      );
    }
    if (currentDukaten <
        _normalizeNonNegativeDukaten(adventure.dukatenReward)) {
      return const AdventureRewardRevokeCheck(
        isAllowed: false,
        reason: 'Die vergebenen Dukaten sind nicht mehr vollständig vorhanden.',
      );
    }
  }

  for (final loot in adventure.lootRewards.where((entry) => entry.hasContent)) {
    final sourceRef = _adventureLootRef(adventure.id, loot.id);
    final exists = hero.inventoryEntries.any(
      (entry) => entry.sourceRef == sourceRef,
    );
    if (!exists) {
      return AdventureRewardRevokeCheck(
        isAllowed: false,
        reason:
            'Der Abschluss-Gegenstand ${_lootLabel(loot)} ist nicht mehr vollständig vorhanden.',
      );
    }
  }

  return const AdventureRewardRevokeCheck(isAllowed: true);
}

/// Nimmt die Belohnungen eines zuvor angewendeten Abenteuers zurueck und
/// oeffnet das Abenteuer wieder.
HeroSheet revokeAdventureRewards({
  required HeroSheet hero,
  required String adventureId,
}) {
  final check = canRevokeAdventureRewards(hero: hero, adventureId: adventureId);
  if (!check.isAllowed) {
    return hero;
  }

  final adventureIndex = _findAdventureIndex(hero, adventureId);
  if (adventureIndex < 0) {
    return hero;
  }

  final adventure = hero.adventures[adventureIndex];
  var nextApTotal = hero.apTotal - _normalizeNonNegative(adventure.apReward);
  if (nextApTotal < 0) {
    nextApTotal = 0;
  }
  var nextTalents = Map<String, HeroTalentEntry>.of(hero.talents);
  var nextAttributeSePool = hero.attributeSePool;
  var nextStatSePool = hero.statSePool;

  for (final reward in adventure.seRewards.where((entry) => entry.hasContent)) {
    switch (reward.targetType) {
      case HeroAdventureSeTargetType.talent:
        final current = nextTalents[reward.targetId];
        if (current == null) {
          break;
        }
        final nextSe = current.specialExperiences - reward.count;
        nextTalents[reward.targetId] = current.copyWith(
          specialExperiences: nextSe < 0 ? 0 : nextSe,
        );
        break;
      case HeroAdventureSeTargetType.grundwert:
        nextStatSePool = nextStatSePool.adjust(reward.targetId, -reward.count);
        break;
      case HeroAdventureSeTargetType.eigenschaft:
        final code = parseAttributeCode(reward.targetId);
        if (code != null) {
          nextAttributeSePool = nextAttributeSePool.adjust(code, -reward.count);
        }
        break;
    }
  }

  final currentDukaten = _parseDukatenValue(hero.dukaten) ?? 0;
  final nextDukaten =
      currentDukaten - _normalizeNonNegativeDukaten(adventure.dukatenReward);
  final nextDukatenValue = _requiresNumericDukaten(adventure)
      ? _formatDukatenValue(nextDukaten < 0 ? 0 : nextDukaten)
      : hero.dukaten;
  final removalRefs = adventure.lootRewards
      .where((entry) => entry.hasContent)
      .map((entry) => _adventureLootRef(adventure.id, entry.id))
      .toSet();
  final nextInventoryEntries = hero.inventoryEntries
      .where((entry) => !removalRefs.contains(entry.sourceRef))
      .toList(growable: false);

  final updatedAdventure = adventure.copyWith(
    status: HeroAdventureStatus.current,
    endWorldDate: const HeroAdventureDateValue(),
    endAventurianDate: const HeroAdventureDateValue(),
    rewardsApplied: false,
  );
  return hero.copyWith(
    apTotal: nextApTotal,
    dukaten: nextDukatenValue,
    talents: nextTalents,
    adventures: _replaceAdventureAt(
      hero.adventures,
      adventureIndex,
      updatedAdventure,
    ),
    attributeSePool: nextAttributeSePool,
    statSePool: nextStatSePool,
    inventoryEntries: nextInventoryEntries,
  );
}

/// Entfernt Abenteuer-Referenzen aus Kontakten, die nicht mehr gueltig sind.
List<HeroConnectionEntry> cleanupAdventureReferences({
  required List<HeroConnectionEntry> connections,
  required Iterable<String> validAdventureIds,
}) {
  final validIds = validAdventureIds
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet();

  return connections
      .map((entry) {
        final reference = entry.adventureId.trim();
        if (reference.isEmpty || validIds.contains(reference)) {
          return entry;
        }
        return entry.copyWith(adventureId: '');
      })
      .toList(growable: false);
}

int _findAdventureIndex(HeroSheet hero, String adventureId) {
  return hero.adventures.indexWhere((entry) => entry.id == adventureId);
}

List<HeroAdventureEntry> _replaceAdventureAt(
  List<HeroAdventureEntry> adventures,
  int index,
  HeroAdventureEntry adventure,
) {
  final next = List<HeroAdventureEntry>.from(adventures);
  next[index] = adventure;
  return List<HeroAdventureEntry>.unmodifiable(next);
}

HeroInventoryEntry _buildAdventureLootInventoryEntry({
  required HeroAdventureEntry adventure,
  required HeroAdventureLootEntry loot,
}) {
  final title = adventure.title.trim();
  final herkunft = loot.origin.trim();
  final adventureLabel = title.isEmpty ? adventure.id : title;
  final effectiveOrigin = herkunft.isEmpty
      ? 'Abenteuer: $adventureLabel'
      : herkunft;
  return HeroInventoryEntry(
    gegenstand: loot.name.trim(),
    anzahl: loot.quantity.trim(),
    welchesAbenteuer: adventureLabel,
    itemType: loot.itemType,
    source: InventoryItemSource.abenteuer,
    sourceRef: _adventureLootRef(adventure.id, loot.id),
    gewichtGramm: _normalizeNonNegative(loot.weightGramm),
    wertSilber: _normalizeNonNegative(loot.valueSilver),
    herkunft: effectiveOrigin,
    beschreibung: loot.description.trim(),
  );
}

String _adventureLootRef(String adventureId, String lootId) {
  return 'adv:${adventureId.trim()}|loot:${lootId.trim()}';
}

String _rewardLabel(HeroAdventureSeReward reward) {
  final label = reward.targetLabel.trim();
  if (label.isNotEmpty) {
    return label;
  }
  return reward.targetId.trim().isEmpty ? 'dem Zielwert' : reward.targetId;
}

String _lootLabel(HeroAdventureLootEntry loot) {
  final label = loot.name.trim();
  return label.isEmpty ? 'der Gegenstand' : label;
}

bool _requiresNumericDukaten(HeroAdventureEntry adventure) {
  return _normalizeNonNegativeDukaten(adventure.dukatenReward) > 0;
}

double? _parseDukatenValue(String rawValue) {
  final kreuzer = parseDsaCurrencyToKreuzer(rawValue);
  if (kreuzer == null) {
    return null;
  }
  return kreuzer / dsaKreuzerPerDukat;
}

String _formatDukatenValue(double value) {
  return formatDsaCurrencyDukaten(dukatenToDsaKreuzer(value));
}

int _normalizeNonNegative(int value) {
  return value < 0 ? 0 : value;
}

double _normalizeNonNegativeDukaten(double value) {
  return value < 0 ? 0 : value;
}
