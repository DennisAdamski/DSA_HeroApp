import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/rules/derived/direkter_modifikator_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parse_result.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_text_parser.dart';

export 'package:dsa_heldenverwaltung/rules/derived/modifier_parse_result.dart';
export 'package:dsa_heldenverwaltung/rules/derived/modifier_text_parser.dart';

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
  // Die Herkunft wertet ARCH-02 getrennt aus (strukturierte Liste, sonst
  // Kompatibilitaetstext); der Textparser sieht sie hier nie, damit nichts
  // doppelt zaehlt, und der Textcache haengt nur an Vor- und Nachteilen.
  final key = _buildModifierParseCacheKey(
    vorteileText: merkmale.freieVorteile,
    nachteileText: merkmale.freieNachteile,
  );
  var parsed = _modifierParseCache[key];
  if (parsed == null) {
    parsed = parseModifierTexts(
      rasseModText: '',
      kulturModText: '',
      professionModText: '',
      vorteileText: merkmale.freieVorteile,
      nachteileText: merkmale.freieNachteile,
    );
    if (_modifierParseCache.length >= _modifierParseCacheMaxEntries) {
      _modifierParseCache.remove(_modifierParseCache.keys.first);
    }
    _modifierParseCache[key] = parsed;
  }
  final herkunft = werteHerkunftAus(hero.background).gesamt;
  return mitMerkmalWirkungen(
    _mitHerkunft(herkunft, parsed),
    merkmale.wirkungen,
  );
}

// Addiert das Herkunftsergebnis auf das Textergebnis von Vor-/Nachteilen.
// Unbekannte Fragmente behalten die bisherige Reihenfolge (Herkunft zuerst).
ModifierParseResult _mitHerkunft(
  ModifierParseResult herkunft,
  ModifierParseResult parsed,
) {
  final unbekannt = <String>[...herkunft.unknownFragments];
  for (final fragment in parsed.unknownFragments) {
    if (!unbekannt.contains(fragment)) {
      unbekannt.add(fragment);
    }
  }
  return ModifierParseResult(
    attributeMods: herkunft.attributeMods + parsed.attributeMods,
    startAttributeMods: herkunft.startAttributeMods + parsed.startAttributeMods,
    statMods: herkunft.statMods + parsed.statMods,
    hasFlinkFromVorteile: parsed.hasFlinkFromVorteile,
    hasBehaebigFromNachteile: parsed.hasBehaebigFromNachteile,
    hasLinkshaenderFromVorteile: parsed.hasLinkshaenderFromVorteile,
    unknownFragments: List<String>.unmodifiable(unbekannt),
  );
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

// Erzeugt einen Cache-Schluessel aus den Vor- und Nachteiltexten.
// Als Trennzeichen wird U+0001 (ASCII SOH) verwendet – ein Steuerzeichen,
// das in normalen Nutzer-Eingaben nicht vorkommt und so falsche Treffer
// durch zufaellig zusammenpassende Textkonkatenationen verhindert.
String _buildModifierParseCacheKey({
  required String vorteileText,
  required String nachteileText,
}) {
  return [vorteileText, nachteileText].join('\u0001');
}
