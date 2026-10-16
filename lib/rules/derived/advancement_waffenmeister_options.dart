/// Waffenmeisterschaften und Waffen-Großmeister direkt am Kampftalent.
///
/// Eine Waffenmeisterschaft wird als [AdvancementKind.talent] mit der Aktion
/// [kWaffenmeisterAktion] geplant; die im Editor erstellte
/// [WaffenmeisterConfig] reist als JSON im Optionsfeld
/// [kWaffenmeisterOptionKonfiguration] mit und wird erst beim Übernehmen in
/// `combatConfig.waffenmeisterschaften` eingetragen. Der Waffen-Großmeister
/// bleibt die epische Kampf-SF des Katalogs ([grossmeisterFuerTalent]).
///
/// Voraussetzungen laut Wege des Schwerts S. 192 (per dsa-rules-MCP belegt):
/// 2.500 AP in Kampf-Sonderfertigkeiten, TaW 18 und eine Spezialisierung auf
/// die Waffe, Eigenschaftsanforderungen von zusammen 32 Punkten in zwei von
/// MU/IN/FF/GE/KK mit GE mindestens 13; Kosten 400 AP. Waffenmeister
/// (Schild): KK 16, GE 15, Schildkampf II, Beidhändiger Kampf I, dazu
/// Parierwaffen I oder Binden, kein TaW 18. Offene Punkte sperren nie, sie
/// verlangen einen Meisterentscheid.
library;

import 'dart:convert';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/waffenmeister_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

import 'advancement_options.dart';
import 'advancement_specialization_rules.dart';
import 'cost_text_parsing.dart';
import 'requirement_evaluation_rules.dart';
import 'special_ability_variant_rules.dart';
import 'waffenmeister_rules.dart';

/// Aktionsname im Optionsfeld `action`.
const String kWaffenmeisterAktion = 'waffenmeister';

/// Optionsschlüssel der serialisierten [WaffenmeisterConfig].
const String kWaffenmeisterOptionKonfiguration = 'config';

/// Schwelle der in Kampf-Sonderfertigkeiten investierten AP.
const int kWaffenmeisterKampfSfAp = 2500;

/// Quellenangabe für Hinweise.
const String kWaffenmeisterQuelle = 'Wege des Schwerts S. 192';

/// Ob ein Talent ein Kampftalent ist (wie der Steigerungskatalog).
bool istKampftalent(TalentDef def) =>
    def.group == 'Kampftalent' ||
    def.type == 'nahkampf' ||
    def.type == 'fernkampf' ||
    def.weaponCategory.isNotEmpty;

/// Liest die geplante Konfiguration; `null` bei fehlender oder kaputter Angabe.
WaffenmeisterConfig? leseWaffenmeisterKonfiguration(
  Map<String, String> options,
) {
  final roh = options[kWaffenmeisterOptionKonfiguration];
  if (roh == null || roh.trim().isEmpty) return null;
  try {
    final json = jsonDecode(roh);
    if (json is! Map) return null;
    return WaffenmeisterConfig.fromJson(json.cast<String, dynamic>());
  } on FormatException {
    return null;
  }
}

/// Serialisiert eine Konfiguration für das Optionsfeld.
String schreibeWaffenmeisterKonfiguration(WaffenmeisterConfig config) =>
    jsonEncode(config.toJson());

/// Der Waffen-Großmeister zum Kampftalent [talentId], sofern katalogisiert.
CombatSpecialAbilityDef? grossmeisterFuerTalent(
  RulesCatalog catalog,
  String talentId,
) {
  final talent = catalog.talents.where((t) => t.id == talentId).firstOrNull;
  if (talent == null) return null;
  final gesucht = normalizeSpecialAbilityName(talent.name);
  for (final def in catalog.combatSpecialAbilities) {
    if (def.kampfTyp != 'grossmeister') continue;
    final passt = def.voraussetzungenStruktur.any(
      (r) =>
          r.art == RequirementArt.waffenmeister &&
          normalizeSpecialAbilityName(r.name) == gesucht,
    );
    if (passt) return def;
  }
  return null;
}

/// AP, die der Held in Kampf-Sonderfertigkeiten und Manöver investiert hat
/// (Grundwerte laut Katalog, wie WdS S. 192 es verlangt).
int kampfSonderfertigkeitenAp(AdvancementContext context) {
  var summe = 0;
  final owned = context.ownedAbilityIds(AdvancementKind.combatAbility);
  for (final def in context.catalog.combatSpecialAbilities) {
    if (owned.contains(def.id)) summe += parseLeadingApAmount(def.kosten) ?? 0;
  }
  final manoever = <String>{
    for (final id in context.ownedManeuverIds) id.split('::').first,
  };
  for (final def in context.catalog.maneuvers) {
    if (manoever.contains(def.id)) {
      summe += parseLeadingApAmount(def.kosten) ?? 0;
    }
  }
  return summe;
}

