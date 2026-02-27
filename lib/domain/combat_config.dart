enum OffhandMode { none, shield, parryWeapon, linkhand }

OffhandMode _offhandModeFromJson(String value) {
  switch (value.trim()) {
    case 'shield':
      return OffhandMode.shield;
    case 'parryWeapon':
      return OffhandMode.parryWeapon;
    case 'linkhand':
      return OffhandMode.linkhand;
    default:
      return OffhandMode.none;
  }
}

String _offhandModeToJson(OffhandMode value) {
  switch (value) {
    case OffhandMode.none:
      return 'none';
    case OffhandMode.shield:
      return 'shield';
    case OffhandMode.parryWeapon:
      return 'parryWeapon';
    case OffhandMode.linkhand:
      return 'linkhand';
  }
}

class MainWeaponSlot {
  const MainWeaponSlot({
    this.name = '',
    this.talentId = '',
    this.weaponType = '',
    this.distanceClass = '',
    this.kkBase = 0,
    this.kkThreshold = 1,
    this.breakFactor = 0,
    this.tpDiceCount = 1,
    this.tpDiceSides = 6,
    this.tpFlat = 0,
    this.wmAt = 0,
    this.wmPa = 0,
    this.iniMod = 0,
    this.beTalentMod = 0,
    this.isOneHanded = true,
  });

  final String name;
  final String talentId;
  final String weaponType;
  final String distanceClass;
  final int kkBase;
  final int kkThreshold;
  final int breakFactor;
  final int tpDiceCount;
  final int tpDiceSides;
  final int tpFlat;
  final int wmAt;
  final int wmPa;
  final int iniMod;
  final int beTalentMod;
  final bool isOneHanded;

  MainWeaponSlot copyWith({
    String? name,
    String? talentId,
    String? weaponType,
    String? distanceClass,
    int? kkBase,
    int? kkThreshold,
    int? breakFactor,
    int? tpDiceCount,
    int? tpDiceSides,
    int? tpFlat,
    int? wmAt,
    int? wmPa,
    int? iniMod,
    int? beTalentMod,
    bool? isOneHanded,
  }) {
    return MainWeaponSlot(
      name: name ?? this.name,
      talentId: talentId ?? this.talentId,
      weaponType: weaponType ?? this.weaponType,
      distanceClass: distanceClass ?? this.distanceClass,
      kkBase: kkBase ?? this.kkBase,
      kkThreshold: kkThreshold ?? this.kkThreshold,
      breakFactor: breakFactor ?? this.breakFactor,
      tpDiceCount: tpDiceCount ?? this.tpDiceCount,
      // W6 is fixed for the current house-rule weapon flow.
      tpDiceSides: 6,
      tpFlat: tpFlat ?? this.tpFlat,
      wmAt: wmAt ?? this.wmAt,
      wmPa: wmPa ?? this.wmPa,
      iniMod: iniMod ?? this.iniMod,
      beTalentMod: beTalentMod ?? this.beTalentMod,
      isOneHanded: isOneHanded ?? this.isOneHanded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'talentId': talentId,
      'weaponType': weaponType,
      'distanceClass': distanceClass,
      'kkBase': kkBase,
      'kkThreshold': kkThreshold,
      'breakFactor': breakFactor,
      'tpDiceCount': tpDiceCount,
      // Persist as W6 for compatibility with existing schema key.
      'tpDiceSides': 6,
      'tpFlat': tpFlat,
      'wmAt': wmAt,
      'wmPa': wmPa,
      'iniMod': iniMod,
      'beTalentMod': beTalentMod,
      'isOneHanded': isOneHanded,
    };
  }

  static MainWeaponSlot fromJson(Map<String, dynamic> json) {
    int getInt(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    String getString(String key) => (json[key] as String?) ?? '';
    return MainWeaponSlot(
      name: getString('name'),
      talentId: getString('talentId'),
      weaponType: getString('weaponType'),
      distanceClass: getString('distanceClass'),
      kkBase: getInt('kkBase', 0),
      kkThreshold: getInt('kkThreshold', 1) < 1 ? 1 : getInt('kkThreshold', 1),
      breakFactor: getInt('breakFactor', 0),
      tpDiceCount: getInt('tpDiceCount', 1),
      tpDiceSides: 6,
      tpFlat: getInt('tpFlat', 0),
      wmAt: getInt('wmAt', 0),
      wmPa: getInt('wmPa', 0),
      iniMod: getInt('iniMod', 0),
      beTalentMod: getInt('beTalentMod', 0),
      isOneHanded: (json['isOneHanded'] as bool?) ?? true,
    );
  }
}

class OffhandSlot {
  const OffhandSlot({
    this.mode = OffhandMode.none,
    this.name = '',
    this.atMod = 0,
    this.paMod = 0,
    this.iniMod = 0,
  });

