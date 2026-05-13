import 'package:dsa_heldenverwaltung/catalog/hero_trait_def.dart';

/// Zerlegt den gespeicherten Vorteil-/Nachteil-Text in einzelne Fragmente.
///
/// Die Funktion nutzt dieselben Trenner wie die vorhandenen Modifier-Parser,
/// damit katalogisierte Auswahlwerte und freie Alttexte kompatibel bleiben.
List<String> splitHeroTraitText(String text) {
  final seen = <String>{};
  final fragments = <String>[];
  for (final raw in text.split(RegExp(r'[\n,;]+'))) {
    final fragment = raw.trim();
    if (fragment.isEmpty || seen.contains(fragment)) {
      continue;
    }
    seen.add(fragment);
    fragments.add(fragment);
  }
  return List<String>.unmodifiable(fragments);
}

/// Serialisiert einzelne Fragmente wieder in das kompatible Freitextformat.
String serializeHeroTraitFragments(Iterable<String> fragments) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final raw in fragments) {
    final fragment = raw.trim();
    if (fragment.isEmpty || seen.contains(fragment)) {
      continue;
    }
    seen.add(fragment);
    normalized.add(fragment);
  }
  return normalized.join('; ');
}

/// Prüft, ob ein Textfragment durch einen der Katalogeinträge abgedeckt ist.
bool isKnownHeroTraitFragment(String fragment, Iterable<HeroTraitDef> traits) {
  final normalizedFragment = _normalizeTraitText(fragment);
  if (normalizedFragment.isEmpty) {
    return false;
  }
  for (final trait in traits) {
    if (!trait.active) {
      continue;
    }
    if (_matchesTraitFragment(normalizedFragment, trait)) {
      return true;
    }
  }
  return false;
}

/// Entfernt bekannte katalogisierte Fragmente aus Parser-Warnungen.
List<String> filterKnownHeroTraitFragments({
  required Iterable<String> fragments,
  required Iterable<HeroTraitDef> advantages,
  required Iterable<HeroTraitDef> disadvantages,
}) {
  final traits = <HeroTraitDef>[...advantages, ...disadvantages];
  return fragments
      .where((fragment) => !isKnownHeroTraitFragment(fragment, traits))
      .toList(growable: false);
}

/// Baut einen speicherkompatiblen Text aus Katalogeintrag und Dialogwerten.
String buildHeroTraitSelectionText({
  required HeroTraitDef trait,
  String choice = '',
  int? value,
}) {
  var template = trait.selectionTemplate.trim();
  if (template.isEmpty) {
    template = trait.name.trim();
  }
  final valueText = value == null ? '' : value.toString();
  final selectedChoice = choice.trim();
  var result = template
      .replaceAll('{choice}', selectedChoice)
      .replaceAll('{value}', valueText);
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
  return result;
}

bool _matchesTraitFragment(String normalizedFragment, HeroTraitDef trait) {
  final patterns = _normalizedPatternsForTrait(trait);
  for (final pattern in patterns) {
    if (pattern.isEmpty) {
      continue;
    }
    if (normalizedFragment == pattern) {
      return true;
    }
    if (normalizedFragment.startsWith('$pattern ')) {
      return true;
    }
  }
  return false;
}

Set<String> _normalizedPatternsForTrait(HeroTraitDef trait) {
  final patterns = <String>{};
  patterns.add(_normalizeTraitText(trait.name));
  final template = trait.selectionTemplate.trim();
  if (template.isNotEmpty) {
    patterns.add(_normalizeTraitText(_templatePrefix(template)));
  }
  patterns.add(_normalizeTraitText(_namePrefix(trait.name)));
  return patterns;
}

String _templatePrefix(String template) {
  final markerIndex = template.indexOf('{');
  if (markerIndex < 0) {
    return template;
  }
  return template.substring(0, markerIndex).trim();
}

String _namePrefix(String name) {
  var result = name.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim();
  result = result.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
  return result;
}

String _normalizeTraitText(String value) {
  var text = value.toLowerCase().trim();
  text = text
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
