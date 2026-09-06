import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_entry.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';

import 'attribute_start_rules.dart';
import 'bought_stat_limit_rules.dart';
import 'combat_special_ability_state.dart';
import 'cost_text_parsing.dart';
import 'hero_requirement_context.dart';
import 'learning_rules.dart';
import 'magic_rules.dart';
import 'modifier_parser.dart';
import 'modifier_source_breakdown.dart';
import 'requirement_evaluation_rules.dart';
import 'special_ability_chain_rules.dart';
import 'special_ability_variant_rules.dart';

part 'advancement_value_options.dart';
part 'advancement_ability_options.dart';
part 'advancement_scope_rules.dart';

/// Regelvorschlag für ein Ziel im aktuellen Stand einer Steigerungssitzung.
class AdvancementOption {
  /// Hält fachliche Grenzen und Dialogvorschläge ohne eigene Persistenz.
  const AdvancementOption({
    required this.kind,
    required this.targetId,
    required this.label,
    this.currentValue = -1,
    this.maxValue = 0,
    this.seAvailable = 0,
    this.learnCost,
    this.startValue,
    this.isMainAttribute = false,
    this.complexityHint,
    this.ability,
    this.options = const {},
    this.isOwned = false,
    this.ownedCount = 0,
    this.unavailableReason,
    this.apCost,
    this.requirements = const [],
    this.isCombatTalent = false,
  });

  final AdvancementKind kind;
  final String targetId;
  final String label;
  final int currentValue;
  final int maxValue;
  final int seAvailable;
  final LearnCost? learnCost;
  final int? startValue;
  final bool isMainAttribute;
  final String? complexityHint;
  final SpecialAbilityEntry? ability;
  final Map<String, String> options;

  /// Ob das Ziel beim Helden auf dem Bogen steht.
  ///
  /// Maßgeblich ist der Schlüssel, nicht der Wert: Ein eingeblendetes Talent
  /// ohne Wert (`null`) steht bereits auf dem Bogen, nur seine
  /// Aktivierungskosten sind noch offen. Zusammen mit [currentValue] ergeben
  /// sich die drei Zustände „nicht auf dem Bogen" (`false` / `-1`),
  /// „eingeblendet, noch nicht aktiviert" (`true` / `-1`) und „aktiviert"
  /// (`true` / `>= 0`) — eine Unterscheidung, die [currentValue] allein nicht
  /// tragen kann. Eigenschaften und Grundwerte sind immer vorhanden und
  /// deshalb immer `true`.
  final bool isOwned;

  /// Anzahl bereits erworbener Instanzen einer mehrfach wählbaren
  /// Sonderfertigkeit; sonst `0`.
  final int ownedCount;

  final String? unavailableReason;
  final int? apCost;
  final List<RequirementCheckResult> requirements;
  final bool isCombatTalent;

  /// Unterscheidet numerische Progression vom einmaligen SF-Erwerb.
  bool get isValueAdvancement => ability == null;
}

/// Einmal je Optionsaufbau berechnete Grundlagen.
///
/// Alle Felder hängen nur am Helden und am Katalog, nicht am einzelnen Ziel.
/// Ohne diese Bündelung baute jede der rund 280 Sonderfertigkeits-Optionen den
/// vollständigen Voraussetzungskontext neu auf, und jede der rund 800 Optionen
/// liefe erneut durch `parseModifierTextsForHero`. Die Felder sind bewusst
/// `late final`: Wertoptionen brauchen den Voraussetzungskontext nie, ein
/// eifriger Aufbau wäre also eine Verschlechterung.
class AdvancementContext {
  /// Bündelt Held und Katalog für einen Durchlauf des Optionsaufbaus.
  AdvancementContext({required this.hero, required this.catalog});

  /// Vorschauheld, gegen den alle Ziele aufgelöst werden.
  final HeroSheet hero;

  /// Regelkatalog der laufenden Sitzung.
  final RulesCatalog catalog;

  /// Dauerhafte Eigenschaften für Grenzen und Erwerbsvoraussetzungen.
  late final Attributes permanentAttributes = advancementPermanentAttributes(
    hero,
  );

  /// Namen aller erworbenen Sonderfertigkeiten über alle Speicherorte hinweg.
  late final List<String> ownedAbilityNames = heroSpecialAbilityNames(
    hero,
    catalog: catalog,
  );

  late final Set<String> _normalizedOwnedNames = <String>{
    for (final name in ownedAbilityNames) normalizeSpecialAbilityName(name),
  };

  /// Prüfkontext für Erwerbsvoraussetzungen.
  late final HeroRequirementContext requirementContext =
      buildHeroRequirementContext(
        hero.copyWith(attributes: permanentAttributes),
        catalog: catalog,
      );

  final Map<AdvancementKind, Set<String>> _ownedAbilityIds = {};
  final Map<AdvancementKind, Set<String>> _actionableAbilityIds = {};

