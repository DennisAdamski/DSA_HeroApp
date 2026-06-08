import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';

/// Zerlegt den Freitext aus dem Katalogfeld `voraussetzungen` in strukturierte
/// [SkillRequirement]s.
///
/// Bewusst tolerant: Nicht eindeutig auswertbare Segmente werden als
/// [UnknownRequirement] gefuehrt, damit die nachgelagerte Bewertung sicher
/// degradieren kann (lieber „unbestimmt“ als faelschlich „lernbar“).
List<SkillRequirement> parseVoraussetzungen(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return const <SkillRequirement>[];
  }

  final result = <SkillRequirement>[];
  // Auf oberster Ebene an ';' und ',' trennen.
  final segments = text
      .split(RegExp(r'[;,]'))
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty);

  var sfContext = false;
  for (final segment in segments) {
    // Innerhalb eines Segments trennt „und“ weitere Teile.
    final parts = segment
        .split(RegExp(r'\s+und\s+', caseSensitive: false))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    for (final part in parts) {
      final parsed = _parsePart(part, sfContext: sfContext);
      result.add(parsed.requirement);
      sfContext = parsed.sfContext;
    }
  }
  return result;
}

/// Interne Eigenschaftskuerzel je Regelwerks-Abkuerzung.
const Map<String, String> _attributeKeys = <String, String>{
  'MU': 'mu',
  'KL': 'kl',
  'IN': 'inn',
  'CH': 'ch',
  'FF': 'ff',
  'GE': 'ge',
  'KO': 'ko',
  'KK': 'kk',
};

final RegExp _attributeWithValue = RegExp(
  r'^(MU|KL|IN|CH|FF|GE|KO|KK)\s+(\d+)$',
  caseSensitive: false,
);
final RegExp _bareAttribute = RegExp(
  r'^(MU|KL|IN|CH|FF|GE|KO|KK)$',
  caseSensitive: false,
);
final RegExp _taw = RegExp(r'^TaW\s+(.+?)\s+(\d+)$', caseSensitive: false);
final RegExp _zfw = RegExp(r'^ZfW\s+(.+?)\s+(\d+)$', caseSensitive: false);
// Talentname ohne Praefix: nur Buchstaben/Leerzeichen, gefolgt von Wert.
final RegExp _bareTalent = RegExp(r'^([A-Za-zÄÖÜäöüß ]+?)\s+(\d+)$');

class _PartResult {
  const _PartResult(this.requirement, {required this.sfContext});

  final SkillRequirement requirement;
  final bool sfContext;
}

_PartResult _parsePart(String part, {required bool sfContext}) {
  // Oder-Verknuepfung zuerst behandeln; sie hebt den SF-Kontext auf.
  if (RegExp(r'\s+oder\s+', caseSensitive: false).hasMatch(part)) {
    return _PartResult(_parseOr(part), sfContext: false);
  }

  final sfMatch = RegExp(r'^SF\s+(.+)$', caseSensitive: false).firstMatch(part);
  if (sfMatch != null) {
    return _PartResult(
      AbilityRequirement(sfMatch.group(1)!.trim()),
      sfContext: true,
    );
  }

  final single = _parseSingle(part, sfContext: sfContext);
  // SF-Kontext bleibt erhalten, solange Fortsetzungen weiter SF-Namen sind.
  return _PartResult(single, sfContext: single is AbilityRequirement);
}

/// Parst ein einzelnes Teilsegment ohne Oder- und SF-Praefix-Behandlung.
SkillRequirement _parseSingle(String part, {bool sfContext = false}) {
  final attr = _attributeWithValue.firstMatch(part);
  if (attr != null) {
    final key = _attributeKeys[attr.group(1)!.toUpperCase()]!;
    return AttributeRequirement(key, int.parse(attr.group(2)!));
  }

  final taw = _taw.firstMatch(part);
  if (taw != null) {
    return TalentRequirement(taw.group(1)!.trim(), int.parse(taw.group(2)!));
  }

  final zfw = _zfw.firstMatch(part);
  if (zfw != null) {
    return SpellRequirement(zfw.group(1)!.trim(), int.parse(zfw.group(2)!));
  }

  final vorteil = RegExp(
    r'^Vorteil\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(part);
  if (vorteil != null) {
    return TraitRequirement(vorteil.group(1)!.trim());
  }

  final rasse = RegExp(
    r'^Rasse\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(part);
  if (rasse != null) {
    return RaceRequirement(rasse.group(1)!.trim());
  }

  // Fortsetzung innerhalb eines „SF …“-Kontexts: schlichter Name → Ability.
  if (sfContext && RegExp(r'^[A-Za-zÄÖÜäöüß ()]+$').hasMatch(part)) {
    return AbilityRequirement(part);
  }

  final bareTalent = _bareTalent.firstMatch(part);
  if (bareTalent != null) {
    return TalentRequirement(
      bareTalent.group(1)!.trim(),
      int.parse(bareTalent.group(2)!),
    );
  }

  return UnknownRequirement(part);
}

/// Parst eine „… oder …“-Verknuepfung in eine [OrRequirement].
SkillRequirement _parseOr(String part) {
  final rawOptions = part
      .split(RegExp(r'\s+oder\s+', caseSensitive: false))
      .map((option) => option.trim())
      .where((option) => option.isNotEmpty)
      .toList(growable: false);

  // Gemeinsamen Eigenschaftswert (am Ende stehend) ermitteln.
  int? sharedAttributeValue;
  for (final option in rawOptions) {
    final attr = _attributeWithValue.firstMatch(option);
    if (attr != null) {
      sharedAttributeValue = int.parse(attr.group(2)!);
    }
  }

  final options = <SkillRequirement>[];
  for (final option in rawOptions) {
    final bare = _bareAttribute.firstMatch(option);
    if (bare != null) {
      final key = _attributeKeys[bare.group(1)!.toUpperCase()]!;
      options.add(AttributeRequirement(key, sharedAttributeValue ?? 0));
      continue;
    }
    final sfMatch = RegExp(
      r'^SF\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(option);
    if (sfMatch != null) {
      options.add(AbilityRequirement(sfMatch.group(1)!.trim()));
      continue;
    }
    options.add(_parseSingle(option));
  }
  return OrRequirement(options);
}
