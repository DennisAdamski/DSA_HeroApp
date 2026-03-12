import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';

/// Zusammengefasste Effekte aktiver waffenloser Kampfstile.
class UnarmedStyleEffects {
  const UnarmedStyleEffects({
    this.atBonus = 0,
    this.paBonus = 0,
    this.iniMod = 0,
    this.activatedManeuverIds = const <String>[],
  });

  final int atBonus;
  final int paBonus;
  final int iniMod;
  final List<String> activatedManeuverIds;
}

/// Leitet aus aktiven waffenlosen Kampfstilen direkte Kampfwerte und Manöver ab.
///
/// Es werden nur fest definierte Zahlenboni und Freischaltungen berücksichtigt.
/// Der kombinierte AT/PA-Bonus aller aktiven Stile ist jeweils auf +2 begrenzt.
UnarmedStyleEffects computeActiveUnarmedStyleEffects({
  required CombatSpecialRules specialRules,
  required List<CombatSpecialAbilityDef> catalogCombatSpecialAbilities,
  required List<ManeuverDef> catalogManeuvers,
  required String activeTalentName,
}) {
  final normalizedTalent = _normalizeStyleTalent(activeTalentName);
  final activeIds = specialRules.activeCombatSpecialAbilityIds.toSet();
  final normalizedManeuvers = <String>{};
  var atBonus = 0;
  var paBonus = 0;
  var iniMod = 0;

  for (final ability in catalogCombatSpecialAbilities) {
    if (!ability.isUnarmedCombatStyle || !activeIds.contains(ability.id)) {
      continue;
    }
    for (final maneuverId in ability.aktiviertManoeverIds) {
      final id = canonicalizeManeuverId(
        maneuverId,
        catalogManeuvers: catalogManeuvers,
      );
      if (id.isNotEmpty) {
        normalizedManeuvers.add(id);
      }
    }
    for (final bonus in ability.kampfwertBoni) {
      if (!_bonusAppliesToTalent(
        bonus.giltFuerTalent,
        normalizedTalent,
        specialRules.gladiatorStyleTalent,
      )) {
        continue;
      }
      atBonus += bonus.atBonus;
      paBonus += bonus.paBonus;
      iniMod += bonus.iniMod;
    }
  }

  return UnarmedStyleEffects(
    atBonus: atBonus.clamp(0, 2),
    paBonus: paBonus.clamp(0, 2),
    iniMod: iniMod,
    activatedManeuverIds: normalizedManeuvers.toList(growable: false),
  );
}

/// Normalisiert eine Manöver-ID oder einen Manövernamen auf die stabile Katalog-ID.
String canonicalizeManeuverId(
  String raw, {
  required List<ManeuverDef> catalogManeuvers,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  for (final maneuver in catalogManeuvers) {
    if (maneuver.id == trimmed) {
      return trimmed;
    }
  }
  final normalizedRaw = _normalizeToken(trimmed);
  for (final maneuver in catalogManeuvers) {
    if (_normalizeToken(maneuver.name) == normalizedRaw) {
      return maneuver.id;
    }
  }
  return '';
}

bool _bonusAppliesToTalent(
  String rawBonusTalent,
  String normalizedActiveTalent,
  String gladiatorStyleTalent,
) {
  final normalizedBonusTalent = _normalizeStyleTalent(rawBonusTalent);
  if (normalizedBonusTalent.isEmpty) {
    return false;
  }
  if (normalizedBonusTalent == 'beide') {
    return normalizedActiveTalent == 'raufen' ||
        normalizedActiveTalent == 'ringen';
  }
  if (normalizedBonusTalent == 'wahl') {
    return normalizedActiveTalent.isNotEmpty &&
        normalizedActiveTalent == _normalizeStyleTalent(gladiatorStyleTalent);
  }
  return normalizedBonusTalent == normalizedActiveTalent;
}

String _normalizeStyleTalent(String raw) {
  final normalized = _normalizeToken(raw);
  if (normalized == 'raufen' ||
      normalized == 'ringen' ||
      normalized == 'beide') {
    return normalized;
  }
  if (normalized == 'wahl') {
    return 'wahl';
  }
  return '';
}

String _normalizeToken(String raw) {
  var value = raw.trim().toLowerCase();
  value = value
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
