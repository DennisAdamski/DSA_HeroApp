/// Geführte Erfassung bereits enthaltener magischer Kenntnisse ohne AP-Buchung.
library;

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';

import 'tradition_rules.dart';

/// Vollständige, noch nicht gespeicherte Entscheidung zur magischen Einrichtung.
class MagicSetupChoice {
  /// Hält die Auswahl einschließlich ausdrücklich zusammenzuführender Gruppen.
  const MagicSetupChoice({
    required this.traditionId,
    required this.includeRepresentation,
    required this.includeRitualKnowledge,
    this.startValue = 3,
    this.sourceCategoryId,
    this.categoryIds = const [],
  });

  final String traditionId;
  final bool includeRepresentation;
  final bool includeRitualKnowledge;
  final int startValue;
  final String? sourceCategoryId;
  final List<String> categoryIds;
}

/// Ergänzt fehlende enthaltene Kenntnisse und bindet nur gewählte Gruppen an.
///
/// Vorhandene gemeinsame Werte bleiben maßgeblich. Die Quelle einer neuen
/// gemeinsamen Kenntnis muss bei unterschiedlichen Altwerten bewusst gewählt
/// werden; bloßes Laden oder Speichern führt niemals Kategorien zusammen.
HeroSheet applyMagicSetup(HeroSheet hero, MagicSetupChoice choice) {
  final tradition = traditionById(choice.traditionId);
  if (tradition == null) throw StateError('Unbekannte magische Tradition.');
  if (choice.includeRitualKnowledge && tradition.ritualKnowledgeName.isEmpty) {
    throw StateError(
      'Diese Tradition besitzt keine gemeinsame Ritualkenntnis.',
    );
  }
  if (choice.startValue < 0 || choice.startValue > 9999) {
    throw StateError('Ungültiger Startwert der Ritualkenntnis.');
  }
  final sources = hero.ritualCategories
      .where((category) => category.id == choice.sourceCategoryId)
      .toList();
  if (choice.sourceCategoryId != null &&
      (sources.length != 1 ||
          sources.single.ownKnowledge == null ||
          sources.single.knowledgeMode !=
              HeroRitualKnowledgeMode.ownKnowledge)) {
    throw StateError('Die gewählte Ritualkenntnis wurde inzwischen geändert.');
  }
  final selected = choice.categoryIds.toSet();
  final actual = hero.ritualCategories.map((category) => category.id).toSet();
  if (!actual.containsAll(selected)) {
    throw StateError('Eine gewählte Ritualgruppe fehlt inzwischen.');
  }
  if (selected.isNotEmpty && !choice.includeRitualKnowledge) {
    throw StateError('Zuordnung erfordert eine gemeinsame Ritualkenntnis.');
  }
  final representations = List<String>.of(hero.representationen);
  final traditions = Map<String, String>.of(hero.repraesentationsTraditionen);
  if (choice.includeRepresentation && tradition.repraesentation.isNotEmpty) {
    if (!representations.contains(tradition.repraesentation)) {
      representations.add(tradition.repraesentation);
    }
    final existing = traditions[tradition.repraesentation];
    if (existing != null && existing != choice.traditionId) {
      throw StateError(
        'Die Repräsentation ist bereits einer anderen Tradition zugeordnet.',
      );
    }
    traditions[tradition.repraesentation] = choice.traditionId;
  }
  final knowledge = Map<String, HeroRitualKnowledge>.of(hero.ritualKnowledge);
  if (choice.sourceCategoryId != null && knowledge.containsKey(tradition.id)) {
    throw StateError(
      'Die gemeinsame Kenntnis ist bereits maßgeblich; '
      'eine andere Quelle muss separat abgeglichen werden.',
    );
  }
  if (choice.includeRitualKnowledge && !knowledge.containsKey(tradition.id)) {
    final legacy = sources.isEmpty ? null : sources.single.ownKnowledge;
    knowledge[tradition.id] =
        legacy?.copyWith(name: tradition.ritualKnowledgeName) ??
        HeroRitualKnowledge(
          name: tradition.ritualKnowledgeName,
          value: choice.startValue,
          learningComplexity: tradition.ritualLearningComplexity,
        );
  }
  final categories = hero.ritualCategories.map((category) {
    if (!selected.contains(category.id)) return category;
    if (category.knowledgeMode == HeroRitualKnowledgeMode.derivedTalents) {
      throw StateError(
        'Talentbasierte Gruppen werden nicht in Ritualkenntnisse umgewandelt.',
      );
    }
    if (category.knowledgeMode == HeroRitualKnowledgeMode.traditionKnowledge &&
        category.traditionId != tradition.id) {
      throw StateError(
        'Diese Ritualgruppe ist bereits einer anderen Tradition zugeordnet.',
      );
    }
    // Der alte Wert bleibt als Archiv erhalten; ausgewertet wird nur der Bezug.
    return category.copyWith(
      knowledgeMode: HeroRitualKnowledgeMode.traditionKnowledge,
      traditionId: tradition.id,
    );
  }).toList();
  return hero.copyWith(
    representationen: representations,
    repraesentationsTraditionen: traditions,
    ritualKnowledge: knowledge,
    ritualCategories: categories,
  );
}

/// Ob ein neu erfasster Vorteil die geführte Einrichtung anbieten soll.
bool offersMagicSetup(String? traitId) =>
    traitId == 'adv_vollzauberer' || traitId == 'adv_halbzauberer';

/// Reserviert bereits im Editor gebuchte AP auch für nachfolgende Erwerbsprüfungen.
HeroSheet withMagicSetupApBudget(HeroSheet hero, {required int apSpent}) {
  final difference = apSpent - hero.apSpent;
  return hero.copyWith(
    apSpent: apSpent,
    apAvailable: (hero.apAvailable - difference).clamp(0, 999999999),
  );
}