  final OffhandMode mode;
  final String name;
  final int atMod;
  final int paMod;
  final int iniMod;

  OffhandSlot copyWith({
    OffhandMode? mode,
    String? name,
    int? atMod,
    int? paMod,
    int? iniMod,
  }) {
    return OffhandSlot(
      mode: mode ?? this.mode,
      name: name ?? this.name,
      atMod: atMod ?? this.atMod,
      paMod: paMod ?? this.paMod,
      iniMod: iniMod ?? this.iniMod,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': _offhandModeToJson(mode),
      'name': name,
      'atMod': atMod,
      'paMod': paMod,
      'iniMod': iniMod,
    };
  }

  static OffhandSlot fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return OffhandSlot(
      mode: _offhandModeFromJson((json['mode'] as String?) ?? 'none'),
      name: (json['name'] as String?) ?? '',
      atMod: getInt('atMod'),
      paMod: getInt('paMod'),
      iniMod: getInt('iniMod'),
    );
  }
}

class ArmorConfig {
  const ArmorConfig({
    this.rsTotal = 0,
    this.beTotalRaw = 0,
    this.armorTrainingLevel = 0,
    this.rgIActive = false,
  });

  final int rsTotal;
  final int beTotalRaw;
  final int armorTrainingLevel;
  final bool rgIActive;

  ArmorConfig copyWith({
    int? rsTotal,
    int? beTotalRaw,
    int? armorTrainingLevel,
    bool? rgIActive,
  }) {
    return ArmorConfig(
      rsTotal: rsTotal ?? this.rsTotal,
      beTotalRaw: beTotalRaw ?? this.beTotalRaw,
      armorTrainingLevel: armorTrainingLevel ?? this.armorTrainingLevel,
      rgIActive: rgIActive ?? this.rgIActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rsTotal': rsTotal,
      'beTotalRaw': beTotalRaw,
      'armorTrainingLevel': armorTrainingLevel,
      'rgIActive': rgIActive,
    };
  }

  static ArmorConfig fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ArmorConfig(
      rsTotal: getInt('rsTotal'),
      beTotalRaw: getInt('beTotalRaw'),
      armorTrainingLevel: getInt('armorTrainingLevel'),
      rgIActive: (json['rgIActive'] as bool?) ?? false,
    );
  }
}

class CombatSpecialRules {
  const CombatSpecialRules({
    this.kampfreflexe = false,
    this.kampfgespuer = false,
    this.ausweichenI = false,
    this.ausweichenII = false,
    this.ausweichenIII = false,
    this.schildkampfI = false,
    this.schildkampfII = false,
    this.parierwaffenI = false,
    this.parierwaffenII = false,
    this.linkhandActive = false,
    this.flink = false,
    this.behaebig = false,
    this.axxeleratusActive = false,
    this.activeManeuvers = const <String>[],
  });

  final bool kampfreflexe;
  final bool kampfgespuer;
  final bool ausweichenI;
  final bool ausweichenII;
  final bool ausweichenIII;
  final bool schildkampfI;
  final bool schildkampfII;
  final bool parierwaffenI;
  final bool parierwaffenII;
  final bool linkhandActive;
  final bool flink;
  final bool behaebig;
  final bool axxeleratusActive;
  final List<String> activeManeuvers;

