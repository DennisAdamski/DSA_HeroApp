part of 'combat_rules.dart';

// ---------------------------------------------------------------------------
// Nebenhand-Vorschau: Waffe, Schild oder Parierwaffe
// ---------------------------------------------------------------------------

OffhandCombatPreview? _buildOffhandPreview({
  required MainWeaponSlot? offhandWeapon,
  required OffhandEquipmentEntry? offhandEquipment,
  required OffhandModifierSnapshot offhandModifiers,
  required FalseHandModifiers falseHandModifiers,
  required Map<String, HeroTalentEntry> talents,
  required List<TalentDef> catalogTalents,
  required CombatConfig config,
  required HeroSheet effectiveSheet,
  required DerivedStats derived,
  required int beKampf,
  required int atBase,
  required int basePa,
  required int axxPaBaseBonus,
  required int iniParadeMod,
  required int kampfInitiative,
  required bool axxeleratusActive,
  required int axxTpBonus,
  required int schildarmWundMalus,
}) {
  if (offhandWeapon != null) {
    return _computeOffhandWeaponPreview(
      slot: offhandWeapon,
      talents: talents,
      catalogTalents: catalogTalents,
      config: config,
      falseHandModifiers: falseHandModifiers,
      effectiveSheet: effectiveSheet,
      derived: derived,
      beKampf: beKampf,
      atBase: atBase,
      basePa: basePa,
      axxPaBaseBonus: axxPaBaseBonus,
      iniParadeMod: iniParadeMod,
      kampfInitiative: kampfInitiative,
      axxeleratusActive: axxeleratusActive,
      axxTpBonus: axxTpBonus,
      schildarmWundMalus: schildarmWundMalus,
    );
  }
  if (offhandEquipment != null) {
    return _computeOffhandEquipmentPreview(
      offhandModifiers: offhandModifiers,
      equipment: offhandEquipment,
    );
  }
  return null;
}