RequirementCheckResult _befund({
  required bool erfuellt,
  required String soll,
  String ist = '',
}) => RequirementCheckResult(
  requirement: SpecialAbilityRequirement(
    art: RequirementArt.hinweis,
    text: soll,
  ),
  status: erfuellt
      ? RequirementStatus.erfuellt
      : RequirementStatus.nichtErfuellt,
  sollText: soll,
  istText: ist,
);

int _eigenschaft(AdvancementContext context, String kuerzel) {
  final code = parseAttributeCode(kuerzel);
  return code == null
      ? 0
      : readAttributeValue(context.permanentAttributes, code);
}

/// Prüft die Voraussetzungen einer Waffenmeisterschaft.
List<RequirementCheckResult> waffenmeisterVoraussetzungen(
  AdvancementContext context,
  TalentDef talent,
  WaffenmeisterConfig? config,
) {
  final schild = config?.isSchild ?? false;
  final ergebnisse = <RequirementCheckResult>[];
  final investiert = kampfSonderfertigkeitenAp(context);
  ergebnisse.add(
    _befund(
      erfuellt: investiert >= kWaffenmeisterKampfSfAp,
      soll: '$kWaffenmeisterKampfSfAp AP in Kampf-Sonderfertigkeiten',
      ist: '$investiert AP',
    ),
  );
  if (schild) {
    ergebnisse.addAll(
      evaluateRequirements(const <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'KK',
          min: 16,
        ),
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'GE',
          min: 15,
        ),
        SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Schildkampf II',
        ),
        SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Beidhändiger Kampf I',
        ),
        SpecialAbilityRequirement(
          art: RequirementArt.oderGruppe,
          bedingungen: <SpecialAbilityRequirement>[
            SpecialAbilityRequirement(
              art: RequirementArt.sonderfertigkeit,
              name: 'Parierwaffen I',
            ),
            SpecialAbilityRequirement(
              art: RequirementArt.manoever,
              name: 'Binden',
            ),
          ],
        ),
      ], context.requirementContext),
    );
  } else {
    ergebnisse.addAll(
      evaluateRequirements(<SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.talent,
          name: talent.name,
          min: 18,
        ),
        const SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'GE',
          min: 13,
        ),
      ], context.requirementContext),
    );
    final eintrag = context.hero.talents[talent.id];
    final spezialisierungen = eintrag == null
        ? const <String>[]
        : advancementTalentSpecializations(eintrag);
    final waffe = config?.weaponType.trim() ?? '';
    final passend = waffe.isEmpty
        ? spezialisierungen.isNotEmpty
        : spezialisierungen.any(
            (name) =>
                normalizeSpecialAbilityName(name) ==
                normalizeSpecialAbilityName(waffe),
          );
    ergebnisse.add(
      _befund(
        erfuellt: passend,
        soll: waffe.isEmpty
            ? 'Spezialisierung auf die Waffe'
            : 'Spezialisierung $waffe',
        ist: spezialisierungen.isEmpty
            ? 'keine Spezialisierung'
            : spezialisierungen.join(', '),
      ),
    );
  }
  if (config != null) {
    final summe =
        config.requiredAttribute1Value + config.requiredAttribute2Value;
    ergebnisse.add(
      _befund(
        erfuellt: summe >= 32,
        soll: 'Eigenschaftsanforderungen zusammen mindestens 32',
        ist:
            '${config.requiredAttribute1} ${config.requiredAttribute1Value} + '
            '${config.requiredAttribute2} ${config.requiredAttribute2Value}',
      ),
    );
    for (final (kuerzel, min) in <(String, int)>[
      (config.requiredAttribute1, config.requiredAttribute1Value),
      (config.requiredAttribute2, config.requiredAttribute2Value),
    ]) {
      final wert = _eigenschaft(context, kuerzel);
      ergebnisse.add(
        _befund(
          erfuellt: wert >= min,
          soll: '$kuerzel $min',
          ist: 'Held hat $wert',
        ),
      );
    }
  }
  if (context.hero.isEpisch) {
    ergebnisse.add(
      RequirementCheckResult(
        requirement: const SpecialAbilityRequirement(
          art: RequirementArt.hinweis,
        ),
        status: RequirementStatus.hinweis,
        sollText:
            'Episch nur, wenn die Voraussetzungen schon beim Erreichen des '
            'epischen Status erfüllt waren (Epische Stufen S. 5)',
      ),
    );
  }
  return ergebnisse;
}

