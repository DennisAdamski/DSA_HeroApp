import 'package:dsa_heldenverwaltung/domain/attributes.dart';

/// Kanonische Codes fuer die acht DSA-Grundeigenschaften.
///
/// Die Werte werden an zentraler Stelle normalisiert, damit Parser- und
/// UI-Pfade dieselben Aliase akzeptieren.
enum AttributeCode { mu, kl, inn, ch, ff, ge, ko, kk }

/// Stabiler persistierter Code fuer einen [AttributeCode].
String attributeCodeKey(AttributeCode code) {
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

/// Normalisiert Eigenschaftsnamen fuer robuste Alias-Erkennung.
///
/// Beispiele:
/// - `MU` -> `mu`
/// - `Intuition` -> `intuition`
/// - `Koerperkraft` / `KoerperkrafT` -> `koerperkraft`
/// - `Körperkraft` -> `koerperkraft`
String normalizeAttributeToken(String value) {
  var text = value.toLowerCase().trim();
  text = text
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return text.replaceAll(RegExp(r'[^a-z]'), '');
}

/// Liefert den kanonischen Attribut-Code fuer bekannte Kurzformen und Namen.
///
/// Gibt `null` zurueck, wenn der Token keine bekannte Eigenschaft beschreibt.
AttributeCode? parseAttributeCode(String raw) {
  final normalized = normalizeAttributeToken(raw);
  switch (normalized) {
    case 'mu':
    case 'mut':
      return AttributeCode.mu;
    case 'kl':
    case 'klugheit':
      return AttributeCode.kl;
    case 'in':
    case 'inn':
    case 'intuition':
      return AttributeCode.inn;
    case 'ch':
    case 'charisma':
      return AttributeCode.ch;
    case 'ff':
    case 'fingerfertigkeit':
      return AttributeCode.ff;
    case 'ge':
    case 'gewandheit':
      return AttributeCode.ge;
    case 'ko':
    case 'konstitution':
      return AttributeCode.ko;
    case 'kk':
    case 'koerperkraft':
    case 'korperkraft':
      return AttributeCode.kk;
    default:
      return null;
  }
}

/// Liefert den aktuellen Eigenschaftswert fuer einen kanonischen Code.
int readAttributeValue(Attributes attributes, AttributeCode code) {
  switch (code) {
    case AttributeCode.mu:
      return attributes.mu;
    case AttributeCode.kl:
      return attributes.kl;
    case AttributeCode.inn:
      return attributes.inn;
    case AttributeCode.ch:
      return attributes.ch;
    case AttributeCode.ff:
      return attributes.ff;
    case AttributeCode.ge:
      return attributes.ge;
    case AttributeCode.ko:
      return attributes.ko;
    case AttributeCode.kk:
      return attributes.kk;
  }
}
