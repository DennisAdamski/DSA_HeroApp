class RulesCatalog {
  const RulesCatalog({
    required this.version,
    required this.source,
    required this.talents,
    required this.spells,
    required this.weapons,
    this.metadata = const {},
  });

  final String version;
  final String source;
  final List<TalentDef> talents;
  final List<SpellDef> spells;
  final List<WeaponDef> weapons;
  final Map<String, dynamic> metadata;

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

  final String id;
  final String name;
  final String group;
  final String steigerung;
  final List<String> attributes;
  final String type;
  final String be;
  final String weaponCategory;
  final String alternatives;
  final String source;
  final String description;
  final bool active;

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
    this.range = '',
    this.duration = '',
    this.modifications = '',
    this.category = '',
    this.source = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String tradition;
  final String steigerung;
  final List<String> attributes;
  final String availability;
  final String traits;
  final String modifier;
  final String castingTime;
  final String aspCost;
  final String range;
  final String duration;
  final String modifications;
  final String category;
  final String source;
  final bool active;

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
      range: _readString(json, 'range', fallback: ''),
      duration: _readString(json, 'duration', fallback: ''),
      modifications: _readString(json, 'modifications', fallback: ''),
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
      'range': range,
      'duration': duration,
      'modifications': modifications,
      'category': category,
      'source': source,
      'active': active,
    };
  }
}

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
  final String type;
  final String combatSkill;
  final String tp;
  final String complexity;
  final String weaponCategory;
  final List<String> possibleManeuvers;
  final List<String> activeManeuvers;
  final String tpkk;
  final int iniMod;
  final int atMod;
  final int paMod;
  final String reach;
  final String source;
  final bool active;

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

String _readString(Map<String, dynamic> json, String key, {required String fallback}) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

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

bool _readBool(Map<String, dynamic> json, String key, {required bool fallback}) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  return fallback;
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const [];
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}
