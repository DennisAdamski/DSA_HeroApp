import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

/// Gueltige Lernkomplexitaeten fuer eigenstaendige Ritualkenntnisse.
const List<String> kRitualKnowledgeComplexities = <String>[
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
];

/// Aufgeloester Talentbezug einer talentbasierten Ritualkategorie.
class ResolvedRitualTalent {
  /// Erzeugt einen unveraenderlichen Talentbezug fuer die Ritualanzeige.
  const ResolvedRitualTalent({
    required this.talentId,
    required this.talentName,
    required this.talentValue,
  });

  /// Referenzierte Talent-ID.
  final String talentId;

  /// Angezeigter Talentname.
  final String talentName;

  /// Aktueller TaW des referenzierten Talents.
  final int talentValue;
}

/// Erzeugt die Standard-Ritualkenntnis fuer eine neue Kategorie.
HeroRitualKnowledge buildDefaultRitualKnowledge(
  String categoryName, {
  int value = 3,
  String learningComplexity = 'E',
}) {
  return HeroRitualKnowledge(
    name: categoryName.trim(),
    value: value,
    learningComplexity: _normalizeLearningComplexity(learningComplexity),
  );
}

/// Normalisiert alle Ritualkategorien eines Helden fuer die Persistenz.
List<HeroRitualCategory> normalizeRitualCategories(
  Iterable<HeroRitualCategory> categories,
) {
  final seenIds = <String>{};
  final normalized = <HeroRitualCategory>[];
  for (final category in categories) {
    final normalizedCategory = normalizeRitualCategory(category);
    final id = normalizedCategory.id.trim();
    if (id.isEmpty || seenIds.contains(id)) {
      continue;
    }
    seenIds.add(id);
    normalized.add(normalizedCategory.copyWith(id: id));
  }
  return List<HeroRitualCategory>.unmodifiable(normalized);
}

/// Normalisiert eine einzelne Ritualkategorie inkl. Ritualen und Zusatzfeldern.
HeroRitualCategory normalizeRitualCategory(HeroRitualCategory category) {
  final normalizedName = category.name.trim();
  final normalizedFieldDefs = normalizeRitualFieldDefs(
    category.additionalFieldDefs,
  );
  final normalizedRituals = category.rituals
      .map((entry) {
        return normalizeRitualEntry(entry, fieldDefs: normalizedFieldDefs);
      })
      .toList(growable: false);

  switch (category.knowledgeMode) {
    case HeroRitualKnowledgeMode.ownKnowledge:
      final ownKnowledge =
          category.ownKnowledge ?? buildDefaultRitualKnowledge(normalizedName);
      return category.copyWith(
        id: category.id.trim(),
        name: normalizedName,
        ownKnowledge: ownKnowledge.copyWith(
          name: normalizedName,
          learningComplexity: _normalizeLearningComplexity(
            ownKnowledge.learningComplexity,
          ),
        ),
        derivedTalentIds: const <String>[],
        additionalFieldDefs: normalizedFieldDefs,
        rituals: normalizedRituals,
      );
    case HeroRitualKnowledgeMode.derivedTalents:
      return category.copyWith(
        id: category.id.trim(),
        name: normalizedName,
        ownKnowledge: null,
        derivedTalentIds: normalizeRitualTalentIds(category.derivedTalentIds),
        additionalFieldDefs: normalizedFieldDefs,
        rituals: normalizedRituals,
      );
  }
}

/// Normalisiert ein einzelnes Ritual anhand der gueltigen Felddefinitionen.
HeroRitualEntry normalizeRitualEntry(
  HeroRitualEntry entry, {
  required List<HeroRitualFieldDef> fieldDefs,
}) {
  return entry.copyWith(
    name: entry.name.trim(),
    wirkung: entry.wirkung.trim(),
    kosten: entry.kosten.trim(),
    wirkungsdauer: entry.wirkungsdauer.trim(),
    merkmale: entry.merkmale.trim(),
    zauberdauer: entry.zauberdauer.trim(),
    zielobjekt: entry.zielobjekt.trim(),
    reichweite: entry.reichweite.trim(),
    technik: entry.technik.trim(),
    additionalFieldValues: normalizeRitualFieldValues(
      entry.additionalFieldValues,
      fieldDefs: fieldDefs,
    ),
  );
}

/// Normalisiert die definierte Talentliste einer talentbasierten Kategorie.
List<String> normalizeRitualTalentIds(Iterable<String> talentIds) {
  final seenIds = <String>{};
  final normalized = <String>[];
  for (final talentId in talentIds) {
    final trimmed = talentId.trim();
    if (trimmed.isEmpty || seenIds.contains(trimmed)) {
      continue;
    }
    seenIds.add(trimmed);
    normalized.add(trimmed);
  }
  return List<String>.unmodifiable(normalized);
}

