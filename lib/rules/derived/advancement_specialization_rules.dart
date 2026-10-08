import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

import 'advancement_options.dart';
import 'learning_rules.dart';

/// Liest auch Spezialisierungen aus älteren Freitext-Einträgen verlustfrei.
List<String> advancementTalentSpecializations(HeroTalentEntry entry) {
  final names = entry.combatSpecializations.isNotEmpty
      ? entry.combatSpecializations
      : entry.specializations.split(RegExp(r'[\n,;]+'));
  return _normalizeNames(names);
}

/// Liefert die vorhandenen Waffenkategorien als Auswahl für Kampftalente.
List<String> advancementSpecializationChoices(
  AdvancementContext context,
  String talentId,
) {
  final def = context.catalog.talents
      .where((def) => def.id == talentId)
      .firstOrNull;
  if (def == null) return const [];
  final names = def.weaponCategory.split(RegExp(r'[\n,;]+'));
  return _normalizeNames(names);
}

// Doppelte und leere Legacy-Namen dürfen die Erwerbsstaffel nicht erhöhen.
List<String> _normalizeNames(Iterable<String> names) {
  final normalized = <String>{};
  for (final name in names) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) normalized.add(trimmed);
  }
  return normalized.toList();
}

/// Prüft Erwerb und Kosten gegen den Vorschau-TaW, unabhängig vom Steigerungsmaximum.
AdvancementOption? resolveTalentSpecialization(
  AdvancementContext context,
  String talentId,
  Map<String, String> options,
) {
  final def = context.catalog.talents
      .where((def) => def.id == talentId)
      .firstOrNull;
  if (def == null) return null;
  final entry = context.hero.talents[talentId];
  if (entry == null || entry.talentValue == null) return null;
  final specs = advancementTalentSpecializations(entry);
  final required = requiredTawForSpecialization(specs.length);
  final name = options['specialization']?.trim() ?? '';
  final choices = advancementSpecializationChoices(context, talentId);
  final befund = context.begabungen.talent(def);
  final cost = talentSpecializationApCost(
    basisKomplexitaet: def.steigerung,
    gifted: befund.istBegabt(gifted: entry.gifted),
    unfaehigkeitsSchritte: befund.erhoehung,
    specializationOrdinal: specs.length + 1,
  );
  String? reason;
  if (entry.talentValue! < required) {
    reason = 'Für die nächste Spezialisierung wird TaW $required benötigt.';
  } else if (options.containsKey('specialization') &&
      (name.isEmpty || name.contains(RegExp(r'[\n,;]')))) {
    reason = 'Bitte genau einen Namen für die Spezialisierung angeben.';
  } else if (specs.any((spec) => spec.toLowerCase() == name.toLowerCase())) {
    reason = 'Diese Spezialisierung wurde bereits gelernt oder vorgemerkt.';
  } else if (name.isNotEmpty && choices.isNotEmpty && !choices.contains(name)) {
    reason = 'Bitte eine passende Waffenkategorie wählen.';
  }
  return AdvancementOption(
    kind: AdvancementKind.talent,
    targetId: talentId,
    label: '${def.name}: $name',
    options: {...options, 'action': 'specialization', 'specialization': name},
    isOwned: true,
    apCost: cost,
    currentValue: entry.talentValue!,
    complexityHint:
        'TaW ≥ $required nötig; ohne Lehrmeister doppelte Kosten '
        '(Wege des Schwerts S. 17)',
    unavailableReason: reason,
  );
}