OffhandCombatPreview _computeOffhandWeaponPreview({
  required MainWeaponSlot slot,
  required Map<String, HeroTalentEntry> talents,
  required List<TalentDef> catalogTalents,
  required CombatConfig config,
  required FalseHandModifiers falseHandModifiers,
  required HeroSheet effectiveSheet,
  required DerivedStats derived,
  required int beKampf,
  required int atBase,
  required int basePa,
  required int axxPaBaseBonus,
  required int iniParadeMod,
  required int kampfInitiative,
  required bool axxeleratusActive,
  required int axxTpBonus,
  required int schildarmWundMalus,
}) {
  final selectedTalent = _findTalentDefById(catalogTalents, slot.talentId);
  final legacyRanged = isRangedCombatTalent(selectedTalent);
  final isRanged = slot.isRanged || legacyRanged;

  // eBE (talentabhaengig)
  final beMod = selectedTalent == null
      ? slot.beTalentMod
      : parseBeModifier(selectedTalent.be);
  final ebe = computeEbe(beKampf: beKampf, beMod: beMod);
  final atEbePart = computeAtEbePart(ebe);
  final paEbePart = computePaEbePart(ebe);

  // Waffenmeister
  final wmEffects = computeWaffenmeisterEffects(
    waffenmeisterschaften: config.waffenmeisterschaften,
    activeWeaponType: slot.weaponType.trim().isEmpty
        ? slot.name
        : slot.weaponType,
    activeTalentId: slot.talentId,
  );

  // Spezialisierung
  final specApplies = hasCombatSpecialization(
    talents: talents,
    talentId: slot.talentId,
    weaponType: slot.weaponType.trim().isEmpty ? slot.name : slot.weaponType,
  );
  final atSpecBonus = specApplies ? (isRanged ? 2 : 1) : 0;
  final paSpecBonus = specApplies && !isRanged ? 1 : 0;

  // TP/KK
  final wmKkBase = slot.kkBase + wmEffects.tpKkBaseReduction;
  final wmKkThreshold = slot.kkThreshold + wmEffects.tpKkThresholdReduction;
  final usesTpKk = _usesTpKkThreshold(
    kkBase: slot.kkBase,
    kkThreshold: slot.kkThreshold,
  );
  final kkThreshold = usesTpKk && wmKkThreshold < 1 ? 1 : wmKkThreshold;
  final tpKk = usesTpKk
      ? computeTpKk(
          kk: effectiveSheet.attributes.kk,
          kkBase: wmKkBase,
          kkThreshold: kkThreshold,
        )
      : 0;

  // Fernkampf-spezifisch
  final activeDistanceBand = slot.rangedProfile.selectedDistanceBand;
  final activeProjectile = slot.rangedProfile.selectedProjectileOrNull;
  final distanceTpMod = isRanged ? activeDistanceBand.tpMod : 0;
  final projectileTpMod = isRanged ? (activeProjectile?.tpMod ?? 0) : 0;
  final projectileAtMod = isRanged ? (activeProjectile?.atMod ?? 0) : 0;

  final tpHerleitung = herleiteTpZuschlag(
    tpGrundwert: slot.tpFlat,
    waffenName: slot.name,
    nutztTpKk: usesTpKk,
    tpKk: tpKk,
    kk: effectiveSheet.attributes.kk,
    kkBasis: wmKkBase,
    kkSchwelle: kkThreshold,
    waffenmeisterKkBasis: wmEffects.tpKkBaseReduction,
    waffenmeisterKkSchwelle: wmEffects.tpKkThresholdReduction,
    axxeleratus: isRanged ? 0 : axxTpBonus,
    entfernung: distanceTpMod,
    entfernungLabel: isRanged ? activeDistanceBand.label : null,
    geschoss: projectileTpMod,
    geschossName: activeProjectile?.name,
  );
  final tpCalc = tpHerleitung.wert;

  // Talent AT/PA
  final talentEntry = slot.talentId.trim().isEmpty
      ? null
      : talents[slot.talentId.trim()];
  final talentAt = talentEntry?.atValue ?? 0;
  final talentPa = talentEntry?.paValue ?? 0;
  final rangedAtBase = isRanged ? derived.fkBase : 0;
  final rangedAtEbePart = isRanged ? ebe : atEbePart;
  // Die Nebenhandwaffe liegt im Schildarm; Fernkampf bleibt unberührt.
  final armMalus = isRanged ? 0 : schildarmWundMalus;

  final atHerleitung = isRanged
      ? herleiteFernkampfAt(
          fkBasis: rangedAtBase,
          talentAt: talentAt,
          talentName: selectedTalent?.name,
          waffenWm: slot.wmAt,
          waffenName: slot.name,
          ebe: rangedAtEbePart,
          spezialisierung: atSpecBonus,
          geschoss: projectileAtMod,
          geschossName: activeProjectile?.name,
        )
      : herleiteNahkampfAt(
          atBasis: atBase,
          talentAt: talentAt,
          talentName: selectedTalent?.name,
          waffenWm: slot.wmAt,
          waffenName: slot.name,
          waffenmeister: wmEffects.atWmBonus,
          ebe: ebe,
          ebeAnteil: atEbePart,
          spezialisierung: atSpecBonus,
          falscheHand: falseHandModifiers.atMod,
          falscheHandLabel: falseHandModifiers.label,
          armWunden: armMalus,
          armBezeichnung: 'Wunden Schildarm',
        );
  final at = atHerleitung.wert;
  final paHerleitung = isRanged
      ? null
      : herleiteNahkampfPa(
          paBasis: basePa,
          axxeleratus: axxPaBaseBonus,
          talentPa: talentPa,
          talentName: selectedTalent?.name,
          waffenWm: slot.wmPa,
          waffenName: slot.name,
          waffenmeister: wmEffects.paWmBonus,
          ebe: ebe,
          ebeAnteil: paEbePart,
          spezialisierung: paSpecBonus,
          falscheHand: falseHandModifiers.paMod,
          falscheHandLabel: falseHandModifiers.label,
          armWunden: armMalus,
          armBezeichnung: 'Wunden Schildarm',
        );
  final pa = paHerleitung?.wert ?? 0;
  final paMitIniHerleitung = paHerleitung == null
      ? null
      : herleitePaMitIniParade(
          pa: paHerleitung,
          iniParadeMod: iniParadeMod,
          kampfInitiative: kampfInitiative,
        );
  final paMitIniParadeMod = paMitIniHerleitung?.wert ?? 0;

  // Ladezeit
  final reloadTimeResult = computeRangedReloadTime(
    weapon: slot,
    specialRules: config.specialRules,
    axxeleratusActive: axxeleratusActive,
    talentName: selectedTalent?.name,
    reloadDivisor: wmEffects.reloadTimeHalved ? 2 : 1,
    beKampf: beKampf,
  );

  // Initiative (nur fuer Referenz)
  final iniSnapshot = _computeWeaponInitiativeSnapshot(
    slot: slot,
    // Nur die relative Waffen-INI ist relevant.
    heldenIni: Herleitung(
      bezeichnung: 'Helden-INI',
      schritte: const <HerleitungsSchritt>[],
    ),
    effectiveGe: effectiveSheet.attributes.ge,
    catalogTalents: catalogTalents,
    waffenmeisterschaften: config.waffenmeisterschaften,
  );

  final weaponTypeLabel = slot.weaponType.trim().isEmpty
      ? slot.name
      : slot.weaponType;

  return OffhandCombatPreview(
    displayName: slot.name.trim().isEmpty ? 'Nebenhand' : slot.name,
    isWeapon: true,
    isRangedWeapon: isRanged,
    at: at,
    pa: pa,
    paMitIniParadeMod: paMitIniParadeMod,
    tpExpression: buildTpExpression(slot, tpCalc),
    tpCalc: tpCalc,
    damageDiceSpec: DiceSpec(
      count: slot.tpDiceCount < 1 ? 1 : slot.tpDiceCount,
      sides: slot.tpDiceSides < 1 ? 6 : slot.tpDiceSides,
      modifier: tpCalc,
    ),
    ebe: ebe,
    beMod: beMod,
    specApplies: specApplies,
    reloadTime: isRanged ? reloadTimeResult.effectiveReloadTime : null,
    reloadTimeDisplay: isRanged ? reloadTimeResult.displayLabel : null,
    activeDistanceLabel: isRanged ? activeDistanceBand.label : null,
    activeProjectileName: isRanged ? (activeProjectile?.name ?? '') : null,
    activeProjectileCount: isRanged ? (activeProjectile?.count ?? 0) : null,
    waffenmeisterActive: wmEffects.isActive,
    waffenmeisterName: wmEffects.isActive
        ? 'Waffenmeister ($weaponTypeLabel)'
        : '',
    waffenmeisterAdditionalManeuvers: wmEffects.additionalManeuvers,
    waffenmeisterManeuverReductions: wmEffects.maneuverReductions,
    weaponInitiative: iniSnapshot.kombinierteIni,
    falseHandAtMod: isRanged ? null : falseHandModifiers.atMod,
    falseHandPaMod: isRanged ? null : falseHandModifiers.paMod,
    falseHandLabel: isRanged ? null : falseHandModifiers.label,
    schildarmWundMalus: armMalus,
    herleitungen: NebenhandHerleitungen(
      at: atHerleitung,
      pa: paHerleitung,
      paMitIniParade: paMitIniHerleitung,
      tpZuschlag: tpHerleitung,
    ),
  );
}

