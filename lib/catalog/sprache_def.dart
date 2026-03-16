import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Definition einer Sprache aus dem Regelkatalog.
///
/// [familie] bestimmt die dynamische Lernkomplexität:
/// – Sprache liegt in derselben Familie wie Muttersprache → A (außer [steigerung] ist 'B')
/// – Andere Familie oder keine Muttersprache → B
/// [steigerung] ist normalerweise 'A'; bei seltenen Sprachen (z. B. Asdharia)
/// ist es fest 'B'.
class SpracheDef {
  const SpracheDef({
    required this.id,
    required this.name,
    required this.familie,
    required this.maxWert,
    this.steigerung = 'A',
    this.schriftIds = const [],
    this.schriftlos = false,
    this.hinweise = '',
  });

  final String id; // Eindeutige ID (z. B. 'spr_garethi')
  final String name; // Anzeigename
  final String familie; // Sprachfamilie (z. B. 'Garethi-Familie')
  final int maxWert; // Maximaler Talentwert
  final String steigerung; // 'A' (Normalfall) oder 'B' (feste Komplexität)
  final List<String> schriftIds; // IDs zugehöriger Schriften
  final bool schriftlos; // true → keine Schrift vorhanden
  final String hinweise; // Freitext-Sonderregeln

  factory SpracheDef.fromJson(Map<String, dynamic> json) {
    return SpracheDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      familie: readCatalogString(json, 'familie', fallback: ''),
      maxWert: readCatalogInt(json, 'maxWert', fallback: 18),
      steigerung: readCatalogString(json, 'steigerung', fallback: 'A'),
      schriftIds: readCatalogStringList(json, 'schriftIds'),
      schriftlos: readCatalogBool(json, 'schriftlos', fallback: false),
      hinweise: readCatalogString(json, 'hinweise', fallback: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'familie': familie,
      'maxWert': maxWert,
      'steigerung': steigerung,
      'schriftIds': schriftIds,
      'schriftlos': schriftlos,
      'hinweise': hinweise,
    };
  }
}
