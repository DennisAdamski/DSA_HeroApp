import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';

/// Parserergebnis fuer freie Modifikatortexte aus den Basisdaten.
///
/// Nicht erkannte Fragmente werden gesammelt, damit die UI sie sichtbar machen
/// kann (`HeroSheet.unknownModifierFragments`).
class ModifierParseResult {
  const ModifierParseResult({
    this.attributeMods = const AttributeModifiers(),
    this.statMods = const StatModifiers(),
    this.hasFlinkFromVorteile = false,
    this.hasBehaebigFromNachteile = false,
    this.unknownFragments = const <String>[],
  });

  final AttributeModifiers attributeMods;
  final StatModifiers statMods;
  final bool hasFlinkFromVorteile;
  final bool hasBehaebigFromNachteile;
  final List<String> unknownFragments;
}

/// Extrahiert alle erkannten Basiswert-Codes aus einem freien Modifier-Text.
///
/// Die Rueckgabe enthaelt normalisierte Codes wie `ASP` oder `KAP`; unbekannte
/// Fragmente werden ignoriert.
Set<String> extractNormalizedStatModifierCodes(String text) {
  final codes = <String>{};
  final regex = RegExp(r'^\s*([A-Za-z]+)\s*([+-])\s*(\d+)\s*$');
  final fragments = text.split(RegExp(r'[\n,;]+'));
  for (final raw in fragments) {
    final fragment = raw.trim();
    if (fragment.isEmpty) {
      continue;
    }
    final match = regex.firstMatch(fragment);
    if (match == null) {
      continue;
    }
    final code = _normalizeCode(match.group(1)!);
    if (_isKnownStatCode(code)) {
      codes.add(code);
    }
  }
  return codes;
}

final Map<String, ModifierParseResult> _modifierParseCache =
    <String, ModifierParseResult>{};
const int _modifierParseCacheMaxEntries = 512;

/// Komfortfunktion: parst alle relevanten Modifikatorfelder eines Helden.
ModifierParseResult parseModifierTextsForHero(HeroSheet hero) {
  final key = _buildModifierParseCacheKey(
    rasseModText: hero.background.rasseModText,
    kulturModText: hero.background.kulturModText,
    professionModText: hero.background.professionModText,
    vorteileText: hero.vorteileText,
    nachteileText: hero.nachteileText,
  );
  final cached = _modifierParseCache[key];
  if (cached != null) {
    return cached;
  }

  final parsed = parseModifierTexts(
    rasseModText: hero.background.rasseModText,
    kulturModText: hero.background.kulturModText,
    professionModText: hero.background.professionModText,
    vorteileText: hero.vorteileText,
    nachteileText: hero.nachteileText,
  );
  if (_modifierParseCache.length >= _modifierParseCacheMaxEntries) {
    _modifierParseCache.remove(_modifierParseCache.keys.first);
  }
  _modifierParseCache[key] = parsed;
  return parsed;
}