/// Normalisiert frei definierte Zusatzfelder einer Ritualkategorie.
List<HeroRitualFieldDef> normalizeRitualFieldDefs(
  Iterable<HeroRitualFieldDef> fieldDefs,
) {
  final seenIds = <String>{};
  final normalized = <HeroRitualFieldDef>[];
  for (final fieldDef in fieldDefs) {
    final id = fieldDef.id.trim();
    final label = fieldDef.label.trim();
    if (id.isEmpty || label.isEmpty || seenIds.contains(id)) {
      continue;
    }
    seenIds.add(id);
    normalized.add(fieldDef.copyWith(id: id, label: label));
  }
  return List<HeroRitualFieldDef>.unmodifiable(normalized);
}

/// Normalisiert die Werte frei definierter Ritualfelder gegen ihre Definitionen.
List<HeroRitualFieldValue> normalizeRitualFieldValues(
  Iterable<HeroRitualFieldValue> values, {
  required List<HeroRitualFieldDef> fieldDefs,
}) {
  final rawById = <String, HeroRitualFieldValue>{};
  for (final value in values) {
    final id = value.fieldDefId.trim();
    if (id.isEmpty) {
      continue;
    }
    rawById[id] = value.copyWith(fieldDefId: id);
  }

  final normalized = <HeroRitualFieldValue>[];
  for (final fieldDef in fieldDefs) {
    final rawValue = rawById[fieldDef.id];
    if (rawValue == null) {
      continue;
    }
    final normalizedValue = _normalizeFieldValue(fieldDef, rawValue);
    if (normalizedValue != null) {
      normalized.add(normalizedValue);
    }
  }
  return List<HeroRitualFieldValue>.unmodifiable(normalized);
}

/// Normalisiert eine Dreierliste von Eigenschaftscodes auf die kanonischen IDs.
///
/// Ungueltige oder leere Eintraege werden verworfen. Es werden nur vollstaendige
/// Dreierlisten akzeptiert.
List<String> normalizeRitualAttributeCodes(Iterable<String> attributeCodes) {
  final normalized = <String>[];
  for (final rawCode in attributeCodes) {
    final parsed = parseAttributeCode(rawCode);
    if (parsed == null) {
      continue;
    }
    normalized.add(_attributeCodeToLabel(parsed));
    if (normalized.length == 3) {
      break;
    }
  }
  if (normalized.length != 3) {
    return const <String>[];
  }
  return List<String>.unmodifiable(normalized);
}

/// Loest die referenzierten Talente einer Ritualkategorie fuer die UI auf.
List<ResolvedRitualTalent> resolveDerivedRitualTalents({
  required HeroRitualCategory category,
  required List<TalentDef> catalogTalents,
  required Map<String, HeroTalentEntry> heroTalents,
}) {
  if (category.knowledgeMode != HeroRitualKnowledgeMode.derivedTalents) {
    return const <ResolvedRitualTalent>[];
  }

  final talentNamesById = <String, String>{};
  for (final talent in catalogTalents) {
    talentNamesById[talent.id] = talent.name;
  }

  return normalizeRitualTalentIds(category.derivedTalentIds)
      .map((talentId) {
        final talentName = talentNamesById[talentId] ?? talentId;
        final talentValue = heroTalents[talentId]?.talentValue ?? 0;
        return ResolvedRitualTalent(
          talentId: talentId,
          talentName: talentName,
          talentValue: talentValue,
        );
      })
      .toList(growable: false);
}

HeroRitualFieldValue? _normalizeFieldValue(
  HeroRitualFieldDef fieldDef,
  HeroRitualFieldValue value,
) {
  switch (fieldDef.type) {
    case HeroRitualFieldType.text:
      final textValue = value.textValue.trim();
      if (textValue.isEmpty) {
        return null;
      }
      return value.copyWith(
        fieldDefId: fieldDef.id,
        textValue: textValue,
        attributeCodes: const <String>[],
      );
    case HeroRitualFieldType.threeAttributes:
      final attributeCodes = normalizeRitualAttributeCodes(
        value.attributeCodes,
      );
      if (attributeCodes.isEmpty) {
        return null;
      }
      return value.copyWith(
        fieldDefId: fieldDef.id,
        textValue: '',
        attributeCodes: attributeCodes,
      );
  }
}

String _normalizeLearningComplexity(String raw) {
  final normalized = raw.trim().toUpperCase();
  if (kRitualKnowledgeComplexities.contains(normalized)) {
    return normalized;
  }
  return 'E';
}

String _attributeCodeToLabel(AttributeCode code) {
  switch (code) {
    case AttributeCode.mu:
      return 'MU';
    case AttributeCode.kl:
      return 'KL';
    case AttributeCode.inn:
      return 'IN';
    case AttributeCode.ch:
      return 'CH';
    case AttributeCode.ff:
      return 'FF';
    case AttributeCode.ge:
      return 'GE';
    case AttributeCode.ko:
      return 'KO';
    case AttributeCode.kk:
      return 'KK';
  }
}
