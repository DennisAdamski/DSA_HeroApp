import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parse_result.dart';

/// Ein erkannter direkter Modifikator der Form `CODE+N` oder `CODE-N`.
///
/// Gemeinsamer Vertrag von Modifikator-Parser und Herkunftsmigration: Beide
/// erkennen dieselben Codes und Aliase, damit die strukturierte Herkunft genau
/// so rechnet wie der Freitext, aus dem sie stammt.
class DirekterModifikator {
  /// Erstellt einen direkten Modifikator; [art] ist nie `frei`.
  const DirekterModifikator({
    required this.art,
    required this.ziel,
    required this.betrag,
  });

  /// `eigenschaft` oder `basiswert`.
  final HeroHerkunftsModifikatorArt art;

  /// Normalisierter Code, bei Eigenschaften der persistierte Kurzcode
  /// (`MU`, `KL`, `IN` …), bei Basiswerten `LEP`, `AU`, `ASP`, `KAP`, `MR`,
  /// `INI`, `GS` oder `AUSWEICHEN`.
  final String ziel;

  /// Vorzeichenbehafteter Betrag.
  final int betrag;
}

final RegExp _direkterModifikator = RegExp(
  r'^\s*([A-Za-z]+)\s*([+-])\s*(\d+)\s*$',
);

/// Erkennt ein Textfragment der Form `CODE+N` / `CODE-N`.
///
/// Aliase: `AE` → `ASP`, `KE` → `KAP`, `LE` → `LEP`, `AW` → `AUSWEICHEN`.
/// Gibt `null` zurück, wenn das Fragment kein direkter Modifikator ist oder
/// der Code weder eine Eigenschaft noch ein bekannter Basiswert ist.
DirekterModifikator? erkenneDirektenModifikator(String fragment) {
  final match = _direkterModifikator.firstMatch(fragment.trim());
  if (match == null) {
    return null;
  }
  final code = normalisiereModifikatorCode(match.group(1)!);
  final vorzeichen = match.group(2) == '-' ? -1 : 1;
  final betrag = int.tryParse(match.group(3)!);
  if (betrag == null) {
    return null;
  }
  final eigenschaft = parseAttributeCode(code);
  if (eigenschaft != null) {
    return DirekterModifikator(
      art: HeroHerkunftsModifikatorArt.eigenschaft,
      ziel: attributeCodeKey(eigenschaft),
      betrag: betrag * vorzeichen,
    );
  }
  if (istBekannterBasiswertCode(code)) {
    return DirekterModifikator(
      art: HeroHerkunftsModifikatorArt.basiswert,
      ziel: code,
      betrag: betrag * vorzeichen,
    );
  }
  return null;
}

/// Wendet einen direkten Herkunftsmodifikator an.
///
/// Eigenschaften wirken laufend **und** auf den Startwert (Herkunft ist
/// Generierungswert); Basiswerte wirken als Basiswertmodifikator.
ModifierParseResult wendeDirektenModifikatorAn(DirekterModifikator eintrag) {
  if (eintrag.art == HeroHerkunftsModifikatorArt.eigenschaft) {
    final mods = wendeAttributCodeAn(
      eintrag.ziel,
      eintrag.betrag,
      const AttributeModifiers(),
    );
    return ModifierParseResult(
      attributeMods: mods ?? const AttributeModifiers(),
      startAttributeMods: mods ?? const AttributeModifiers(),
    );
  }
  return ModifierParseResult(
    statMods:
        wendeBasiswertCodeAn(
          eintrag.ziel,
          eintrag.betrag,
          const StatModifiers(),
        ) ??
        const StatModifiers(),
  );
}

/// Extrahiert alle erkannten Basiswert-Codes aus einem freien Modifier-Text.
///
/// Die Rückgabe enthält normalisierte Codes wie `ASP` oder `KAP`; unbekannte
/// Fragmente werden ignoriert.
Set<String> normalisierteBasiswertCodes(String text) {
  final codes = <String>{};
  for (final roh in text.split(RegExp(r'[\n,;]+'))) {
    final direkt = erkenneDirektenModifikator(roh);
    if (direkt != null && direkt.art == HeroHerkunftsModifikatorArt.basiswert) {
      codes.add(direkt.ziel);
    }
  }
  return codes;
}

/// Normalisiert einen Modifikatorcode auf Großbuchstaben und löst DSA-Aliase
/// auf (`AE` → `ASP`, `KE` → `KAP`, `LE` → `LEP`, `AW` → `AUSWEICHEN`).
///
/// Nicht-Buchstaben entfallen, damit `Mu` und `MU` gleich behandelt werden.
String normalisiereModifikatorCode(String eingabe) {
  final text = eingabe.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  const aliase = {'AE': 'ASP', 'KE': 'KAP', 'LE': 'LEP', 'AW': 'AUSWEICHEN'};
  return aliase[text] ?? text;
}

/// Ob [code] ein bekannter, bereits normalisierter Basiswertcode ist.
bool istBekannterBasiswertCode(String code) {
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

/// Addiert [betrag] auf die Eigenschaft [code]; `null`, wenn [code] keine
/// Eigenschaft ist.
AttributeModifiers? wendeAttributCodeAn(
  String code,
  int betrag,
  AttributeModifiers aktuell,
) {
  switch (parseAttributeCode(code)) {
    case AttributeCode.mu:
      return aktuell.copyWith(mu: aktuell.mu + betrag);
    case AttributeCode.kl:
      return aktuell.copyWith(kl: aktuell.kl + betrag);
    case AttributeCode.inn:
      return aktuell.copyWith(inn: aktuell.inn + betrag);
    case AttributeCode.ch:
      return aktuell.copyWith(ch: aktuell.ch + betrag);
    case AttributeCode.ff:
      return aktuell.copyWith(ff: aktuell.ff + betrag);
    case AttributeCode.ge:
      return aktuell.copyWith(ge: aktuell.ge + betrag);
    case AttributeCode.ko:
      return aktuell.copyWith(ko: aktuell.ko + betrag);
    case AttributeCode.kk:
      return aktuell.copyWith(kk: aktuell.kk + betrag);
    case null:
      return null;
  }
}

/// Addiert [betrag] auf den Basiswert [code]; `null`, wenn der Code unbekannt
/// ist.
StatModifiers? wendeBasiswertCodeAn(
  String code,
  int betrag,
  StatModifiers aktuell,
) {
  switch (code) {
    case 'LEP':
      return aktuell.copyWith(lep: aktuell.lep + betrag);
    case 'AU':
      return aktuell.copyWith(au: aktuell.au + betrag);
    case 'ASP':
      return aktuell.copyWith(asp: aktuell.asp + betrag);
    case 'KAP':
      return aktuell.copyWith(kap: aktuell.kap + betrag);
    case 'MR':
      return aktuell.copyWith(mr: aktuell.mr + betrag);
    case 'INI':
      return aktuell.copyWith(iniBase: aktuell.iniBase + betrag);
    case 'GS':
      return aktuell.copyWith(gs: aktuell.gs + betrag);
    case 'AUSWEICHEN':
      return aktuell.copyWith(ausweichen: aktuell.ausweichen + betrag);
    default:
      return null;
  }
}