/// Berechnet effektive Attribute inklusive Textmodifikatoren.
Attributes computeEffectiveAttributes(
  HeroSheet hero, {
  AttributeModifiers tempAttributeMods = const AttributeModifiers(),
}) {
  final parsed = parseModifierTextsForHero(hero);
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
  var statMods = const StatModifiers();
  final unknown = <String>[];
  final hasFlinkFromVorteile = _containsNamedToken(vorteileText, const {
    'flink',
  });
  final hasBehaebigFromNachteile = _containsNamedToken(nachteileText, const {
    'behaebig',
    'behabig',
  });

  final allTexts = [
    rasseModText,
    kulturModText,
    professionModText,
    vorteileText,
    nachteileText,
  ];

  final regex = RegExp(r'^\s*([A-Za-z]+)\s*([+-])\s*(\d+)\s*$');

  for (final text in allTexts) {
    final fragments = text.split(RegExp(r'[\n,;]+'));
    for (final raw in fragments) {
      final fragment = raw.trim();
      if (fragment.isEmpty) {
        continue;
      }

      final match = regex.firstMatch(fragment);
      if (match == null) {
        if (!unknown.contains(fragment)) {
          unknown.add(fragment);
        }
        continue;
      }

      final code = _normalizeCode(match.group(1)!);
      final sign = match.group(2) == '-' ? -1 : 1;
      final amount = int.parse(match.group(3)!) * sign;

      final handledAttr = _applyAttributeCode(code, amount, attrMods);
      if (handledAttr != null) {
        attrMods = handledAttr;
        continue;
      }

      final handledStat = _applyStatCode(code, amount, statMods);
      if (handledStat != null) {
        statMods = handledStat;
        continue;
      }

      if (!unknown.contains(fragment)) {
        unknown.add(fragment);
      }
    }
  }

  return ModifierParseResult(
    attributeMods: attrMods,
    statMods: statMods,
    hasFlinkFromVorteile: hasFlinkFromVorteile,
    hasBehaebigFromNachteile: hasBehaebigFromNachteile,
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

// Normalisiert einen Modifier-Code auf Grossbuchstaben und loest DSA-Aliase auf:
//   AE → ASP   (Astralpunkte; AE = Astral-Energie, historische Abkuerzung)
//   LE → LEP   (Lebenspunkte; LE = Lebens-Energie)
//   AW → AUSWEICHEN
// Nicht-Buchstaben werden entfernt, damit z. B. 'Mu' und 'MU' identisch behandelt werden.
String _normalizeCode(String input) {
  final text = input.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

  const aliases = {
    'AE': 'ASP',
    'KE': 'KAP',
    'LE': 'LEP',
    'AW': 'AUSWEICHEN',
  };

  return aliases[text] ?? text;
}

bool _isKnownStatCode(String code) {
  switch (code) {
    case 'LEP':
    case 'AU':
    case 'ASP':
    case 'KAP':
    case 'MR':
    case 'INI':
    case 'GS':
    case 'AUSWEICHEN':
      return true;
    default:
      return false;
  }
}

// Wendet einen Modifier-Betrag auf die passende Eigenschaft an.
// Gibt null zurueck, wenn der Code keiner Eigenschaft entspricht,
// damit der Aufrufer den Stat-Code-Pfad probieren kann.
AttributeModifiers? _applyAttributeCode(
  String code,
  int amount,
  AttributeModifiers current,
) {
  final parsed = parseAttributeCode(code);
  switch (parsed) {
    case AttributeCode.mu:
      return current.copyWith(mu: current.mu + amount);
    case AttributeCode.kl:
      return current.copyWith(kl: current.kl + amount);
    case AttributeCode.inn:
      return current.copyWith(inn: current.inn + amount);
    case AttributeCode.ch:
      return current.copyWith(ch: current.ch + amount);
    case AttributeCode.ff:
      return current.copyWith(ff: current.ff + amount);
    case AttributeCode.ge:
      return current.copyWith(ge: current.ge + amount);
    case AttributeCode.ko:
      return current.copyWith(ko: current.ko + amount);
    case AttributeCode.kk:
      return current.copyWith(kk: current.kk + amount);
    case null:
      return null;
  }
}

// Wendet einen Modifier-Betrag auf den passenden abgeleiteten Wert an.
// Gibt null zurueck, wenn der Code unbekannt ist; der Aufrufer sammelt
// unbekannte Fragmente dann in unknownFragments.
StatModifiers? _applyStatCode(String code, int amount, StatModifiers current) {
  switch (code) {
    case 'LEP':
      return current.copyWith(lep: current.lep + amount);
    case 'AU':
      return current.copyWith(au: current.au + amount);
    case 'ASP':
      return current.copyWith(asp: current.asp + amount);
    case 'KAP':
      return current.copyWith(kap: current.kap + amount);
    case 'MR':
      return current.copyWith(mr: current.mr + amount);
    case 'INI':
      return current.copyWith(iniBase: current.iniBase + amount);
    case 'GS':
      return current.copyWith(gs: current.gs + amount);
    case 'AUSWEICHEN':
      return current.copyWith(ausweichen: current.ausweichen + amount);
    default:
      return null;
  }
}
