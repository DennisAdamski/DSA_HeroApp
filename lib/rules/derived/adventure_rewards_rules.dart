import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

/// Ergebnis der Ruecknahmepruefung fuer Abenteuer-Belohnungen.
class AdventureRewardRevokeCheck {
  /// Erzeugt ein unveraenderliches Pruefergebnis.
  const AdventureRewardRevokeCheck({required this.isAllowed, this.reason = ''});

  /// Gibt an, ob die Ruecknahme aktuell fachlich erlaubt ist.
  final bool isAllowed;

  /// Erklaert die Sperre fuer die UI.
  final String reason;
}

/// Wendet die Belohnungen eines Abenteuers einmalig auf den Helden an.
HeroSheet applyAdventureRewards({
  required HeroSheet hero,
  required String adventureId,
}) {
  final adventureIndex = _findAdventureIndex(hero, adventureId);
  if (adventureIndex < 0) {
    return hero;
  }

  final adventure = hero.adventures[adventureIndex];
  if (adventure.rewardsApplied) {
    return hero;
  }

  var nextApTotal = hero.apTotal + _normalizeNonNegative(adventure.apReward);
  var nextTalents = Map<String, HeroTalentEntry>.of(hero.talents);
  var nextAttributeSePool = hero.attributeSePool;
  var nextStatSePool = hero.statSePool;

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

  final updatedAdventure = adventure.copyWith(rewardsApplied: true);
  return hero.copyWith(
    apTotal: nextApTotal,
    talents: nextTalents,
    adventures: _replaceAdventureAt(
      hero.adventures,
      adventureIndex,
      updatedAdventure,
    ),
    attributeSePool: nextAttributeSePool,
    statSePool: nextStatSePool,
  );
}

/// Prueft, ob die Belohnungen eines Abenteuers sicher zurueckgenommen werden koennen.
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

  return const AdventureRewardRevokeCheck(isAllowed: true);
}

/// Nimmt die Belohnungen eines zuvor angewendeten Abenteuers zurueck.
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

  final updatedAdventure = adventure.copyWith(rewardsApplied: false);
  return hero.copyWith(
    apTotal: nextApTotal,
    talents: nextTalents,
    adventures: _replaceAdventureAt(
      hero.adventures,
      adventureIndex,
      updatedAdventure,
    ),
    attributeSePool: nextAttributeSePool,
    statSePool: nextStatSePool,
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

String _rewardLabel(HeroAdventureSeReward reward) {
  final label = reward.targetLabel.trim();
  if (label.isNotEmpty) {
    return label;
  }
  return reward.targetId.trim().isEmpty ? 'dem Zielwert' : reward.targetId;
}

int _normalizeNonNegative(int value) {
  return value < 0 ? 0 : value;
}
