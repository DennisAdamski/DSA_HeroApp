import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

import 'advancement_attribute_rules.dart';
import 'advancement_options.dart';
import 'hero_stat_inputs.dart';
import 'resource_activation_rules.dart';

/// Vorher-/Nachher-Wert einschließlich der fachlich berechneten Differenz.
class AdvancementStatChange {
  /// Verknüpft einen angezeigten Basiswert mit beiden Vergleichsständen.
  const AdvancementStatChange(this.label, this.before, this.after);
  final String label;
  final int before;
  final int after;

  /// Differenz der Summen; Rundung ist bereits in den Basiswerten enthalten.
  int get delta => after - before;
}

/// Ein bisher begrenztes Steigerungsziel mit neuem regeltechnischem Spielraum.
class AdvancementUnlockedValue {
  /// Erhält die ursprüngliche Grenze und die neu aufgelöste Steigerungsoption.
  const AdvancementUnlockedValue(this.before, this.after);
  final AdvancementOption before;
  final AdvancementOption after;

  /// Trennt Kampfwerte von sonstigen Talenten für eine verständliche Liste.
  String get category => before.kind == AdvancementKind.spell
      ? 'Zauber'
      : before.isCombatTalent
      ? 'Kampftalent'
      : 'Talent';
}

/// Rein informative Auswirkungen ohne AP-Buchung oder Änderung der Sitzung.
class AdvancementImpact {
  /// Schützt die Ergebnisse vor nachträglicher Änderung durch das UI.
  AdvancementImpact({
    required List<AdvancementStatChange> stats,
    List<AdvancementUnlockedValue> unlocked = const [],
  }) : stats = List.unmodifiable(stats),
       unlocked = List.unmodifiable(unlocked);
  final List<AdvancementStatChange> stats;
  final List<AdvancementUnlockedValue> unlocked;
}

/// Vergleicht Basiswertsummen mit identischem Laufzeitzustand und Regelstand.
AdvancementImpact computeAdvancementImpact({
  required HeroSheet before,
  required HeroSheet after,
  required HeroState state,
  required RulesCatalog catalog,
  required bool epicAdvantagesActive,
}) {
  final oldInputs = computeHeroStatInputs(
    hero: before,
    state: state,
    talents: catalog.talents,
    epicAdvantagesActive: epicAdvantagesActive,
  );
  final newInputs = computeHeroStatInputs(
    hero: after,
    state: state,
    talents: catalog.talents,
    epicAdvantagesActive: epicAdvantagesActive,
  );
  final oldStats = oldInputs.derive(before, state);
  final newStats = newInputs.derive(after, state);
  final activation = computeHeroResourceActivation(after);
  return AdvancementImpact(
    stats: [
      AdvancementStatChange('LeP', oldStats.maxLep, newStats.maxLep),
      AdvancementStatChange('Au', oldStats.maxAu, newStats.maxAu),
      if (activation.magic.isEnabled)
        AdvancementStatChange('AsP', oldStats.maxAsp, newStats.maxAsp),
      if (activation.divine.isEnabled)
        AdvancementStatChange('KaP', oldStats.maxKap, newStats.maxKap),
      AdvancementStatChange('MR', oldStats.mr, newStats.mr),
      AdvancementStatChange('Ini-Basis', oldStats.iniBase, newStats.iniBase),
      AdvancementStatChange('AT-Basis', oldStats.atBase, newStats.atBase),
      AdvancementStatChange('PA-Basis', oldStats.paBase, newStats.paBase),
      AdvancementStatChange('FK-Basis', oldStats.fkBase, newStats.fkBase),
      AdvancementStatChange('GS', oldStats.gs, newStats.gs),
    ],
  );
}

/// Simuliert nur die gewählte Eigenschaft auf Basis der aktuellen Planung.
/// Talentgrenzen verwenden dieselben permanenten Eigenschaften wie der Katalog;
/// AP-Verfügbarkeit beeinflusst diese rein regeltechnische Auskunft nicht.
AdvancementImpact computeAttributeAdvancementImpact({
  required HeroSheet hero,
  required RulesCatalog catalog,
  required HeroState state,
  required AttributeCode attribute,
  required int targetValue,
  required bool epicAdvantagesActive,
}) {
  final after = applyAdvancementAttributeValue(hero, attribute, targetValue);
  final stats = computeAdvancementImpact(
    before: hero,
    after: after,
    state: state,
    catalog: catalog,
    epicAdvantagesActive: epicAdvantagesActive,
  ).stats;
  final unlocked = <AdvancementUnlockedValue>[];
  final targets = <(AdvancementKind, String)>[
    for (final id in hero.talents.keys) (AdvancementKind.talent, id),
    for (final id in hero.spells.keys) (AdvancementKind.spell, id),
  ];
  // Je ein Kontext für beide Vergleichsstände, außerhalb der Schleife: sonst
  // liefe jeder Klick im Eigenschaftsdialog zweimal je Talent und Zauber
  // durch die Modifikatoren-Auswertung.
  final beforeContext = AdvancementContext(hero: hero, catalog: catalog);
  final afterContext = AdvancementContext(hero: after, catalog: catalog);
  for (final (kind, id) in targets) {
    final oldOption = resolveAdvancementOptionIn(
      context: beforeContext,
      kind: kind,
      targetId: id,
    );
    if (oldOption == null ||
        oldOption.currentValue < 0 ||
        oldOption.currentValue < oldOption.maxValue) {
      continue;
    }
    final newOption = resolveAdvancementOptionIn(
      context: afterContext,
      kind: kind,
      targetId: id,
    );
    if (newOption == null ||
        newOption.maxValue <= oldOption.maxValue ||
        newOption.maxValue <= oldOption.currentValue ||
        newOption.unavailableReason != null) {
      continue;
    }
    unlocked.add(AdvancementUnlockedValue(oldOption, newOption));
  }
  unlocked.sort((a, b) {
    final categoryOrder = a.category.compareTo(b.category);
    if (categoryOrder != 0) return categoryOrder;
    return a.before.label.toLowerCase().compareTo(b.before.label.toLowerCase());
  });
  return AdvancementImpact(stats: stats, unlocked: unlocked);
}
