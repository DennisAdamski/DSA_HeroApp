// Gemeinsame Hilfsfunktionen fuer die Kampf-Subtab-Widgets.
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_stat_inputs.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

/// Kampfvorschau des Kampf-Tabs mit denselben Eingaben wie Inspector und
/// Spielansicht.
///
/// Modifikatoren, effektive Eigenschaften, Basiswerte und Wunden kommen aus
/// [berechnet], dem Snapshot des gespeicherten Helden
/// (`heroComputedProvider`). Ohne sie fehlten die Wunden in AT, PA, FK und
/// INI. Entwurfswerte des Tabs wirken über [overrideConfig] und
/// [overrideTalents]. Liegt noch kein Snapshot vor, werden dieselben
/// Eingaben aus [hero] und [state] berechnet.
CombatPreviewStats kampfvorschau({
  required HeroSheet hero,
  required HeroState state,
  required HeroComputedSnapshot? berechnet,
  required RulesCatalog catalog,
  required CombatConfig overrideConfig,
  required Map<String, HeroTalentEntry> overrideTalents,
  required bool epicAdvantagesRuleActive,
}) {
  final eingaben = berechnet == null
      ? computeHeroStatInputs(
          hero: hero,
          state: state,
          talents: catalog.talents,
          epicAdvantagesActive: epicAdvantagesRuleActive,
          catalog: catalog,
        )
      : null;
  return computeCombatPreviewStats(
    hero,
    state,
    overrideConfig: overrideConfig,
    overrideTalents: overrideTalents,
    catalogTalents: catalog.talents,
    catalogManeuvers: catalog.maneuvers,
    catalogCombatSpecialAbilities: catalog.combatSpecialAbilities,
    parsedModifiers: berechnet?.modifierParse ?? eingaben!.parsed,
    effectiveAttributes: berechnet?.effectiveAttributes ?? eingaben!.effective,
    derivedStats: berechnet?.derivedStats ?? eingaben!.derive(hero, state),
    wunden: berechnet?.wundEffekte ?? eingaben!.wounds,
    epicAdvantagesRuleActive: epicAdvantagesRuleActive,
    catalog: catalog,
  );
}

/// Gibt den deutschen Anzeige-Label fuer einen Waffenkampftyp zurueck.
String combatTypeLabel(WeaponCombatType combatType) {
  return combatType == WeaponCombatType.ranged ? 'Fernkampf' : 'Nahkampf';
}

/// Leitet den Kampftyp eines Talents aus seinem `type`-Feld ab.
WeaponCombatType combatTypeFromTalent(TalentDef talent) {
  return talent.type.trim().toLowerCase() == 'fernkampf'
      ? WeaponCombatType.ranged
      : WeaponCombatType.melee;
}

/// Sortiert eine Liste von Kampftalenten alphabetisch nach Name.
List<TalentDef> sortedCombatTalents(List<TalentDef> combatTalents) {
  final talents = List<TalentDef>.from(combatTalents, growable: false)
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return talents;
}

/// Sortiert und filtert Kampftalente nach Kampftyp.
List<TalentDef> sortedCombatTalentsForType(
  List<TalentDef> combatTalents,
  WeaponCombatType combatType,
) {
  return sortedCombatTalents(combatTalents)
      .where((talent) => combatTypeFromTalent(talent) == combatType)
      .toList(growable: false);
}

/// Findet ein Talent anhand seiner ID in einer Liste.
TalentDef? findTalentById(List<TalentDef> talents, String talentId) {
  final trimmed = talentId.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  for (final talent in talents) {
    if (talent.id == trimmed) {
      return talent;
    }
  }
  return null;
}

/// Normalisiert einen String-Token fuer case-insensitiven Vergleich.
String normalizeToken(String raw) {
  var value = raw.trim().toLowerCase();
  value = value
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

/// Parst Waffen-Kategorien aus einem mehrzeiligen String.
List<String> parseWeaponCategoryValues(String raw) {
  final seen = <String>{};
  final values = <String>[];
  for (final token in raw.split(RegExp(r'[\n,;]+'))) {
    final trimmed = token.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    values.add(trimmed);
  }
  return values;
}

/// Gibt die Waffenart-Optionen fuer ein Talent zurueck.
List<String> weaponTypeOptionsForTalent({
  required TalentDef? talent,
  required RulesCatalog catalog,
  required WeaponCombatType combatType,
}) {
  if (talent == null) {
    return const <String>[];
  }
  final seen = <String>{};
  final options = <String>[];
  final talentNameToken = normalizeToken(talent.name);
  for (final weapon in catalog.weapons) {
    if (weaponCombatTypeFromJson(weapon.type) != combatType) {
      continue;
    }
    if (normalizeToken(weapon.combatSkill) != talentNameToken) {
      continue;
    }
    final name = weapon.name.trim();
    if (name.isEmpty || seen.contains(name)) {
      continue;
    }
    seen.add(name);
    options.add(name);
  }
  for (final fallback in parseWeaponCategoryValues(talent.weaponCategory)) {
    if (seen.contains(fallback)) {
      continue;
    }
    seen.add(fallback);
    options.add(fallback);
  }
  options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return options;
}

/// Findet die Talent-ID zu einem Kampftalent-Namen aus dem Katalog.
String findTalentIdByName(
  String combatSkillName,
  List<TalentDef> combatTalents,
) {
  final needle = normalizeToken(combatSkillName);
  if (needle.isEmpty) {
    return '';
  }
  for (final talent in combatTalents) {
    if (normalizeToken(talent.name) == needle) {
      return talent.id;
    }
  }
  return '';
}

/// Gibt den deutschen Anzeige-Label fuer eine Schildgroesse zurueck.
String shieldSizeLabel(ShieldSize size) {
  return switch (size) {
    ShieldSize.small => 'Klein',
    ShieldSize.large => 'Groß',
    ShieldSize.veryLarge => 'Sehr groß',
  };
}