OffhandCombatPreview _computeOffhandEquipmentPreview({
  required OffhandModifierSnapshot offhandModifiers,
  required OffhandEquipmentEntry equipment,
}) {
  return OffhandCombatPreview(
    displayName: offhandModifiers.displayName.trim().isEmpty
        ? (equipment.isShield ? 'Schild' : 'Parierwaffe')
        : offhandModifiers.displayName,
    isShield: offhandModifiers.isShield,
    isParryWeapon: offhandModifiers.isParryWeapon,
    shieldPa: offhandModifiers.isShield ? offhandModifiers.shieldPa : null,
    mainPaMod: offhandModifiers.isParryWeapon
        ? offhandModifiers.mainPaMod
        : null,
    atMod: offhandModifiers.atMod != 0 ? offhandModifiers.atMod : null,
    iniMod: offhandModifiers.iniMod != 0 ? offhandModifiers.iniMod : null,
    requiresLinkhandViolation: offhandModifiers.requiresLinkhandViolation,
    schildarmWundMalus: offhandModifiers.isShield
        ? offhandModifiers.schildarmWundMalus
        : 0,
  );
}

class _WeaponInitiativeSnapshot {
  const _WeaponInitiativeSnapshot({
    required this.geBase,
    required this.geThreshold,
    required this.iniGe,
    required this.projectileIniMod,
    required this.waffenmeisterIniBonus,
    required this.herleitung,
  });

