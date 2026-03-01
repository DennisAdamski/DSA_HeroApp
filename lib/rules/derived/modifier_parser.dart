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
    this.unknownFragments = const <String>[],
  });

  final AttributeModifiers attributeMods;
  final StatModifiers statMods;
  final List<String> unknownFragments;
}

final Map<String, ModifierParseResult> _modifierParseCache =
    <String, ModifierParseResult>{};
const int _modifierParseCacheMaxEntries = 512;

/// Komfortfunktion: parst alle relevanten Modifikatorfelder eines Helden.
ModifierParseResult parseModifierTextsForHero(HeroSheet hero) {
  final key = _buildModifierParseCacheKey(
    rasseModText: hero.rasseModText,
    kulturModText: hero.kulturModText,
    professionModText: hero.professionModText,
    vorteileText: hero.vorteileText,
    nachteileText: hero.nachteileText,
  );
  final cached = _modifierParseCache[key];
  if (cached != null) {
    return cached;
  }

  final parsed = parseModifierTexts(
    rasseModText: hero.rasseModText,
    kulturModText: hero.kulturModText,
    professionModText: hero.professionModText,
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
    unknownFragments: List<String>.unmodifiable(unknown),
  );
}

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

String _normalizeCode(String input) {
  final text = input.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

  const aliases = {'AE': 'ASP', 'LE': 'LEP', 'AW': 'AUSWEICHEN'};

  return aliases[text] ?? text;
}

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
