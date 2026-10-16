// Gemeinsame Hilfsfunktionen fuer die Kampf-Subtab-Widgets.

// Talent- und Waffenartauflösung liegen als Regel bei der Slotprüfung
// (ARCH-05); die Widgets beziehen sie weiter über diese Datei.
export 'package:dsa_heldenverwaltung/rules/derived/kampf_slot_pruefung_rules.dart'
    show
        combatTypeFromTalent,
        normalizeToken,
        parseWeaponCategoryValues,
        weaponTypeOptionsForTalent;

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_stat_inputs.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_slot_pruefung_rules.dart';
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