  final int geBase;
  final int geThreshold;
  final int iniGe;
  final int projectileIniMod;
  final int waffenmeisterIniBonus;

  /// Initiative von Held und Waffe als Herleitung.
  final Herleitung herleitung;

  int get kombinierteIni => herleitung.wert;
}

_WeaponInitiativeSnapshot _computeWeaponInitiativeSnapshot({
  required MainWeaponSlot slot,
  required Herleitung heldenIni,
  required int effectiveGe,
  required List<TalentDef> catalogTalents,
  required List<WaffenmeisterConfig> waffenmeisterschaften,
}) {
  final selectedTalent = _findTalentDefById(catalogTalents, slot.talentId);
  final legacyRanged = isRangedCombatTalent(selectedTalent);
  final isRangedWeapon = slot.isRanged || legacyRanged;
  final wmEffects = computeWaffenmeisterEffects(
    waffenmeisterschaften: waffenmeisterschaften,
    activeWeaponType: slot.weaponType.trim().isEmpty
        ? slot.name
        : slot.weaponType,
    activeTalentId: slot.talentId,
  );
  final wmKkBase = slot.kkBase + wmEffects.tpKkBaseReduction;
  final wmKkThreshold = slot.kkThreshold + wmEffects.tpKkThresholdReduction;
  final usesTpKkThreshold = _usesTpKkThreshold(
    kkBase: slot.kkBase,
    kkThreshold: slot.kkThreshold,
  );
  final kkThreshold = usesTpKkThreshold && wmKkThreshold < 1
      ? 1
      : wmKkThreshold;
  final geBase = usesTpKkThreshold ? 26 - wmKkBase : 0;
  final geThreshold = usesTpKkThreshold ? 7 - kkThreshold : 0;
  final iniGe = usesTpKkThreshold
      ? computeIniGe(
          ge: effectiveGe,
          kkBase: wmKkBase,
          kkThreshold: kkThreshold,
        )
      : 0;
  final activeProjectile = slot.rangedProfile.selectedProjectileOrNull;
  final projectileIniMod = isRangedWeapon ? (activeProjectile?.iniMod ?? 0) : 0;
  final herleitung = herleiteWaffenIni(
    heldenIni: heldenIni,
    waffenIniMod: slot.iniMod,
    waffenName: slot.name,
    nutztIniGe: usesTpKkThreshold,
    iniGe: iniGe,
    ge: effectiveGe,
    geBasis: geBase,
    geSchwelle: geThreshold,
    geschoss: projectileIniMod,
    geschossName: isRangedWeapon ? activeProjectile?.name : null,
    waffenmeister: wmEffects.iniBonus,
  );

  return _WeaponInitiativeSnapshot(
    geBase: geBase,
    geThreshold: geThreshold,
    iniGe: iniGe,
    projectileIniMod: projectileIniMod,
    waffenmeisterIniBonus: wmEffects.iniBonus,
    herleitung: herleitung,
  );
}

TalentDef? _findTalentDefById(List<TalentDef> talents, String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  for (final entry in talents) {
    if (entry.id == trimmed) {
      return entry;
    }
  }
  return null;
}

/// `0/0` kennzeichnet bewusst deaktivierte TP/KK- und INI/GE-Regeln.
bool _usesTpKkThreshold({required int kkBase, required int kkThreshold}) {
  return !(kkBase == 0 && kkThreshold == 0);
}
