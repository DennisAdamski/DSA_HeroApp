import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';
import 'package:dsa_heldenverwaltung/catalog/rule_meta.dart';

/// Definition eines Talents aus dem Regelkatalog.
///
/// Unterscheidung normale Talente vs. Kampftalente erfolgt ueber
/// [group] ('Kampftalent'), [weaponCategory] (nicht-leer) oder
/// [type] ('nahkampf' / 'fernkampf').
///
/// [steigerung] ist der Steigerungsfaktor der DSA-Steigungstabelle
/// (z. B. 'B', 'C', 'D', 'E', 'F') – bestimmt AP-Kosten pro TaW-Punkt.
/// [be] beschreibt den Behinderungseinfluss: '-' = keiner, '-2' = feste
/// Reduktion, 'xBE' = Vielfaches der Ruestungsbehinderung.
class TalentDef {
  const TalentDef({
    required this.id,
    required this.name,
    required this.group,
    required this.steigerung,
    required this.attributes,
    this.type = '',
    this.be = '',
    this.weaponCategory = '',
    this.alternatives = '',
    this.source = '',
    this.description = '',
    this.active = true,
    this.ruleMeta,
  });

  final String id; // Eindeutige ID (z. B. 'tal_empathie')
  final String name; // Anzeigename
  final String group; // Gruppe ('Kampftalent', 'Gabe', 'Koerper', …)
  final String steigerung; // AP-Steigerungskategorie ('B'–'F')
  final List<String> attributes; // Drei Eigenschaftskuerzel fuer Proben
  final String type; // Talenttyp ('nahkampf', 'fernkampf', 'Gabe', …)
  final String be; // Behinderungsformel ('-', '-N', 'xN' oder '')
  final String weaponCategory; // Waffenkategorie fuer Spezialisierungsabgleich
  final String alternatives; // Alternative Kategorienamen (kommagetrennt)
  final String source; // Quellreferenz (Seitenzahl o. Ae.)
  final String description; // Regelbeschreibung als Freitext
  final bool active; // Im App verfuegbar und anzeigbar?
  final RuleMeta? ruleMeta; // Strukturierte Herkunfts- und Freischaltmetadaten

  factory TalentDef.fromJson(Map<String, dynamic> json) {
    final ruleMetaJson = readCatalogObject(json, 'ruleMeta');
    return TalentDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      group: readCatalogString(json, 'group', fallback: ''),
      steigerung: readCatalogString(json, 'steigerung', fallback: 'B'),
      attributes: readCatalogStringList(json, 'attributes'),
      type: readCatalogString(json, 'type', fallback: ''),
      be: readCatalogString(json, 'be', fallback: ''),
      weaponCategory: readCatalogString(json, 'weaponCategory', fallback: ''),
      alternatives: readCatalogString(json, 'alternatives', fallback: ''),
      source: readCatalogString(json, 'source', fallback: ''),
      description: readCatalogString(json, 'description', fallback: ''),
      active: readCatalogBool(json, 'active', fallback: true),
      ruleMeta: ruleMetaJson == null ? null : RuleMeta.fromJson(ruleMetaJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group': group,
      'steigerung': steigerung,
      'attributes': attributes,
      'type': type,
      'be': be,
      'weaponCategory': weaponCategory,
      'alternatives': alternatives,
      'source': source,
      'description': description,
      'active': active,
      if (ruleMeta != null) 'ruleMeta': ruleMeta!.toJson(),
    };
  }
}
