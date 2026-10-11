import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Löst eine eigene oder gemeinsam gespeicherte Ritualkenntnis auf.
///
/// Fehlende Traditionsbezüge bleiben fehlend; insbesondere entsteht dadurch
/// keine Ersatzkenntnis. Talentbasierte Kategorien haben keine eigene Kenntnis.
HeroRitualKnowledge? resolveRitualKnowledge(
  HeroSheet hero,
  HeroRitualCategory category,
) {
  switch (category.knowledgeMode) {
    case HeroRitualKnowledgeMode.ownKnowledge:
      return category.ownKnowledge;
    case HeroRitualKnowledgeMode.traditionKnowledge:
      return hero.ritualKnowledge[category.traditionId];
    case HeroRitualKnowledgeMode.derivedTalents:
      return null;
  }
}
