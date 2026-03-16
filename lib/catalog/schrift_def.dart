import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Definition einer Schrift aus dem Regelkatalog.
///
/// [steigerung] bestimmt die AP-Kosten pro Talentwert-Punkt ('A', 'B' oder 'C').
class SchriftDef {
  const SchriftDef({
    required this.id,
    required this.name,
    required this.maxWert,
    this.beschreibung = '',
    this.steigerung = 'A',
    this.hinweise = '',
  });

  final String id; // Eindeutige ID (z. B. 'sch_kusliker_zeichen')
  final String name; // Anzeigename
  final int maxWert; // Maximaler Talentwert
  final String beschreibung; // Kurzbeschreibung (z. B. '31 Lautzeichen')
  final String steigerung; // AP-Steigerungskategorie ('A', 'B' oder 'C')
  final String hinweise; // Freitext-Sonderregeln

  factory SchriftDef.fromJson(Map<String, dynamic> json) {
    return SchriftDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      maxWert: readCatalogInt(json, 'maxWert', fallback: 10),
      beschreibung: readCatalogString(json, 'beschreibung', fallback: ''),
      steigerung: readCatalogString(json, 'steigerung', fallback: 'A'),
      hinweise: readCatalogString(json, 'hinweise', fallback: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'maxWert': maxWert,
      'beschreibung': beschreibung,
      'steigerung': steigerung,
      'hinweise': hinweise,
    };
  }
}
