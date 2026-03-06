/// Haelt alle zur Laufzeit geladenen DSA-Spielregeldaten.
///
/// Wird einmalig beim App-Start durch [CatalogLoader] aus den Split-JSON-
/// Assets befuellt und dann als unveraenderliches Objekt weitergegeben.
/// Der Katalog ist die zentrale Quelle fuer Talent-, Waffen-, Zauber- und
/// Manoeuverdefinitionen.
class RulesCatalog {
  const RulesCatalog({
    required this.version,
    required this.source,
    required this.talents,
    required this.spells,
    required this.weapons,
    this.maneuvers = const [],
    this.metadata = const {},
  });

  final String version; // Katalogversion (z. B. 'house_rules_v1')
  final String source; // Quell-ID (z. B. Dateiname des Manifests)
  final List<TalentDef> talents; // Alle Talente (regulaer + Kampftalente)
  final List<SpellDef> spells; // Alle Zaubersprueche
  final List<WeaponDef> weapons; // Alle Waffendefinitionen
  final List<ManeuverDef> maneuvers; // Kampfmanöver (optional, kann leer sein)
  final Map<String, dynamic> metadata; // Sonstige Metadaten aus dem Manifest

  /// Sucht ein Manöver anhand des Namens (Groß-/Kleinschreibung wird ignoriert).
  ManeuverDef? maneuverByName(String name) {
    final needle = name.trim().toLowerCase();
    for (final m in maneuvers) {
      if (m.name.trim().toLowerCase() == needle) return m;
    }
    return null;
  }

  factory RulesCatalog.fromJson(Map<String, dynamic> json) {
    final talentsRaw = (json['talents'] as List?) ?? const [];
    final spellsRaw = (json['spells'] as List?) ?? const [];
    final weaponsRaw = (json['weapons'] as List?) ?? const [];

    return RulesCatalog(
      version: _readString(json, 'version', fallback: 'unknown'),
      source: _readString(json, 'source', fallback: 'unknown'),
      talents: talentsRaw
          .whereType<Map>()
          .map((entry) => TalentDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      spells: spellsRaw
          .whereType<Map>()
          .map((entry) => SpellDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      weapons: weaponsRaw
          .whereType<Map>()
          .map((entry) => WeaponDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'source': source,
      'metadata': metadata,
      'talents': talents.map((entry) => entry.toJson()).toList(growable: false),
      'spells': spells.map((entry) => entry.toJson()).toList(growable: false),
      'weapons': weapons.map((entry) => entry.toJson()).toList(growable: false),
    };
  }
}

/// Definition eines Kampfmanoeuvers aus dem Regelkatalog.
///
/// Manoever koennen Waffen ([WeaponDef.possibleManeuvers]) zugeordnet sein.
/// [erschwernis] enthaelt den Erschwernis-Wert als Freitext (z. B. '-4' oder '+0').
class ManeuverDef {
  const ManeuverDef({
    required this.id,
    required this.name,
    this.gruppe = '',
    this.erschwernis = '',
    this.seite = '',
    this.erklarung = '',
  });

  final String id; // Eindeutige ID (z. B. 'man_hammerschlag')
  final String name; // Anzeigename
  final String gruppe; // Kategorie (z. B. 'Angriff', 'Abwehr')
  final String erschwernis; // Erschwernis-Modifikator als Freitext
  final String seite; // Seitenreferenz im Regelwerk
  final String erklarung; // Regeltext / Beschreibung

  factory ManeuverDef.fromJson(Map<String, dynamic> json) {
    return ManeuverDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      gruppe: _readString(json, 'gruppe', fallback: ''),
      erschwernis: _readString(json, 'erschwernis', fallback: ''),
      seite: _readString(json, 'seite', fallback: ''),
      erklarung: _readString(json, 'erklarung', fallback: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gruppe': gruppe,
      'erschwernis': erschwernis,
      'seite': seite,
      'erklarung': erklarung,
    };
  }
}

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

  factory TalentDef.fromJson(Map<String, dynamic> json) {
    return TalentDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      group: _readString(json, 'group', fallback: ''),
      steigerung: _readString(json, 'steigerung', fallback: 'B'),
      attributes: _readStringList(json, 'attributes'),
      type: _readString(json, 'type', fallback: ''),
      be: _readString(json, 'be', fallback: ''),
      weaponCategory: _readString(json, 'weaponCategory', fallback: ''),
      alternatives: _readString(json, 'alternatives', fallback: ''),
      source: _readString(json, 'source', fallback: ''),
      description: _readString(json, 'description', fallback: ''),
      active: _readBool(json, 'active', fallback: true),
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
    };
  }
}

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
  final String category; // Zauberkategorie
  final String source; // Quellreferenz
  final bool active; // Im App verfuegbar und anzeigbar?