/// Löst den Erwerb einer Waffenmeisterschaft am Kampftalent [talentId] auf.
AdvancementOption? resolveWaffenmeister(
  AdvancementContext context,
  String talentId,
  Map<String, String> options,
) {
  final talent = context.catalog.talents
      .where((def) => def.id == talentId)
      .firstOrNull;
  if (talent == null || !istKampftalent(talent)) return null;
  final config = leseWaffenmeisterKonfiguration(options);
  final eintrag = context.hero.talents[talentId];
  String? grund;
  if (eintrag?.talentValue == null) {
    grund = 'Das Kampftalent ist noch nicht aktiviert.';
  } else if (options.containsKey(kWaffenmeisterOptionKonfiguration) &&
      config == null) {
    grund = 'Die Waffenmeisterschaft ist nicht lesbar.';
  } else if (config != null && config.talentId != talentId) {
    grund = 'Die Waffenmeisterschaft gehört zu einem anderen Kampftalent.';
  } else if (config != null &&
      context.hero.combatConfig.waffenmeisterschaften.any(
        (wm) =>
            wm.talentId == talentId &&
            normalizeSpecialAbilityName(wm.weaponType) ==
                normalizeSpecialAbilityName(config.weaponType),
      )) {
    grund = 'Für diese Waffe besteht bereits eine Waffenmeisterschaft.';
  } else if (config != null) {
    final name = talent.name.toLowerCase();
    final auto = computeAutoPointCost(
      steigerung: talent.steigerung,
      isAttackOnly:
          talent.type.toLowerCase() == 'fernkampf' ||
          name == 'peitsche' ||
          name == 'lanzenreiten',
      hasAdditionalWeapons: config.additionalWeaponTypes.isNotEmpty,
    );
    final verteilt = computeTotalAllocated(config.bonuses);
    if (auto + verteilt > waffenmeisterTotalBudget) {
      grund =
          'Bonuspunkte überschreiten das Budget '
          '(${auto + verteilt} / $waffenmeisterTotalBudget).';
    }
  }
  final waffe = config?.weaponType.trim() ?? '';
  final katalogKosten = context.catalog.combatSpecialAbilities
      .where((def) => def.id == 'ksf_waffenmeister')
      .map((def) => parseLeadingApAmount(def.kosten))
      .firstOrNull;
  return AdvancementOption(
    kind: AdvancementKind.talent,
    targetId: talentId,
    label: 'Waffenmeister (${waffe.isEmpty ? talent.name : waffe})',
    options: {...options, 'action': kWaffenmeisterAktion},
    isOwned: true,
    isCombatTalent: true,
    currentValue: eintrag?.talentValue ?? -1,
    apCost: katalogKosten ?? waffenmeisterApCost,
    unavailableReason: grund,
    requirements: waffenmeisterVoraussetzungen(context, talent, config),
    complexityHint: '400 AP ($kWaffenmeisterQuelle)',
  );
}

/// Prüft einen geplanten Waffenmeister-Erwerb.
void validateWaffenmeisterEntry(
  HeroAdvancementEntry entry,
  AdvancementOption option,
) {
  if (leseWaffenmeisterKonfiguration(entry.options) == null) {
    throw StateError('Bitte die Waffenmeisterschaft im Editor festlegen.');
  }
  if (entry.seSpent != 0 || entry.fromValue != null || entry.toValue != null) {
    throw StateError(
      'Waffenmeisterschaften verändern weder TaW noch Sondererfahrungen.',
    );
  }
  if (!alleVoraussetzungenErfuellt(option.requirements) &&
      entry.options['meisterentscheid'] != 'true') {
    throw StateError(
      'Voraussetzungen fehlen; ein ausdrücklicher Meisterentscheid ist '
      'erforderlich.',
    );
  }
}

/// Trägt die geplante Waffenmeisterschaft am Vorschauhelden ein.
HeroSheet applyWaffenmeisterEntry(HeroSheet hero, HeroAdvancementEntry entry) {
  final config = leseWaffenmeisterKonfiguration(entry.options)!;
  final combat = hero.combatConfig;
  return hero.copyWith(
    combatConfig: combat.copyWith(
      waffenmeisterschaften: [...combat.waffenmeisterschaften, config],
    ),
  );
}
