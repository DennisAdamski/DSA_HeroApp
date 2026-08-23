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
  // Ein leerer `{choice}` in Klammern soll keine leere Klammer hinterlassen:
  // `Guter Ruf 4 ()` waere kein sinnvoller Anzeigetext.
  result = result.replaceAll(RegExp(r'\s*\(\s*\)'), '');
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
  return result;
}

/// Zerlegung eines gespeicherten Fragments in seine Template-Bestandteile.
class HeroTraitFragmentParts {
  const HeroTraitFragmentParts({this.choice = '', this.value});

  /// Der `{choice}`-Anteil, leer wenn das Template keinen hat oder er fehlte.
  final String choice;

  /// Der `{value}`-Anteil, `null` wenn das Template keinen hat.
  final int? value;
}

/// Zerlegt ein gespeichertes Fragment anhand des `selectionTemplate` eines
/// Katalogeintrags — die Umkehrung von [buildHeroTraitSelectionText]. Liefert
/// `null`, wenn das Fragment nicht zum Template passt.
///
/// Eine Klammergruppe, die nur `{choice}` enthaelt, gilt als optional. Sonst
/// wuerde ein Bestandsfragment wie `Guter Ruf 4` gegen das erweiterte Template
/// `Guter Ruf {value} ({choice})` nicht mehr matchen.
HeroTraitFragmentParts? parseTraitFragmentParts(
  String fragment,
  HeroTraitDef trait,
) {
  var template = trait.selectionTemplate.trim();
  if (template.isEmpty) {
    template = trait.name.trim();
  }
  template = template.replaceAll(RegExp(r'\s+'), ' ');

  final tokenPattern = RegExp(r'\{value\}|\s*\(\{choice\}\)|\{choice\}');
  final buffer = StringBuffer('^');
  var lastEnd = 0;
  var valueGroupIndex = 0;
  var choiceGroupIndex = 0;
  var groupCount = 0;
  for (final tokenMatch in tokenPattern.allMatches(template)) {
    buffer.write(RegExp.escape(template.substring(lastEnd, tokenMatch.start)));
    final token = tokenMatch.group(0)!;
    if (token == '{value}') {
      groupCount++;
      valueGroupIndex = groupCount;
      buffer.write(r'(-?\d+)');
    } else if (token == '{choice}') {
      groupCount++;
      choiceGroupIndex = groupCount;
      buffer.write('(.*?)');
    } else {
      // Klammergruppe mit ausschliesslich `{choice}` — optionaler Teil.
      groupCount++;
      choiceGroupIndex = groupCount;
      buffer.write(r'(?:\s*\((.*?)\))?');
    }
    lastEnd = tokenMatch.end;
  }
  buffer.write(RegExp.escape(template.substring(lastEnd)));
  buffer.write(r'$');

  final regex = RegExp(buffer.toString());
  final normalizedFragment = fragment.trim().replaceAll(RegExp(r'\s+'), ' ');
  final match = regex.firstMatch(normalizedFragment);
  if (match == null) {
    return null;
  }
  return HeroTraitFragmentParts(
    choice: choiceGroupIndex == 0
        ? ''
        : (match.group(choiceGroupIndex) ?? '').trim(),
    value: valueGroupIndex == 0
        ? null
        : int.tryParse(match.group(valueGroupIndex) ?? ''),
  );
}

/// Extrahiert den numerischen Wert aus einem gespeicherten Fragment anhand
/// des `selectionTemplate` eines Katalogeintrags. Liefert `null`, wenn das
/// Template kein `{value}` enthaelt oder das Fragment nicht dazu passt.
int? parseTraitFragmentValue(String fragment, HeroTraitDef trait) {
  var template = trait.selectionTemplate.trim();
  if (template.isEmpty) {
    template = trait.name.trim();
  }
  if (!template.contains('{value}')) {
    return null;
  }
  return parseTraitFragmentParts(fragment, trait)?.value;
}

/// Fuegt ein Fragment hinzu und fasst dabei die gleiche Auswahl desselben
/// Katalogeintrags zu einem Eintrag mit summiertem Wert zusammen.
///
/// Ohne diese Zusammenfassung verschluckt [serializeHeroTraitFragments] den
/// zweiten Erwerb still, weil es identische Strings verwirft — und der Nutzer
/// hat ueber den Erwerbsdialog unter Umstaenden schon AP dafuer bezahlt.
/// Greift nur bei Templates mit `{choice}` **und** `{value}`; sonst wird das
/// Fragment schlicht angehaengt.
List<String> mergeHeroTraitFragment({
  required List<String> fragments,
  required String fragment,
  required HeroTraitDef trait,
}) {
  final result = List<String>.from(fragments);
  final addition = fragment.trim();
  if (addition.isEmpty) {
    return result;
  }

  final template = trait.selectionTemplate.trim();
  if (!template.contains('{choice}') || !template.contains('{value}')) {
    result.add(addition);
    return result;
  }

  final incoming = parseTraitFragmentParts(addition, trait);
  if (incoming == null || incoming.value == null) {
    result.add(addition);
    return result;
  }

  for (var index = 0; index < result.length; index++) {
    final existing = parseTraitFragmentParts(result[index], trait);
    if (existing == null || existing.value == null) {
      continue;
    }
    if (_normalizeTraitText(existing.choice) !=
        _normalizeTraitText(incoming.choice)) {
      continue;
    }
    result[index] = buildHeroTraitSelectionText(
      trait: trait,
      choice: incoming.choice,
      value: existing.value! + incoming.value!,
    );
    return result;
  }

  result.add(addition);
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