  CombatSpecialRules copyWith({
    bool? kampfreflexe,
    bool? kampfgespuer,
    bool? ausweichenI,
    bool? ausweichenII,
    bool? ausweichenIII,
    bool? schildkampfI,
    bool? schildkampfII,
    bool? parierwaffenI,
    bool? parierwaffenII,
    bool? linkhandActive,
    bool? flink,
    bool? behaebig,
    bool? axxeleratusActive,
    List<String>? activeManeuvers,
  }) {
    return CombatSpecialRules(
      kampfreflexe: kampfreflexe ?? this.kampfreflexe,
      kampfgespuer: kampfgespuer ?? this.kampfgespuer,
      ausweichenI: ausweichenI ?? this.ausweichenI,
      ausweichenII: ausweichenII ?? this.ausweichenII,
      ausweichenIII: ausweichenIII ?? this.ausweichenIII,
      schildkampfI: schildkampfI ?? this.schildkampfI,
      schildkampfII: schildkampfII ?? this.schildkampfII,
      parierwaffenI: parierwaffenI ?? this.parierwaffenI,
      parierwaffenII: parierwaffenII ?? this.parierwaffenII,
      linkhandActive: linkhandActive ?? this.linkhandActive,
      flink: flink ?? this.flink,
      behaebig: behaebig ?? this.behaebig,
      axxeleratusActive: axxeleratusActive ?? this.axxeleratusActive,
      activeManeuvers: _normalizeStringList(
        activeManeuvers ?? this.activeManeuvers,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kampfreflexe': kampfreflexe,
      'kampfgespuer': kampfgespuer,
      'ausweichenI': ausweichenI,
      'ausweichenII': ausweichenII,
      'ausweichenIII': ausweichenIII,
      'schildkampfI': schildkampfI,
      'schildkampfII': schildkampfII,
      'parierwaffenI': parierwaffenI,
      'parierwaffenII': parierwaffenII,
      'linkhandActive': linkhandActive,
      'flink': flink,
      'behaebig': behaebig,
      'axxeleratusActive': axxeleratusActive,
      'activeManeuvers': _normalizeStringList(activeManeuvers),
    };
  }

  static CombatSpecialRules fromJson(Map<String, dynamic> json) {
    bool getBool(String key) => (json[key] as bool?) ?? false;
    return CombatSpecialRules(
      kampfreflexe: getBool('kampfreflexe'),
      kampfgespuer: getBool('kampfgespuer'),
      ausweichenI: getBool('ausweichenI'),
      ausweichenII: getBool('ausweichenII'),
      ausweichenIII: getBool('ausweichenIII'),
      schildkampfI: getBool('schildkampfI'),
      schildkampfII: getBool('schildkampfII'),
      parierwaffenI: getBool('parierwaffenI'),
      parierwaffenII: getBool('parierwaffenII'),
      linkhandActive: getBool('linkhandActive'),
      flink: getBool('flink'),
      behaebig: getBool('behaebig'),
      axxeleratusActive: getBool('axxeleratusActive'),
      activeManeuvers: _normalizeStringList(
        (json['activeManeuvers'] as List?) ?? const <dynamic>[],
      ),
    );
  }
}

class CombatManualMods {
  const CombatManualMods({
    this.iniMod = 0,
    this.ausweichenMod = 0,
    this.atMod = 0,
    this.paMod = 0,
  });

  final int iniMod;
  final int ausweichenMod;
  final int atMod;
  final int paMod;

  CombatManualMods copyWith({
    int? iniMod,
    int? ausweichenMod,
    int? atMod,
    int? paMod,
  }) {
    return CombatManualMods(
      iniMod: iniMod ?? this.iniMod,
      ausweichenMod: ausweichenMod ?? this.ausweichenMod,
      atMod: atMod ?? this.atMod,
      paMod: paMod ?? this.paMod,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iniMod': iniMod,
      'ausweichenMod': ausweichenMod,
      'atMod': atMod,
      'paMod': paMod,
    };
  }

  static CombatManualMods fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return CombatManualMods(
      iniMod: getInt('iniMod'),
      ausweichenMod: getInt('ausweichenMod'),
      atMod: getInt('atMod'),
      paMod: getInt('paMod'),
    );
  }
}

class CombatConfig {
  const CombatConfig({
    this.mainWeapon = const MainWeaponSlot(),
    this.weapons = const <MainWeaponSlot>[],
    this.selectedWeaponIndex = 0,
    this.offhand = const OffhandSlot(),
    this.armor = const ArmorConfig(),
    this.specialRules = const CombatSpecialRules(),
    this.manualMods = const CombatManualMods(),
  });

