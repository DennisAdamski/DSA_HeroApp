import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';

import 'advancement_options.dart';
import 'advancement_attribute_rules.dart';
import 'requirement_evaluation_rules.dart';

export 'advancement_options.dart';
part 'advancement_apply.dart';

/// Vorschau einer wiederholbaren, noch nicht persistierten Steigerungssitzung.
class AdvancementReplay {
  /// Schützt Befunde vor nachträglicher Mutation durch Aufrufer.
  AdvancementReplay({
    required this.hero,
    required Map<String, String> errors,
    required this.apReserved,
  }) : errors = Map.unmodifiable(errors);
  final HeroSheet hero;
  final Map<String, String> errors;
  final int apReserved;
}

/// Spielt Befehle in Reihenfolge ab; ungültige Schritte bleiben als Befund erhalten.
AdvancementReplay replayAdvancements({
  required HeroSheet base,
  required List<HeroAdvancementEntry> entries,
  required RulesCatalog catalog,
}) {
  var hero = base;
  var reserved = 0;
  final errors = <String, String>{};
  final seen = base.advancementHistory.map((entry) => entry.id).toSet();
  for (final entry in entries) {
    try {
      if (!seen.add(entry.id)) {
        throw StateError('Eintrag wurde bereits übernommen oder geplant.');
      }
      final option = resolveAdvancementOption(
        hero: hero,
        catalog: catalog,
        kind: entry.kind,
        targetId: entry.targetId,
        options: entry.options,
      );
      if (option == null) {
        throw StateError('Steigerungsziel ist nicht im Katalog verfügbar.');
      }
      _validateEntry(hero, entry, option);
      final updated = _applyEntry(hero, entry, option, catalog);
      hero = updated.copyWith(
        apSpent: hero.apSpent + entry.apCost,
        apAvailable: hero.apAvailable - entry.apCost,
      );
      reserved += entry.apCost;
    } on StateError catch (error) {
      errors[entry.id] = error.message.toString();
    }
  }
  return AdvancementReplay(hero: hero, errors: errors, apReserved: reserved);
}

/// Übernimmt ausschließlich eine vollständig gültige Runde samt unveränderlicher Historie.
HeroSheet commitAdvancements({
  required HeroSheet base,
  required List<HeroAdvancementEntry> entries,
  required RulesCatalog catalog,
}) {
  final replay = replayAdvancements(
    base: base,
    entries: entries,
    catalog: catalog,
  );
  if (replay.errors.isNotEmpty) throw StateError(replay.errors.values.first);
  return replay.hero.copyWith(
    advancementHistory: List.unmodifiable([
      ...base.advancementHistory,
      ...entries,
    ]),
  );
}

// Die bestätigten Kosten dürfen Hausregeln enthalten, aber niemals AP oder SE erzeugen.
void _validateEntry(
  HeroSheet hero,
  HeroAdvancementEntry entry,
  AdvancementOption option,
) {
  if (entry.id.isEmpty || entry.sessionId.isEmpty) {
    throw StateError('Eintragskennung fehlt.');
  }
  if (entry.apCost < 0 || entry.apCost > hero.apAvailable) {
    throw StateError('Nicht genügend AP oder ungültige AP-Kosten.');
  }
  if (option.unavailableReason != null) {
    throw StateError(option.unavailableReason!);
  }
  if (entry.seSpent < 0 || entry.seSpent > option.seAvailable) {
    throw StateError('Nicht genügend Sondererfahrungen.');
  }
  if (option.isValueAdvancement) {
    if (entry.fromValue != option.currentValue) {
      throw StateError('Ausgangswert hat sich geändert. Bitte neu planen.');
    }
    final target = entry.toValue;
    if (target == null ||
        target < 0 ||
        target <= option.currentValue ||
        target > option.maxValue) {
      throw StateError('Zielwert liegt außerhalb der erlaubten Steigerung.');
    }
    if (entry.seSpent > target - option.currentValue) {
      throw StateError('Mehr Sondererfahrungen als Steigerungsschritte.');
    }
    return;
  }
  if (entry.seSpent != 0 || entry.fromValue != null || entry.toValue != null) {
    throw StateError(
      'Sonderfertigkeiten verwenden keine numerischen Steigerungsschritte.',
    );
  }
  final def = option.ability!;
  if (def is SpecialAbilityDef && def.mehrfachwaehlbar) {
    final variant = entry.options['variant']?.trim() ?? '';
    if (variant.isEmpty) throw StateError('Bitte eine Variante wählen.');
    if (!def.variantenFreitext && !def.alleVarianten.contains(variant)) {
      throw StateError('Diese Variante ist nicht verfügbar.');
    }
  }
  if (!alleVoraussetzungenErfuellt(option.requirements) &&
      entry.options['meisterentscheid'] != 'true') {
    throw StateError(
      'Voraussetzungen fehlen; ein ausdrücklicher Meisterentscheid ist erforderlich.',
    );
  }
}

/// Erlaubte AT-Zuwächse; die übrigen Punkte gehen bei Nahkampf an PA.
List<int> advancementCombatAllocations({
  required HeroSheet hero,
  required RulesCatalog catalog,
  required String targetId,
  required int fromValue,
  required int toValue,
}) {
  final def = catalog.talents.where((item) => item.id == targetId).firstOrNull;
  if (def == null || def.type != 'nahkampf') return const [];
  final delta = toValue - (fromValue < 0 ? 0 : fromValue);
  if (delta < 0) return const [];
  return List.generate(delta + 1, (index) => index);
}
