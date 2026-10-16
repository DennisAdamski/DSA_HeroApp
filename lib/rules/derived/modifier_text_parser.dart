import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_trait_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/direkter_modifikator_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parse_result.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standard_stat_modifier_rules.dart';

/// Zerlegt freie Texte in einzelne Modifikator-Fragmente und summiert diese.
///
/// Erlaubtes Grundformat pro Fragment: `CODE+N` oder `CODE-N`.
ModifierParseResult parseModifierTexts({
  required String rasseModText,
  required String kulturModText,
  required String professionModText,
  required String vorteileText,
  required String nachteileText,
}) {
  var attrMods = const AttributeModifiers();
  var startAttrMods = const AttributeModifiers();
  var statMods = const StatModifiers();
  final unknown = <String>[];
  final hasFlinkFromVorteile = _containsNamedToken(vorteileText, const {
    'flink',
  });
  final hasBehaebigFromNachteile = _containsNamedToken(nachteileText, const {
    'behaebig',
    'behabig',
  });
  // Umlaute werden zu `a` normalisiert: `Linkshänder` wird `linkshander`.
  final hasLinkshaenderFromVorteile = _containsNamedToken(vorteileText, const {
    'linkshander',
    'linkshaender',
  });

  final allTexts = [
    (
      text: rasseModText,
      allowStandardAdvantages: false,
      allowStandardDisadvantages: false,
      contributesToStartAttributes: true,
    ),
    (
      text: kulturModText,
      allowStandardAdvantages: false,
      allowStandardDisadvantages: false,
      contributesToStartAttributes: true,
    ),
    (
      text: professionModText,
      allowStandardAdvantages: false,
      allowStandardDisadvantages: false,
      contributesToStartAttributes: true,
    ),
    (
      text: vorteileText,
      allowStandardAdvantages: true,
      allowStandardDisadvantages: false,
      contributesToStartAttributes: false,
    ),
    (
      text: nachteileText,
      allowStandardAdvantages: false,
      allowStandardDisadvantages: true,
      contributesToStartAttributes: false,
    ),
  ];

  for (final source in allTexts) {
    final fragments = source.text.split(RegExp(r'[\n,;]+'));
    for (final raw in fragments) {
      final fragment = raw.trim();
      if (fragment.isEmpty) {
        continue;
      }

      final standardModifier = parseStandardStatModifierFragment(
        fragment: fragment,
        allowAdvantages: source.allowStandardAdvantages,
        allowDisadvantages: source.allowStandardDisadvantages,
      );
      if (standardModifier != null) {
        if (standardModifier.hasAmount) {
          statMods = statMods + standardModifier.statMods;
          continue;
        }
        if (!unknown.contains(fragment)) {
          unknown.add(fragment);
        }
        continue;
      }

      final attributeTrait = parseAttributeTraitFragment(
        fragment: fragment,
        allowAdvantages: source.allowStandardAdvantages,
        allowDisadvantages: source.allowStandardDisadvantages,
      );
      if (attributeTrait != null) {
        if (!attributeTrait.hasAttribute) {
          if (!unknown.contains(fragment)) {
            unknown.add(fragment);
          }
          continue;
        }
        attrMods = attrMods + attributeTrait.attributeMods;
        if (attributeTrait.raisesStartValue) {
          startAttrMods = startAttrMods + attributeTrait.attributeMods;
        }
        continue;
      }

      final direkt = erkenneDirektenModifikator(fragment);
      if (direkt == null) {
        if (!unknown.contains(fragment)) {
          unknown.add(fragment);
        }
        continue;
      }

      if (direkt.art == HeroHerkunftsModifikatorArt.eigenschaft) {
        attrMods = wendeAttributCodeAn(direkt.ziel, direkt.betrag, attrMods)!;
        if (source.contributesToStartAttributes) {
          startAttrMods = wendeAttributCodeAn(
            direkt.ziel,
            direkt.betrag,
            startAttrMods,
          )!;
        }
        continue;
      }

      statMods = wendeBasiswertCodeAn(direkt.ziel, direkt.betrag, statMods)!;
    }
  }

  return ModifierParseResult(
    attributeMods: attrMods,
    startAttributeMods: startAttrMods,
    statMods: statMods,
    hasFlinkFromVorteile: hasFlinkFromVorteile,
    hasBehaebigFromNachteile: hasBehaebigFromNachteile,
    hasLinkshaenderFromVorteile: hasLinkshaenderFromVorteile,
    unknownFragments: List<String>.unmodifiable(unknown),
  );
}

// Prueft, ob ein benanntes Token (z. B. 'flink', 'behaebig') im Text vorkommt.
//
// Deutsche Umlaute werden vor dem Vergleich normalisiert (ae, oe, ue, ss),
// weil Nutzer Vorteile unterschiedlich eintippen koennen
// ('Behäbig', 'Behaebig', 'BEHÄBIG'). Die Zeichencodes sind Unicode-Codepoints
// der Umlaute: 228=ä, 246=ö, 252=ü, 223=ß.
// Anschliessend wird der Text an nicht-alphanumerischen Zeichen in Tokens
// aufgeteilt und jeder Token gegen die Ziel-Menge geprueft.
bool _containsNamedToken(String text, Set<String> targets) {
  for (final rawFragment in text.split(RegExp(r'[\n,;]+'))) {
    final fragment = rawFragment.trim();
    if (fragment.isEmpty) {
      continue;
    }
    final normalizedFragment = fragment
        .toLowerCase()
        .replaceAll(String.fromCharCode(228), 'a')
        .replaceAll(String.fromCharCode(246), 'o')
        .replaceAll(String.fromCharCode(252), 'u')
        .replaceAll(String.fromCharCode(223), 'ss');
    final tokens = normalizedFragment
        .split(RegExp(r'[^a-z0-9]+'))
        .where((entry) => entry.isNotEmpty);
    for (final token in tokens) {
      if (targets.contains(token)) {
        return true;
      }
    }
  }
  return false;
}