  /// Ob der Held eine Sonderfertigkeit unter genau diesem Anzeigenamen führt.
  bool hasOwnedAbilityName(String displayName) =>
      _normalizedOwnedNames.contains(normalizeSpecialAbilityName(displayName));

  /// Katalogeinträge der jeweiligen Sonderfertigkeits-Art.
  List<SpecialAbilityEntry> abilityEntries(AdvancementKind kind) =>
      switch (kind) {
        AdvancementKind.generalAbility => catalog.generalSpecialAbilities,
        AdvancementKind.magicAbility => catalog.magicSpecialAbilities,
        AdvancementKind.karmalAbility => catalog.karmalSpecialAbilities,
        AdvancementKind.combatAbility => catalog.combatSpecialAbilities,
        _ => const <SpecialAbilityEntry>[],
      };

  /// IDs der bereits erworbenen Sonderfertigkeiten dieser Art.
  Set<String> ownedAbilityIds(AdvancementKind kind) => _ownedAbilityIds
      .putIfAbsent(kind, () => computeOwnedAbilityIds(this, kind));

  /// IDs, die aus dem Bestand des Helden unmittelbar handlungsfähig sind.
  Set<String> actionableAbilityTargets(AdvancementKind kind) =>
      _actionableAbilityIds.putIfAbsent(
        kind,
        () => computeActionableAbilityTargets(this, kind),
      );
}

/// Erstellt die Katalogziele im gewünschten [scope].
///
/// Der Umfang wird vor dem Auflösen geprüft, damit ein eingeschränkter Aufruf
/// die teure Regelauswertung gar nicht erst anstößt.
List<AdvancementOption> buildAdvancementOptions({
  required HeroSheet hero,
  required RulesCatalog catalog,
  AdvancementScope scope = AdvancementScope.all,
}) {
  final context = AdvancementContext(hero: hero, catalog: catalog);
  final targets = <(AdvancementKind, String)>[
    for (final code in AttributeCode.values)
      (AdvancementKind.attribute, code.name),
    for (final key in kGrundwertKomplexitaeten.keys)
      (AdvancementKind.boughtStat, key),
    for (final def in catalog.talents) (AdvancementKind.talent, def.id),
    for (final def in catalog.spells) (AdvancementKind.spell, def.id),
    for (final def in catalog.sprachen) (AdvancementKind.language, def.id),
    for (final def in catalog.schriften) (AdvancementKind.script, def.id),
    for (final def in catalog.generalSpecialAbilities)
      (AdvancementKind.generalAbility, def.id),
    for (final def in catalog.magicSpecialAbilities)
      (AdvancementKind.magicAbility, def.id),
    for (final def in catalog.karmalSpecialAbilities)
      (AdvancementKind.karmalAbility, def.id),
    for (final def in catalog.combatSpecialAbilities)
      (AdvancementKind.combatAbility, def.id),
  ];
  return [
    for (final target in targets)
      if (advancementScopeIncludes(
        context: context,
        scope: scope,
        kind: target.$1,
        targetId: target.$2,
      ))
        ?resolveAdvancementOptionIn(
          context: context,
          kind: target.$1,
          targetId: target.$2,
        ),
  ];
}

/// Prüft ein ausgewähltes Ziel erneut gegen den jeweils aktuellen Vorschauhelden.
AdvancementOption? resolveAdvancementOption({
  required HeroSheet hero,
  required RulesCatalog catalog,
  required AdvancementKind kind,
  required String targetId,
  Map<String, String> options = const {},
}) => resolveAdvancementOptionIn(
  context: AdvancementContext(hero: hero, catalog: catalog),
  kind: kind,
  targetId: targetId,
  options: options,
);

/// Löst ein Ziel gegen bereits vorberechnete Grundlagen auf.
///
/// Getrennt von [resolveAdvancementOption] und nicht als optionaler Parameter,
/// damit kein Aufrufer ein inkonsistentes Paar aus Held und Kontext übergeben
/// kann.
AdvancementOption? resolveAdvancementOptionIn({
  required AdvancementContext context,
  required AdvancementKind kind,
  required String targetId,
  Map<String, String> options = const {},
}) {
  return switch (kind) {
    AdvancementKind.attribute => _attributeOption(context, targetId),
    AdvancementKind.boughtStat => _boughtOption(context, targetId),
    AdvancementKind.talent => _talentOption(context, targetId),
    AdvancementKind.spell => _spellOption(context, targetId, options),
    AdvancementKind.language => _languageOption(context, targetId),
    AdvancementKind.script => _scriptOption(context, targetId),
    _ => _abilityOption(context, kind, targetId, options),
  };
}

/// Dauerhafte Eigenschaften für Grenzen und Erwerbsvoraussetzungen.
Attributes advancementPermanentAttributes(HeroSheet hero) {
  final parsed = parseModifierTextsForHero(hero);
  final named = aggregateNamedAttributeModifiers(hero.attributeModifiers);
  return applyAttributeModifiers(hero.attributes, parsed.attributeMods + named);
}
