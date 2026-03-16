import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_distance_band.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';

/// Definition einer Waffe aus dem Regelkatalog.
///
/// [combatSkill] verweist auf den Namen des zugehoerigen Kampftalents.
/// [tp] enthaelt die Schadens-Formel als Freitext (z. B. '1W6+4').
/// [tpkk] beschreibt die KK-abhaengige TP-Skalierung im DSA-Format
/// (z. B. '12/6' bedeutet: ab KK 12, ein TP-Schritt pro 6 KK-Punkte).
/// [atMod] und [paMod] sind waffenspezifische Angriffs- und Parade-Boni.
class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.name,
    required this.type,
    required this.combatSkill,
    required this.tp,
    this.complexity = '',
    this.weaponCategory = '',
    this.possibleManeuvers = const [],
    this.activeManeuvers = const [],
    this.tpkk = '',
    this.iniMod = 0,
    this.atMod = 0,
    this.paMod = 0,
    this.reloadTime = 0,
    this.rangedDistanceBands = const <RangedDistanceBand>[],
    this.rangedProjectiles = const <RangedProjectile>[],
    this.reach = '',
    this.source = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String type; // 'Nahkampf' oder 'Fernkampf'
  final String combatSkill; // Verknuepftes Kampftalent (Name)
  final String tp; // Schadens-Formel (z. B. '1W6+4')
  final String complexity; // Waffenkomplexitaet
  final String weaponCategory; // Kategorie fuer Spezialisierungsabgleich
  final List<String> possibleManeuvers; // Alle verfuegbaren Manöver-IDs
  final List<String> activeManeuvers; // Standardmaessig aktive Manöver-IDs
  final String tpkk; // KK-Skalierung im Format 'Basis/Schritt'
  final int iniMod; // Waffenspezifischer Initiative-Modifier
  final int atMod; // Waffenspezifischer Angriff-Modifier
  final int paMod; // Waffenspezifischer Parade-Modifier
  final int reloadTime; // Feste Ladezeit fuer Fernkampfwaffen
  final List<RangedDistanceBand> rangedDistanceBands; // Distanzstufen
  final List<RangedProjectile> rangedProjectiles; // Geschossvorlagen
  final String reach; // Reichweite / Distanzklasse
  final String source; // Quellreferenz
  final bool active; // Im App verfuegbar und anzeigbar?

  factory WeaponDef.fromJson(Map<String, dynamic> json) {
    final type = readCatalogString(json, 'type', fallback: '');
    final rawDistanceBands =
        (json['rangedDistanceBands'] as List?) ?? const <dynamic>[];
    final rawProjectiles =
        (json['rangedProjectiles'] as List?) ??
        (json['projectiles'] as List?) ??
        const <dynamic>[];
    final hasAtMod = json.containsKey('atMod') && json['atMod'] != null;
    return WeaponDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      type: type,
      combatSkill: readCatalogString(json, 'combatSkill', fallback: ''),
      tp: readCatalogString(json, 'tp', fallback: ''),
      complexity: readCatalogString(json, 'complexity', fallback: ''),
      weaponCategory: readCatalogString(json, 'weaponCategory', fallback: ''),
      possibleManeuvers: readCatalogStringList(json, 'possibleManeuvers'),
      activeManeuvers: readCatalogStringList(json, 'activeManeuvers'),
      tpkk: readCatalogString(json, 'tpkk', fallback: ''),
      iniMod: readCatalogInt(json, 'iniMod', fallback: 0),
      atMod: hasAtMod
          ? readCatalogInt(json, 'atMod', fallback: 0)
          : readCatalogInt(
              json,
              'fkMod',
              fallback: type.trim().toLowerCase() == 'fernkampf'
                  ? 0
                  : readCatalogInt(json, 'atMod', fallback: 0),
            ),
      paMod: readCatalogInt(json, 'paMod', fallback: 0),
      reloadTime: readCatalogInt(json, 'reloadTime', fallback: 0),
      rangedDistanceBands: rawDistanceBands
          .whereType<Map>()
          .map(
            (entry) =>
                RangedDistanceBand.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      rangedProjectiles: rawProjectiles
          .whereType<Map>()
          .map(
            (entry) => RangedProjectile.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      reach: readCatalogString(json, 'reach', fallback: ''),
      source: readCatalogString(json, 'source', fallback: ''),
      active: readCatalogBool(json, 'active', fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'combatSkill': combatSkill,
      'tp': tp,
      'complexity': complexity,
      'weaponCategory': weaponCategory,
      'possibleManeuvers': possibleManeuvers,
      'activeManeuvers': activeManeuvers,
      'tpkk': tpkk,
      'iniMod': iniMod,
      'atMod': atMod,
      'paMod': paMod,
      'reloadTime': reloadTime,
      'rangedDistanceBands': rangedDistanceBands
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'rangedProjectiles': rangedProjectiles
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'reach': reach,
      'source': source,
      'active': active,
    };
  }
}