  factory SpellDef.fromJson(Map<String, dynamic> json) {
    return SpellDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      tradition: _readString(json, 'tradition', fallback: ''),
      steigerung: _readString(json, 'steigerung', fallback: 'C'),
      attributes: _readStringList(json, 'attributes'),
      availability: _readString(json, 'availability', fallback: ''),
      traits: _readString(json, 'traits', fallback: ''),
      modifier: _readString(json, 'modifier', fallback: ''),
      castingTime: _readString(json, 'castingTime', fallback: ''),
      aspCost: _readString(json, 'aspCost', fallback: ''),
      targetObject: _readString(json, 'targetObject', fallback: ''),
      range: _readString(json, 'range', fallback: ''),
      duration: _readString(json, 'duration', fallback: ''),
      modifications: _readString(json, 'modifications', fallback: ''),
      wirkung: _readString(json, 'wirkung', fallback: ''),
      variants: _readStringList(json, 'variants'),
      category: _readString(json, 'category', fallback: ''),
      source: _readString(json, 'source', fallback: ''),
      active: _readBool(json, 'active', fallback: true),
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
  final String reach; // Reichweite / Distanzklasse
  final String source; // Quellreferenz
  final bool active; // Im App verfuegbar und anzeigbar?

  factory WeaponDef.fromJson(Map<String, dynamic> json) {
    return WeaponDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      type: _readString(json, 'type', fallback: ''),
      combatSkill: _readString(json, 'combatSkill', fallback: ''),
      tp: _readString(json, 'tp', fallback: ''),
      complexity: _readString(json, 'complexity', fallback: ''),
      weaponCategory: _readString(json, 'weaponCategory', fallback: ''),
      possibleManeuvers: _readStringList(json, 'possibleManeuvers'),
      activeManeuvers: _readStringList(json, 'activeManeuvers'),
      tpkk: _readString(json, 'tpkk', fallback: ''),
      iniMod: _readInt(json, 'iniMod', fallback: 0),
      atMod: _readInt(json, 'atMod', fallback: 0),
      paMod: _readInt(json, 'paMod', fallback: 0),
      reach: _readString(json, 'reach', fallback: ''),
      source: _readString(json, 'source', fallback: ''),
      active: _readBool(json, 'active', fallback: true),
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
      'reach': reach,
      'source': source,
      'active': active,
    };
  }
}

// Liest einen String-Wert lenient: nicht-String-Werte werden via toString()
// konvertiert, null ergibt den Fallback. So bleiben alte Schemata lesbar.
String _readString(
  Map<String, dynamic> json,
  String key, {
  required String fallback,
}) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

// Liest einen int-Wert lenient: num wird via toInt() konvertiert (kürzt
// Nachkommastellen). Nützlich, wenn JSON-Dateien Floats statt Ints enthalten.
int _readInt(Map<String, dynamic> json, String key, {required int fallback}) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

// Liest einen bool-Wert; jeder Nicht-Bool-Wert ergibt den Fallback.
bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required bool fallback,
}) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  return fallback;
}

// Liest eine JSON-Liste als String-Liste. Nicht-Listen ergeben eine leere
// konstante Liste. Jedes Element wird via toString() konvertiert, um
// typentolerante JSON-Quellen zu unterstuetzen.
List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const [];
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}

/// Die neun DSA-Repraesentationen (Kuerzel fuer Zaubertradition).
const List<String> kRepresentationen = [
  'Ach', // Achaz
  'Bor', // Borbaradianer
  'Dru', // Druide
  'Elf', // Elf
  'Geo', // Geode
  'Hex', // Hexe
  'Mag', // Gildenmagier
  'Sch', // Schelm
  'Srl', // Scharlatane
];

/// Alle 34 bekannten Zauber-Merkmale aus dem Katalog.
const List<String> kMerkmale = [
  'Antimagie',
  'Beschwörung',
  'Dämonisch (Amazeroth)',
  'Dämonisch (Asfaloth)',
  'Dämonisch (Blakharaz)',
  'Dämonisch (Lolgramoth)',
  'Dämonisch (Mishkara)',
  'Dämonisch (Thargunitoth)',
  'Dämonisch (allgemein)',
  'Eigenschaften',
  'Einfluss',
  'Elementar (Eis)',
  'Elementar (Erz)',
  'Elementar (Feuer)',
  'Elementar (Humus)',
  'Elementar (Luft)',
  'Elementar (Wasser)',
  'Elementar (allgemein)',
  'Form',
  'Geisterwesen',
  'Heilung',
  'Hellsicht',
  'Herbeirufung',
  'Herrschaft',
  'Illusion',
  'Kraft',
  'Limbus',
  'Metamagie',
  'Objekt',
  'Schaden',
  'Telekinese',
  'Temporal',
  'Umwelt',
  'Verständigung',
];
