import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_main_attribute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/house_rules/house_rule_registry.dart';
import 'package:dsa_heldenverwaltung/state/house_rules_providers.dart';

/// Ob die epische KO-Haupteigenschaft die Wund-Proben-Erschwernis halbiert.
///
/// Die Wunden-UI berechnet ihre Vorschauwerte selbst und nicht ueber
/// `heroComputedProvider`. Damit Vorschau und persistierter Snapshot
/// dieselbe Regel anwenden, liegt das Gate hier an einer Stelle.
bool isEpicWoundReliefActive(WidgetRef ref, HeroSheet hero) {
  return isEpicMainAttributeBonusActive(
    ruleActive: ref.read(isHouseRuleActiveProvider(EpicRuleKeys.advantages)),
    isEpisch: hero.isEpisch,
    mainAttributes: hero.epicMainAttributes,
    code: AttributeCode.ko,
  );
}
