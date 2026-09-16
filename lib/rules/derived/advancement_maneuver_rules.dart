import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

import 'advancement_options.dart';
import 'cost_text_parsing.dart';
import 'requirement_evaluation_rules.dart';

/// Listet getrennt lernbare Manöver pro vorhandenem, aktivem Kampftalent auf.
List<String> advancementManeuverTargets(HeroSheet hero, RulesCatalog catalog) {
  final targets = <String>[];
  for (final def in catalog.maneuvers) {
    final talents = _eligibleTalents(hero, catalog, def);
    if (!def.mussSeparatErlerntWerden || talents.isEmpty) {
      targets.add(def.id);
    } else {
      targets.addAll(talents.map((talent) => '${def.id}::${talent.id}'));
    }
  }
  return targets;
}

/// Erkennt direkt erlernte und durch erworbene Kampfstile freigeschaltete Manöver.
bool isAdvancementManeuverOwned(AdvancementContext context, String targetId) =>
    context.ownedManeuverIds.contains(targetId);

/// Liefert AP, Besitz und Voraussetzungen eines konkreten Manövererwerbs.
AdvancementOption? resolveAdvancementManeuver(
  AdvancementContext context,
  String targetId,
) {
  final parts = targetId.split('::');
  if (parts.length > 2) return null;
  final def = context.catalog.maneuvers
      .where((def) => def.id == parts.first)
      .firstOrNull;
  if (def == null) return null;
  final eligible = _eligibleTalents(context.hero, context.catalog, def);
  final selected = parts.length == 2
      ? eligible.where((talent) => talent.id == parts[1]).firstOrNull
      : null;
  if (parts.length == 2 &&
      (!def.mussSeparatErlerntWerden || selected == null)) {
    return null;
  }
  final owned = isAdvancementManeuverOwned(context, targetId);
  String? unavailable;
  if (def.mussSeparatErlerntWerden && selected == null) {
    unavailable = 'Ein aktives passendes Kampftalent ist erforderlich.';
  }
  if (def.nurEpisch && !context.hero.isEpisch) {
    unavailable = 'Erfordert epischen Status';
  }
  if (owned) unavailable = 'Bereits erworben';
  final requirements =
      def.voraussetzungenStruktur.isEmpty &&
          def.voraussetzungen.trim().isNotEmpty
      ? [
          SpecialAbilityRequirement(
            art: RequirementArt.hinweis,
            text: def.voraussetzungen,
          ),
        ]
      : def.voraussetzungenStruktur;
  final bound = requirements.map((r) => _bindTalent(r, selected?.name ?? ''));
  return AdvancementOption(
    kind: AdvancementKind.maneuver,
    targetId: targetId,
    label: selected == null ? def.name : '${def.name} (${selected.name})',
    ability: def,
    isOwned: owned,
    unavailableReason: unavailable,
    apCost: parseLeadingApAmount(def.kosten),
    requirements: evaluateRequirements(bound, context.requirementContext),
  );
}

// Verhindert Phantom-Erwerbe für unbekannte, ausgeblendete oder inaktive Talente.
List<TalentDef> _eligibleTalents(
  HeroSheet hero,
  RulesCatalog catalog,
  ManeuverDef def,
) {
  return catalog.talents
      .where((talent) {
        final value = hero.talents[talent.id]?.talentValue ?? -1;
        return talent.active &&
            value >= 0 &&
            (def.giltFuerTalentTyp.isEmpty ||
                talent.type == def.giltFuerTalentTyp) &&
            (def.nurFuerTalente.isEmpty ||
                def.nurFuerTalente.contains(talent.id));
      })
      .toList(growable: false);
}

// Der Katalog kann denselben Vertrag für jedes Fernkampftalent ausdrücken.
SpecialAbilityRequirement _bindTalent(
  SpecialAbilityRequirement r,
  String name,
) {
  final json = r.toJson();
  if (r.name.contains(r'$talent')) {
    json['name'] = r.name.replaceAll(r'$talent', name);
  }
  if (r.bedingungen.isNotEmpty) {
    json['bedingungen'] = r.bedingungen
        .map((child) => _bindTalent(child, name).toJson())
        .toList();
  }
  return SpecialAbilityRequirement.fromJson(json);
}
