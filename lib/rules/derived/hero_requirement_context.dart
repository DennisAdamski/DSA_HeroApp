/// Baut den Pruefkontext fuer Erwerbsvoraussetzungen aus einem Helden.
///
/// Getrennt von `requirement_evaluation_rules.dart`, damit die eigentliche
/// Auswertung ohne Abhaengigkeit auf Heldenmodell und Katalog testbar bleibt.
/// Der Katalog wird gebraucht, weil der Held Talente und Zauber nur unter
/// ihrer ID kennt (`tal_magiekunde`), die Regelwerke ihre Voraussetzungen aber
/// mit Klarnamen formulieren (`TaW Magiekunde 11`).
library;

import 'package:dsa_heldenverwaltung/catalog/hero_trait_text.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tradition_rules.dart';

/// Baut den Pruefkontext eines Helden.
///
/// [catalog] darf `null` sein; dann bleiben Zauber- und Talentwerte leer und
/// die betroffenen Voraussetzungen melden „nicht vorhanden“ statt zu raten.
HeroRequirementContext buildHeroRequirementContext(
  HeroSheet hero, {
  RulesCatalog? catalog,
}) {
  final ritualkenntnisse = _ritualkenntnisse(hero, catalog: catalog);
  return HeroRequirementContext(
    eigenschaften: <String, int>{
      for (final code in AttributeCode.values)
        attributeCodeKey(code): readAttributeValue(hero.attributes, code),
    },
    sonderfertigkeiten: heroSpecialAbilityNames(hero, catalog: catalog),
    zauberwerte: _werteNachName(
      eintraege: hero.spells.map(
        (id, entry) => MapEntry(id, entry.spellValue),
      ),
      namenNachId: <String, String>{
        for (final spell in catalog?.spells ?? const []) spell.id: spell.name,
      },
    ),
    talentwerte: _werteNachName(
      eintraege: hero.talents.map(
        (id, entry) => MapEntry(id, entry.talentValue),
      ),
      namenNachId: <String, String>{
        for (final talent in catalog?.talents ?? const [])
          talent.id: talent.name,
      },
    ),
    ritualkenntnisse: ritualkenntnisse,
    traditionen: resolveHeroTraditionen(
      repraesentationen: hero.representationen,
      gewaehlteTraditionen: hero.repraesentationsTraditionen,
      ritualkenntnisse: ritualkenntnisse.keys,
    ),
    merkmalskenntnisse: hero.merkmalskenntnisse,
    vorteile: splitHeroTraitText(hero.vorteileText),
    nachteile: splitHeroTraitText(hero.nachteileText),
    rasse: hero.background.rasse,
    leiteigenschaftOverride: hero.magicLeadAttribute,
  );
}

/// Sammelt die Namen aller erworbenen Sonderfertigkeiten eines Helden.
///
/// Allgemeine und magische Sonderfertigkeiten stehen als Klartext im
/// Heldenmodell; Kampf-Sonderfertigkeiten nur als Katalog-ID und werden
/// deshalb ueber [catalog] aufgeloest.
List<String> heroSpecialAbilityNames(
  HeroSheet hero, {
  RulesCatalog? catalog,
}) {
  final namen = <String>[
    for (final ability in hero.talentSpecialAbilities) ability.name,
    for (final ability in hero.magicSpecialAbilities) ability.name,
  ];
  final kampfNamenNachId = <String, String>{
    for (final ability in catalog?.combatSpecialAbilities ?? const [])
      ability.id: ability.name,
  };
  for (final id in hero.combatConfig.specialRules.activeCombatSpecialAbilityIds) {
    final name = kampfNamenNachId[id];
    if (name != null) {
      namen.add(name);
    }
  }
  return List<String>.unmodifiable(
    namen.where((name) => name.trim().isNotEmpty),
  );
}

/// Uebersetzt „ID → Wert“ in „Name → Wert“ und laesst ungesetzte Werte weg.
Map<String, int> _werteNachName({
  required Map<String, int?> eintraege,
  required Map<String, String> namenNachId,
}) {
  final result = <String, int>{};
  for (final entry in eintraege.entries) {
    final wert = entry.value;
    if (wert == null) {
      continue;
    }
    final name = namenNachId[entry.key] ?? entry.key;
    final vorhanden = result[name];
    if (vorhanden == null || wert > vorhanden) {
      result[name] = wert;
    }
  }
  return result;
}

/// Ritualkenntnisse des Helden als „Name → RkW“.
///
/// Kategorien mit eigener Ritualkenntnis liefern deren Wert; talentbasierte
/// Kategorien den hoechsten TaW ihrer Bezugstalente — genau die Zahl, mit der
/// laut Regelwerk auch die Ritualproben gewuerfelt werden.
Map<String, int> _ritualkenntnisse(HeroSheet hero, {RulesCatalog? catalog}) {
  final result = <String, int>{};
  for (final kategorie in hero.ritualCategories) {
    switch (kategorie.knowledgeMode) {
      case HeroRitualKnowledgeMode.ownKnowledge:
        final kenntnis = kategorie.ownKnowledge;
        if (kenntnis == null) {
          continue;
        }
        final name = kenntnis.name.trim().isEmpty
            ? kategorie.name.trim()
            : kenntnis.name.trim();
        if (name.isNotEmpty) {
          result[name] = kenntnis.value;
        }
      case HeroRitualKnowledgeMode.derivedTalents:
        final name = kategorie.name.trim();
        if (name.isEmpty) {
          continue;
        }
        var bester = 0;
        for (final talentId in kategorie.derivedTalentIds) {
          final wert = hero.talents[talentId]?.talentValue ?? 0;
          if (wert > bester) {
            bester = wert;
          }
        }
        result[name] = bester;
    }
  }
  return result;
}