  final MainWeaponSlot mainWeapon;
  final List<MainWeaponSlot> weapons;
  final int selectedWeaponIndex;
  final OffhandSlot offhand;
  final ArmorConfig armor;
  final CombatSpecialRules specialRules;
  final CombatManualMods manualMods;

  List<MainWeaponSlot> get weaponSlots {
    if (weapons.isEmpty) {
      return <MainWeaponSlot>[mainWeapon];
    }
    return List<MainWeaponSlot>.from(weapons, growable: false);
  }

  MainWeaponSlot get selectedWeapon {
    final slots = weaponSlots;
    return slots[_normalizeWeaponIndex(selectedWeaponIndex, slots.length)];
  }

  CombatConfig copyWith({
    MainWeaponSlot? mainWeapon,
    List<MainWeaponSlot>? weapons,
    int? selectedWeaponIndex,
    OffhandSlot? offhand,
    ArmorConfig? armor,
    CombatSpecialRules? specialRules,
    CombatManualMods? manualMods,
  }) {
    final nextWeapons = List<MainWeaponSlot>.from(
      weapons ?? weaponSlots,
      growable: false,
    );
    final nextSelectedIndex = _normalizeWeaponIndex(
      selectedWeaponIndex ?? this.selectedWeaponIndex,
      nextWeapons.length,
    );
    final nextMain = mainWeapon ?? nextWeapons[nextSelectedIndex];
    final normalizedWeapons = List<MainWeaponSlot>.from(nextWeapons);
    normalizedWeapons[nextSelectedIndex] = nextMain;

    return CombatConfig(
      mainWeapon: nextMain,
      weapons: List<MainWeaponSlot>.unmodifiable(normalizedWeapons),
      selectedWeaponIndex: nextSelectedIndex,
      offhand: offhand ?? this.offhand,
      armor: armor ?? this.armor,
      specialRules: specialRules ?? this.specialRules,
      manualMods: manualMods ?? this.manualMods,
    );
  }

  Map<String, dynamic> toJson() {
    final slots = weaponSlots;
    final index = _normalizeWeaponIndex(selectedWeaponIndex, slots.length);
    final activeWeapon = slots[index];
    return {
      'mainWeapon': activeWeapon.toJson(),
      'weapons': slots.map((entry) => entry.toJson()).toList(growable: false),
      'selectedWeaponIndex': index,
      'offhand': offhand.toJson(),
      'armor': armor.toJson(),
      'specialRules': specialRules.toJson(),
      'manualMods': manualMods.toJson(),
    };
  }

  static CombatConfig fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> readMap(String key) {
      final raw = json[key];
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is Map) {
        return raw.cast<String, dynamic>();
      }
      return const <String, dynamic>{};
    }

    final legacyMain = MainWeaponSlot.fromJson(readMap('mainWeapon'));
    final rawWeapons = (json['weapons'] as List?) ?? const <dynamic>[];
    final parsedWeapons = rawWeapons
        .whereType<Map>()
        .map((entry) => MainWeaponSlot.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
    final slots = parsedWeapons.isEmpty
        ? <MainWeaponSlot>[legacyMain]
        : parsedWeapons;
    final selectedIndex = _normalizeWeaponIndex(
      (json['selectedWeaponIndex'] as num?)?.toInt() ?? 0,
      slots.length,
    );

    return CombatConfig(
      mainWeapon: slots[selectedIndex],
      weapons: slots,
      selectedWeaponIndex: selectedIndex,
      offhand: OffhandSlot.fromJson(readMap('offhand')),
      armor: ArmorConfig.fromJson(readMap('armor')),
      specialRules: CombatSpecialRules.fromJson(readMap('specialRules')),
      manualMods: CombatManualMods.fromJson(readMap('manualMods')),
    );
  }
}

int _normalizeWeaponIndex(int value, int length) {
  if (length <= 1) {
    return 0;
  }
  if (value < 0) {
    return 0;
  }
  if (value >= length) {
    return length - 1;
  }
  return value;
}

List<String> _normalizeStringList(Iterable<dynamic> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final text = value.toString().trim();
    if (text.isEmpty || seen.contains(text)) {
      continue;
    }
    seen.add(text);
    normalized.add(text);
  }
  return List<String>.unmodifiable(normalized);
}
