part of 'advancement_options.dart';

// Eigenschaften werden auf derselben Effektivebene wie Startwert und Maximum geplant.
AdvancementOption? _attributeOption(AdvancementContext context, String id) {
  final hero = context.hero;
  final code = parseAttributeCode(id);
  if (code == null) return null;
  final delta = attributeModValue(
    parseStartAttributeModifiers(hero),
    code.name,
  );
  final value = readAttributeValue(hero.attributes, code) + delta;
  final maximum = readAttributeValue(computeHeroAttributeMaximums(hero), code);
  return AdvancementOption(
    kind: AdvancementKind.attribute,
    targetId: code.name,
    label: '${attributeCodeName(code)} (${attributeCodeKey(code)})',
    currentValue: value,
    maxValue: maximum,
    seAvailable: hero.attributeSePool.valueFor(code),
    learnCost: kEigenschaftKomplexitaet,
    startValue: readAttributeValue(
      computeHeroEffectiveStartAttributes(hero),
      code,
    ),
    isMainAttribute: readAttributeValue(hero.epicMainAttributes, code) > 0,
    // Eigenschaften gibt es bei jedem Helden; sie kennen keine Aktivierung.
    isOwned: true,
    unavailableReason: value >= maximum ? 'Maximum erreicht' : null,
  );
}

// Grundwerte behalten die bisherigen fachlichen Zukaufgrenzen.
AdvancementOption? _boughtOption(AdvancementContext context, String id) {
  final hero = context.hero;
  final cost = kGrundwertKomplexitaeten[id];
  if (cost == null) return null;
  final value = (hero.bought.toJson()[id] as num).toInt();
  final maximum = computeBoughtStatMaximum(
    statKey: id,
    permanentAttributes: context.permanentAttributes,
  );
  // Ohne Fachgrenze begrenzt die AP-Prüfung den Erwerb. Der Dialog erhält
  // einen endlichen großzügigen Bereich, auch für verbilligte Schritte.
  final dialogMaximum =
      maximum ?? value + hero.apAvailable.clamp(0, 1000000) + 1;
  return AdvancementOption(
    kind: AdvancementKind.boughtStat,
    targetId: id,
    label: const {
      'lep': 'LeP',
      'au': 'Au',
      'asp': 'AsP',
      'kap': 'KaP',
      'mr': 'MR',
    }[id]!,
    currentValue: value,
    maxValue: dialogMaximum,
    learnCost: cost,
    seAvailable: hero.statSePool.valueFor(id),
    isOwned: true,
    unavailableReason: value >= dialogMaximum ? 'Maximum erreicht' : null,
  );
}

// Talentgrenzen und Begabung stammen aus den bereits gemeinsam verwendeten Regeln.
AdvancementOption? _talentOption(AdvancementContext context, String id) {
  final hero = context.hero;
  final def = context.catalog.talents
      .where((item) => item.id == id)
      .firstOrNull;
  // Ein abgeschaltetes Katalogtalent verschwindet — es sei denn, der Held
  // führt es bereits. Sonst wäre sein Wert weder sichtbar noch steigerbar.
  if (def == null || (!def.active && !hero.talents.containsKey(id))) {
    return null;
  }
  final entry = hero.talents[id] ?? const HeroTalentEntry();
  final combat =
      def.group == 'Kampftalent' ||
      def.type == 'nahkampf' ||
      def.type == 'fernkampf' ||
      def.weaponCategory.isNotEmpty;
  final attrs = context.permanentAttributes;
  var maximum = combat
      ? computeCombatTalentMaxValue(
          effectiveAttributes: attrs,
          talentType: def.type,
          gifted: entry.gifted,
        )
      : computeTalentMaxValue(
          effectiveAttributes: attrs,
          attributeNames: def.attributes,
          gifted: entry.gifted,
        );
  if (hero.isEpisch && hero.epicUnactivatedTalentIds.contains(id)) {
    final names = combat
        ? (def.type == 'fernkampf' ? ['FF', 'KK'] : ['GE', 'KK'])
        : def.attributes;
    for (final name in names) {
      final code = parseAttributeCode(name);
      if (code != null) {
        final value = readAttributeValue(attrs, code);
        if (value < maximum) maximum = value;
      }
    }
  }
  final complexity = effectiveTalentLernkomplexitaet(
    basisKomplexitaet: def.steigerung,
    gifted: entry.gifted,
  );
  final cost = learnCostFromKomplexitaet(complexity);
  final value = entry.talentValue ?? -1;
  return AdvancementOption(
    kind: AdvancementKind.talent,
    targetId: id,
    label: def.name,
    currentValue: value,
    maxValue: maximum,
    learnCost: cost,
    seAvailable: entry.specialExperiences,
    isCombatTalent: combat,
    isOwned: hero.talents.containsKey(id),
    complexityHint: 'Lernkomplexität $complexity',
    unavailableReason: cost == null
        ? 'Keine Lernkomplexität hinterlegt'
        : value >= maximum
        ? 'Maximum erreicht'
        : null,
  );
}

