part of 'advancement_rules.dart';

// Jede Mutation erhält fachfremde Felder des bestehenden Eintrags.
HeroSheet _applyEntry(
  HeroSheet hero,
  HeroAdvancementEntry entry,
  AdvancementOption option,
  RulesCatalog catalog,
) {
  final id = entry.targetId;
  switch (entry.kind) {
    case AdvancementKind.attribute:
      final code = parseAttributeCode(id)!;
      final raised = applyAdvancementAttributeValue(hero, code, entry.toValue!);
      return raised.copyWith(
        attributeSePool: hero.attributeSePool.adjust(code, -entry.seSpent),
      );
    case AdvancementKind.boughtStat:
      final json = hero.bought.toJson();
      json[id] = entry.toValue!;
      return hero.copyWith(
        bought: BoughtStats.fromJson(json),
        statSePool: hero.statSePool.adjust(id, -entry.seSpent),
      );
    case AdvancementKind.talent:
      return _applyTalent(hero, entry, catalog);
    case AdvancementKind.spell:
      final old = hero.spells[id] ?? const HeroSpellEntry();
      final activate = old.spellValue == null;
      final next = old.copyWith(
        spellValue: entry.toValue,
        learnedRepresentation: activate
            ? option.options['learnedRepresentation']
            : old.learnedRepresentation,
        learnedTradition: activate
            ? option.options['learnedTradition']
            : old.learnedTradition,
      );
      return hero.copyWith(spells: {...hero.spells, id: next});
    case AdvancementKind.language:
      final old = hero.sprachen[id] ?? const HeroLanguageEntry();
      return hero.copyWith(
        sprachen: {
          ...hero.sprachen,
          id: old.copyWith(wert: entry.toValue),
        },
      );
    case AdvancementKind.script:
      final old = hero.schriften[id] ?? const HeroScriptEntry();
      return hero.copyWith(
        schriften: {
          ...hero.schriften,
          id: old.copyWith(wert: entry.toValue),
        },
      );
    case AdvancementKind.combatAbility:
      return hero.copyWith(
        combatConfig: _acquireCombatAbility(hero.combatConfig, id),
      );
    case AdvancementKind.generalAbility:
    case AdvancementKind.karmalAbility:
      return hero.copyWith(
        talentSpecialAbilities: [
          ...hero.talentSpecialAbilities,
          TalentSpecialAbility(name: option.label),
        ],
      );
    case AdvancementKind.magicAbility:
      return hero.copyWith(
        magicSpecialAbilities: [
          ...hero.magicSpecialAbilities,
          MagicSpecialAbility(name: option.label),
        ],
      );
  }
}

// AT/PA sind reine Verteilung der neu erworbenen Nahkampfpunkte.
HeroSheet _applyTalent(
  HeroSheet hero,
  HeroAdvancementEntry entry,
  RulesCatalog catalog,
) {
  final id = entry.targetId;
  final old = hero.talents[id] ?? const HeroTalentEntry();
  final def = catalog.talents.firstWhere((item) => item.id == id);
  var next = old.copyWith(
    talentValue: entry.toValue,
    specialExperiences: old.specialExperiences - entry.seSpent,
  );
  if (def.type == 'fernkampf') {
    next = next.copyWith(atValue: entry.toValue!, paValue: 0);
  } else if (def.type == 'nahkampf') {
    final delta = entry.toValue! - (old.talentValue ?? 0);
    final at = int.tryParse(entry.options['atDelta'] ?? '') ?? delta;
    final allocations = advancementCombatAllocations(
      hero: hero,
      catalog: catalog,
      targetId: id,
      fromValue: entry.fromValue!,
      toValue: entry.toValue!,
    );
    if (!allocations.contains(at)) {
      throw StateError('Ungültige AT/PA-Verteilung.');
    }
    next = next.copyWith(
      atValue: old.atValue + at,
      paValue: old.paValue + delta - at,
    );
  }
  return hero.copyWith(
    talents: {...hero.talents, id: next},
    hiddenTalentIds: hero.hiddenTalentIds.where((item) => item != id).toList(),
  );
}

// Sonderfelder müssen gesetzt werden, weil Kampfberechnungen diese direkt lesen.
CombatConfig _acquireCombatAbility(CombatConfig config, String id) {
  final rules = config.specialRules;
  final updated = switch (id) {
    'ksf_kampfreflexe' => rules.copyWith(kampfreflexe: true),
    'ksf_kampfgespuer' => rules.copyWith(kampfgespuer: true),
    'ksf_schnellziehen' => rules.copyWith(schnellziehen: true),
    'ksf_ausweichen_i' => rules.copyWith(ausweichenI: true),
    'ksf_ausweichen_ii' => rules.copyWith(ausweichenII: true),
    'ksf_ausweichen_iii' => rules.copyWith(ausweichenIII: true),
    'ksf_linkhand' => rules.copyWith(linkhandActive: true),
    'ksf_schildkampf_i' => rules.copyWith(schildkampfI: true),
    'ksf_schildkampf_ii' => rules.copyWith(schildkampfII: true),
    'ksf_parierwaffen_i' => rules.copyWith(parierwaffenI: true),
    'ksf_parierwaffen_ii' => rules.copyWith(parierwaffenII: true),
    'ksf_klingentaenzer' => rules.copyWith(klingentaenzer: true),
    'ksf_aufmerksamkeit' => rules.copyWith(aufmerksamkeit: true),
    _ => rules.copyWith(
      activeCombatSpecialAbilityIds: [
        ...rules.activeCombatSpecialAbilityIds,
        id,
      ],
    ),
  };
  final training = switch (id) {
    'ksf_ruestungsgewoehnung_i' => 1,
    'ksf_ruestungsgewoehnung_ii' => 2,
    'ksf_ruestungsgewoehnung_iii' => 3,
    _ => config.armor.globalArmorTrainingLevel,
  };
  return config.copyWith(
    specialRules: updated,
    armor: config.armor.copyWith(globalArmorTrainingLevel: training),
  );
}
