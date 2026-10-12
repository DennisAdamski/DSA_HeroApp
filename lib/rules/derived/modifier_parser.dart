import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_trait_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/direkter_modifikator_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parse_result.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standard_stat_modifier_rules.dart';

export 'package:dsa_heldenverwaltung/rules/derived/modifier_parse_result.dart';

/// Extrahiert alle erkannten Basiswert-Codes aus einem freien Modifier-Text.
///
/// Die Rueckgabe enthaelt normalisierte Codes wie `ASP` oder `KAP`; unbekannte
/// Fragmente werden ignoriert.
Set<String> extractNormalizedStatModifierCodes(String text) =>
    normalisierteBasiswertCodes(text);

final Map<String, ModifierParseResult> _modifierParseCache =
    <String, ModifierParseResult>{};
const int _modifierParseCacheMaxEntries = 512;

/// Komfortfunktion: parst alle relevanten Modifikatorfelder eines Helden.
///
/// Vor- und Nachteile kommen aus [werteMerkmaleAus] (ARCH-02): Mit [catalog]
/// wirken katalogisierte Eintraege ueber ihre Katalog-ID, nur die frei
/// wirkenden Fragmente laufen durch den Textparser. Ohne Katalog laeuft der
/// Text der Merkmalsliste durch den Parser — mit demselben Ergebnis fuer
/// jeden unveraendert benannten Katalogeintrag.
ModifierParseResult parseModifierTextsForHero(
  HeroSheet hero, {
  required RulesCatalog? catalog,
}) {
  final merkmale = werteMerkmaleAus(hero, catalog: catalog);
  final key = _buildModifierParseCacheKey(
    rasseModText: hero.background.rasseModText,
    kulturModText: hero.background.kulturModText,
    professionModText: hero.background.professionModText,
    vorteileText: merkmale.freieVorteile,
    nachteileText: merkmale.freieNachteile,
  );
  var parsed = _modifierParseCache[key];
  if (parsed == null) {
    parsed = parseModifierTexts(
      rasseModText: hero.background.rasseModText,
      kulturModText: hero.background.kulturModText,
      professionModText: hero.background.professionModText,
      vorteileText: merkmale.freieVorteile,
      nachteileText: merkmale.freieNachteile,
    );
    if (_modifierParseCache.length >= _modifierParseCacheMaxEntries) {
      _modifierParseCache.remove(_modifierParseCache.keys.first);
    }
    _modifierParseCache[key] = parsed;
  }
  return mitMerkmalWirkungen(parsed, merkmale.wirkungen);
}

/// Ergaenzt ein Parserergebnis um die Wirkungen katalogisierter Merkmale.
ModifierParseResult mitMerkmalWirkungen(
  ModifierParseResult parsed,
  MerkmalWirkungen wirkungen,
) {
  return ModifierParseResult(
    attributeMods: parsed.attributeMods + wirkungen.attributeMods,
    startAttributeMods:
        parsed.startAttributeMods + wirkungen.startAttributeMods,
    statMods: parsed.statMods + wirkungen.statMods,
    hasFlinkFromVorteile: parsed.hasFlinkFromVorteile || wirkungen.flink,
    hasBehaebigFromNachteile:
        parsed.hasBehaebigFromNachteile || wirkungen.behaebig,
    hasLinkshaenderFromVorteile:
        parsed.hasLinkshaenderFromVorteile || wirkungen.linkshaender,
    unknownFragments: parsed.unknownFragments,
  );
}

/// Berechnet effektive Attribute inklusive Textmodifikatoren.
Attributes computeEffectiveAttributes(
  HeroSheet hero, {
  AttributeModifiers tempAttributeMods = const AttributeModifiers(),
  required RulesCatalog? catalog,
}) {
  final parsed = parseModifierTextsForHero(hero, catalog: catalog);
  return applyAttributeModifiers(
    hero.attributes,
    parsed.attributeMods + tempAttributeMods,
  );
}

/// Addiert die Attributmodifikatoren auf den Basiswertesatz.
Attributes applyAttributeModifiers(Attributes base, AttributeModifiers mods) {
  return base.copyWith(
    mu: base.mu + mods.mu,
    kl: base.kl + mods.kl,
    inn: base.inn + mods.inn,
    ch: base.ch + mods.ch,
    ff: base.ff + mods.ff,
    ge: base.ge + mods.ge,
    ko: base.ko + mods.ko,
    kk: base.kk + mods.kk,
  );
}

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

// Erzeugt einen Cache-Schluessel aus den fuenf Modifier-Texten.
// Als Trennzeichen wird U+0001 (ASCII SOH) verwendet – ein Steuerzeichen,
// das in normalen Nutzer-Eingaben nicht vorkommt und so falsche Treffer
// durch zufaellig zusammenpassende Textkonkatenationen verhindert.
String _buildModifierParseCacheKey({
  required String rasseModText,
  required String kulturModText,
  required String professionModText,
  required String vorteileText,
  required String nachteileText,
}) {
  return [
    rasseModText,
    kulturModText,
    professionModText,
    vorteileText,
    nachteileText,
  ].join('\u0001');
}