// Repräsentationen bleiben Teil des Befehls, damit Replay denselben Erwerb prüft.
AdvancementOption? _spellOption(
  AdvancementContext context,
  String id,
  Map<String, String> options,
) {
  final hero = context.hero;
  final def = context.catalog.spells.where((item) => item.id == id).firstOrNull;
  if (def == null) return null;
  final entry = hero.spells[id] ?? const HeroSpellEntry();
  final choices = allLearningOptionsForHero(
    def.availability,
    hero.representationen,
  );
  final repr = options['learnedRepresentation'] ?? entry.learnedRepresentation;
  final tradition = options['learnedTradition'] ?? entry.learnedTradition;
  final selected = choices
      .where(
        (item) =>
            (repr == null || item.learnedRepresentation == repr) &&
            (tradition == null || item.tradition == tradition),
      )
      .firstOrNull;
  final value = entry.spellValue ?? -1;
  final chosen = <String, String>{
    ...options,
    if (selected != null)
      'learnedRepresentation': selected.learnedRepresentation,
    if (selected != null) 'learnedTradition': selected.tradition,
  };
  final foreign = isForeignLearnedRepresentation(
    learnedRepresentation: chosen['learnedRepresentation'] ?? repr,
    learnedTradition: chosen['learnedTradition'] ?? tradition,
  );
  final complexity = effectiveSpellLernkomplexitaet(
    basisKomplexitaet: def.steigerung,
    istHauszauber: entry.hauszauber,
    zauberMerkmale: parseSpellTraits(def.traits),
    heldMerkmalskenntnisse: hero.merkmalskenntnisse,
    gifted: entry.gifted,
    penaltySteps: foreign ? 2 : 0,
  );
  final maximum = computeTalentMaxValue(
    effectiveAttributes: context.permanentAttributes,
    attributeNames: def.attributes,
    gifted: entry.gifted,
  );
  final cost = learnCostFromKomplexitaet(complexity);
  return AdvancementOption(
    kind: AdvancementKind.spell,
    targetId: id,
    label: def.name,
    currentValue: value,
    maxValue: maximum,
    learnCost: cost,
    options: chosen,
    isOwned: hero.spells.containsKey(id),
    complexityHint: 'Lernkomplexität $complexity',
    unavailableReason: value < 0 && selected == null
        ? 'Keine passende Repräsentation'
        : cost == null
        ? 'Keine Lernkomplexität hinterlegt'
        : value >= maximum
        ? 'Maximum erreicht'
        : null,
  );
}

// Die Sprachfamilie der Muttersprache bestimmt die verbilligte Kategorie.
AdvancementOption? _languageOption(AdvancementContext context, String id) {
  final hero = context.hero;
  final catalog = context.catalog;
  final def = catalog.sprachen.where((item) => item.id == id).firstOrNull;
  if (def == null) return null;
  final mother = catalog.sprachen
      .where((item) => item.id == hero.muttersprache)
      .firstOrNull;
  final sameFamily = mother != null && mother.familie == def.familie;
  final complexity = def.steigerung == 'B' || !sameFamily ? 'B' : 'A';
  final value = hero.sprachen[id]?.wert ?? -1;
  return AdvancementOption(
    kind: AdvancementKind.language,
    targetId: id,
    label: def.name,
    currentValue: value,
    maxValue: def.maxWert,
    learnCost: learnCostFromKomplexitaet(complexity),
    isOwned: hero.sprachen.containsKey(id),
    unavailableReason: value >= def.maxWert ? 'Maximum erreicht' : null,
  );
}

AdvancementOption? _scriptOption(AdvancementContext context, String id) {
  final hero = context.hero;
  final def = context.catalog.schriften
      .where((item) => item.id == id)
      .firstOrNull;
  if (def == null) return null;
  final value = hero.schriften[id]?.wert ?? -1;
  return AdvancementOption(
    kind: AdvancementKind.script,
    targetId: id,
    label: def.name,
    currentValue: value,
    maxValue: def.maxWert,
    learnCost: learnCostFromKomplexitaet(def.steigerung),
    isOwned: hero.schriften.containsKey(id),
    unavailableReason: value >= def.maxWert ? 'Maximum erreicht' : null,
  );
}
