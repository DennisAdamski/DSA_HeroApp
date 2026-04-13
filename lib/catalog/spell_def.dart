import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Definition eines Zauberspruchs aus dem Regelkatalog.
///
/// [steigerung] entspricht dem AP-Steigerungsfaktor (analog zu [TalentDef]).
/// [aspCost] enthaelt die Kosten in Astralpunkten als Formel-String
/// (z. B. '4' oder '4W6').
/// [modifier] beschreibt moegliche Erschwernisse oder Erleichterungen.
class SpellDef {
  const SpellDef({
    required this.id,
    required this.name,
    required this.tradition,
    required this.steigerung,
    required this.attributes,
    this.availability = '',
    this.traits = '',
    this.modifier = '',
    this.castingTime = '',
    this.aspCost = '',
    this.targetObject = '',
    this.range = '',
    this.duration = '',
    this.modifications = '',
    this.wirkung = '',
    this.variants = const [],
    this.rawVariantsEncrypted,
    this.category = '',
    this.source = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String tradition; // Magie-Tradition (z. B. 'Gildenmagie')
  final String steigerung; // AP-Steigerungskategorie ('A'–'F')
  final List<String> attributes; // Eigenschaftskuerzel fuer Zauberprobe
  final String availability; // Verfuegbarkeit (Verbreitung)
  final String traits; // Zaubereigenschaften (z. B. 'Beruehrung, Blitz')
  final String modifier; // Erschwernis/Erleichterung als Freitext
  final String castingTime; // Zauberdauer (z. B. '2 Aktionen')
  final String aspCost; // AsP-Kosten als Freitext-Formel (z. B. '4W6')
  final String targetObject; // Zielobjekt laut Regelwerk
  final String range; // Reichweite
  final String duration; // Wirkungsdauer
  final String modifications; // Modifikationsoptionen fuer den Zauber
  final String wirkung; // Wirkungsbeschreibung (Langtext aus dem Regelwerk)
  final List<String> variants; // Definierte Varianten des Zaubers

  /// Verschluesselter Roh-String fuer Varianten (nur gesetzt bei `enc:`-Werten).
  final String? rawVariantsEncrypted;

  final String category; // Zauberkategorie
  final String source; // Quellreferenz (z. B. 'Liber Cantiones S. 36')
  final bool active; // Im App verfuegbar und anzeigbar?

  factory SpellDef.fromJson(Map<String, dynamic> json) {
    // Varianten koennen als verschluesselter String vorliegen.
    final rawVariants = json['variants'];
    final variantsEncrypted =
        isEncryptedValue(rawVariants) ? rawVariants as String : null;
    final variants =
        variantsEncrypted != null ? const <String>[] : readCatalogStringList(json, 'variants');

    return SpellDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      tradition: readCatalogString(json, 'tradition', fallback: ''),
      steigerung: readCatalogString(json, 'steigerung', fallback: 'C'),
      attributes: readCatalogStringList(json, 'attributes'),
      availability: readCatalogString(json, 'availability', fallback: ''),
      traits: readCatalogString(json, 'traits', fallback: ''),
      modifier: readCatalogString(json, 'modifier', fallback: ''),
      castingTime: readCatalogString(json, 'castingTime', fallback: ''),
      aspCost: readCatalogString(json, 'aspCost', fallback: ''),
      targetObject: readCatalogString(json, 'targetObject', fallback: ''),
      range: readCatalogString(json, 'range', fallback: ''),
      duration: readCatalogString(json, 'duration', fallback: ''),
      modifications: readCatalogString(json, 'modifications', fallback: ''),
      wirkung: readCatalogString(json, 'wirkung', fallback: ''),
      variants: variants,
      rawVariantsEncrypted: variantsEncrypted,
      category: readCatalogString(json, 'category', fallback: ''),
      source: readCatalogString(json, 'source', fallback: ''),
      active: readCatalogBool(json, 'active', fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tradition': tradition,
      'steigerung': steigerung,
      'attributes': attributes,
      'availability': availability,
      'traits': traits,
      'modifier': modifier,
      'castingTime': castingTime,
      'aspCost': aspCost,
      'targetObject': targetObject,
      'range': range,
      'duration': duration,
      'modifications': modifications,
      'wirkung': wirkung,
      'variants': variants,
      'category': category,
      'source': source,
      'active': active,
    };
  }
}
