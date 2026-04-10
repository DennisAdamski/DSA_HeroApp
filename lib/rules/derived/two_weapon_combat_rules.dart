import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/maneuver_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

const String _beidhaendigerKampfIId = 'ksf_beidhaendiger_kampf_i';
const String _beidhaendigerKampfIIId = 'ksf_beidhaendiger_kampf_ii';
const String _todVonLinksId = 'ksf_tod_von_links';
const String _doppelangriffId = 'man_doppelangriff';

/// Beschreibt die aktuell gewaehlte beidhändige Kampfaktion.
enum TwoWeaponActionType {
  none,
  extraOffhandAttack,
  extraOffhandParry,
  doubleAttack,
}

/// Kapselt die Mali fuer Aktionen mit der falschen Hand.
class FalseHandModifiers {
  /// Erzeugt ein unveraenderliches Snapshot-Objekt fuer die Falsche-Hand-Regel.
  const FalseHandModifiers({
    required this.atMod,
    required this.paMod,
    required this.label,
  });

  /// Attacke-Modifikator fuer die falsche Hand.
  final int atMod;

  /// Parade-Modifikator fuer die falsche Hand.
  final int paMod;

  /// Lesbare Quellenbezeichnung fuer den aktuell aktiven Modifikator.
  final String label;
}

/// Repräsentiert eine konkrete beidhändige Aktionsoption fuer die Vorschau.
class TwoWeaponActionOption {
  /// Erzeugt eine unveraenderliche Aktionsbeschreibung fuer die Kampfansicht.
  const TwoWeaponActionOption({
    required this.type,
    required this.label,
    required this.description,
    required this.isAvailable,
    this.availabilityReason = '',
    this.mainAttackTarget,
    this.offhandAttackTarget,
    this.offhandParryTarget,
    this.exclusionNotes = const <String>[],
  });

  /// Stabiler Typ der Aktionsoption.
  final TwoWeaponActionType type;

  /// Anzeigename fuer Chip und Detailbereich.
  final String label;

  /// Kurzbeschreibung der Quelle oder Nutzung.
  final String description;

  /// Kennzeichnet, ob die Option mit der aktuellen Waffenhaltung nutzbar ist.
  final bool isAvailable;

  /// Begruendung, warum die Aktion aktuell nicht verfuegbar ist.
  final String availabilityReason;

  /// Zielfwert der Haupthand-AT, falls die Aktion einen Kontextwert liefert.
  final int? mainAttackTarget;

  /// Zielfwert der Nebenhand-AT, falls die Aktion einen Kontextwert liefert.
  final int? offhandAttackTarget;

  /// Zielfwert der Nebenhand-PA, falls die Aktion einen Kontextwert liefert.
  final int? offhandParryTarget;

  /// Zusaetzliche Exklusivitaets- oder Konflikthinweise.
  final List<String> exclusionNotes;
}

/// Verdichtet alle beidhändigen Kampfinformationen fuer die Vorschau.
class TwoWeaponCombatSnapshot {
  /// Erzeugt einen unveraenderlichen Snapshot fuer beidhändigen Kampf.
  const TwoWeaponCombatSnapshot({
    required this.falseHandModifiers,
    required this.hasOffhandWeapon,
    required this.hasParryWeapon,
    required this.hasShield,
    required this.attackCapablePair,
    required this.options,
    required this.notes,
  });

  /// Aktive Mali fuer Aktionen mit der falschen Hand.
  final FalseHandModifiers falseHandModifiers;

  /// Kennzeichnet eine zweite Waffe in der Nebenhand.
  final bool hasOffhandWeapon;

  /// Kennzeichnet eine Parierwaffe in der Nebenhand.
  final bool hasParryWeapon;

  /// Kennzeichnet einen Schild in der Nebenhand.
  final bool hasShield;

  /// Kennzeichnet zwei regeltechnisch attackefaehige Einhandwaffen.
  final bool attackCapablePair;

  /// Alle relevanten Aktionsoptionen fuer die aktuelle Haltung.
  final List<TwoWeaponActionOption> options;

  /// Allgemeine Hinweise zu Konflikten und Voraussetzungen.
  final List<String> notes;

  /// Gibt an, ob ueberhaupt eine beidhändige Situation vorliegt.
  bool get isRelevant => hasOffhandWeapon || hasParryWeapon || hasShield;

  /// Gibt an, ob mindestens eine Aktion aktuell verfuegbar ist.
  bool get hasAvailableOptions => options.any((option) => option.isAvailable);

  /// Liefert die passende Option zu einem Aktions-Typ oder `null`.
  TwoWeaponActionOption? optionFor(TwoWeaponActionType type) {
    for (final option in options) {
      if (option.type == type) {
        return option;
      }
    }
    return null;
  }
}

/// Berechnet die Mali fuer Angriffe und Paraden mit der falschen Hand.
FalseHandModifiers computeFalseHandModifiers({
  required CombatSpecialRules specialRules,
}) {
  if (_hasCombatAbility(specialRules, _beidhaendigerKampfIIId)) {
    return const FalseHandModifiers(
      atMod: 0,
      paMod: 0,
      label: 'Beidhändiger Kampf II',
    );
  }
  if (_hasCombatAbility(specialRules, _beidhaendigerKampfIId)) {
    return const FalseHandModifiers(
      atMod: -3,
      paMod: -3,
      label: 'Beidhändiger Kampf I',
    );
  }
  if (specialRules.linkhandActive) {
    return const FalseHandModifiers(atMod: -6, paMod: -6, label: 'Linkhand');
  }
  return const FalseHandModifiers(atMod: -9, paMod: -9, label: 'Falsche Hand');
}

/// Leitet alle beidhändigen Aktionsoptionen aus Waffenhaltung und SF ab.
TwoWeaponCombatSnapshot computeTwoWeaponCombatSnapshot({
  required CombatSpecialRules specialRules,
  required MainWeaponSlot mainWeapon,
  required MainWeaponSlot? offhandWeapon,
  required OffhandEquipmentEntry? offhandEquipment,
  required FalseHandModifiers falseHandModifiers,
  required int mainAttackTarget,
  required int mainParryTarget,
  required int? offhandAttackTarget,
  required int? offhandParryTarget,
  required bool offhandRequiresLinkhandViolation,
}) {
  final hasOffhandWeapon = offhandWeapon != null;
  final hasParryWeapon =
      offhandEquipment?.type == OffhandEquipmentType.parryWeapon;
  final hasShield = offhandEquipment?.type == OffhandEquipmentType.shield;
  final attackCapablePair =
      offhandWeapon != null &&
      mainWeapon.isOneHanded &&
      offhandWeapon.isOneHanded &&
      !mainWeapon.isRanged &&
      !offhandWeapon.isRanged;
  final hasBeidhaendigerKampfI = _hasCombatAbility(
    specialRules,
    _beidhaendigerKampfIId,
  );
  final hasBeidhaendigerKampfII = _hasCombatAbility(
    specialRules,
    _beidhaendigerKampfIIId,
  );
  final hasTodVonLinks = _hasCombatAbility(specialRules, _todVonLinksId);
  final hasDoppelangriff = _hasManeuver(specialRules, _doppelangriffId);
  final distanceClassesCompatible = _distanceClassesCompatible(
    mainWeapon: mainWeapon,
    offhandWeapon: offhandWeapon,
  );
  final identicalWeapons = _identicalWeapons(
    mainWeapon: mainWeapon,
    offhandWeapon: offhandWeapon,
  );

  final options = <TwoWeaponActionOption>[];

  if (hasOffhandWeapon || hasParryWeapon) {
    options.add(
      _buildExtraOffhandAttackOption(
        hasBeidhaendigerKampfII: hasBeidhaendigerKampfII,
        hasTodVonLinks: hasTodVonLinks,
        attackCapablePair: attackCapablePair,
        hasParryWeapon: hasParryWeapon,
        offhandRequiresLinkhandViolation: offhandRequiresLinkhandViolation,
        offhandAttackTarget: offhandAttackTarget,
      ),
    );
    options.add(
      _buildExtraOffhandParryOption(
        hasBeidhaendigerKampfII: hasBeidhaendigerKampfII,
        hasParryWeapon: hasParryWeapon,
        hasParierwaffenII: specialRules.parierwaffenII,
        attackCapablePair: attackCapablePair,
        offhandRequiresLinkhandViolation: offhandRequiresLinkhandViolation,
        offhandParryTarget: offhandParryTarget,
        parryWeaponParryTarget: mainParryTarget,
      ),
    );
  }

  if (hasOffhandWeapon) {
    options.add(
      _buildDoubleAttackOption(
        hasBeidhaendigerKampfI: hasBeidhaendigerKampfI,
        hasDoppelangriff: hasDoppelangriff,
        attackCapablePair: attackCapablePair,
        distanceClassesCompatible: distanceClassesCompatible,
        identicalWeapons: identicalWeapons,
        mainAttackTarget: mainAttackTarget,
        offhandAttackTarget: offhandAttackTarget,
      ),
    );
  }

  final notes = <String>[];
  if (hasOffhandWeapon) {
    notes.add(
      'Nebenhand nutzt ${falseHandModifiers.label}: AT ${_signed(falseHandModifiers.atMod)}, PA ${_signed(falseHandModifiers.paMod)}.',
    );
  }
  if ((hasBeidhaendigerKampfII &&
          (specialRules.parierwaffenII || hasTodVonLinks)) ||
      (specialRules.parierwaffenII && hasTodVonLinks)) {
    notes.add(
      'Zusatzaktionen aus Beidhändiger Kampf II, Parierwaffen II und Tod von Links sind nicht kumulativ.',
    );
  }
  if (hasOffhandWeapon) {
    notes.add(
      'Doppelangriff schließt Zusatzangriffe und Zusatzparaden derselben Kampfrunde aus.',
    );
  }

  return TwoWeaponCombatSnapshot(
    falseHandModifiers: falseHandModifiers,
    hasOffhandWeapon: hasOffhandWeapon,
    hasParryWeapon: hasParryWeapon,
    hasShield: hasShield,
    attackCapablePair: attackCapablePair,
    options: List<TwoWeaponActionOption>.unmodifiable(options),
    notes: List<String>.unmodifiable(notes),
  );
}

/// Baut die Zusatzangriffs-Option fuer Nebenhand oder Parierwaffe.
TwoWeaponActionOption _buildExtraOffhandAttackOption({
  required bool hasBeidhaendigerKampfII,
  required bool hasTodVonLinks,
  required bool attackCapablePair,
  required bool hasParryWeapon,
  required bool offhandRequiresLinkhandViolation,
  required int? offhandAttackTarget,
}) {
  final sources = <String>[];
  if (hasBeidhaendigerKampfII && attackCapablePair) {
    sources.add('Beidhändiger Kampf II');
  }
  if (hasTodVonLinks && hasParryWeapon) {
    sources.add('Tod von Links');
  }
  if (sources.isEmpty) {
    return const TwoWeaponActionOption(
      type: TwoWeaponActionType.extraOffhandAttack,
      label: 'Zusatzangriff links',
      description: 'Keine zusätzliche Angriffsquelle aktiv.',
      isAvailable: false,
      availabilityReason:
          'Aktiviere Beidhändiger Kampf II oder Tod von Links für einen Zusatzangriff.',
    );
  }
  if (offhandRequiresLinkhandViolation) {
    return TwoWeaponActionOption(
      type: TwoWeaponActionType.extraOffhandAttack,
      label: 'Zusatzangriff links',
      description: 'Quelle: ${sources.join(' / ')}',
      isAvailable: false,
      availabilityReason: 'Parierwaffen erfordern Linkhand.',
    );
  }
  if (offhandAttackTarget == null) {
    return TwoWeaponActionOption(
      type: TwoWeaponActionType.extraOffhandAttack,
      label: 'Zusatzangriff links',
      description: 'Quelle: ${sources.join(' / ')}',
      isAvailable: false,
      availabilityReason:
          'Für diese Nebenhand liegt noch kein Angriffsprofil vor.',
      exclusionNotes: const <String>[
        'Nicht kumulativ mit anderen Zusatzaktionen derselben Kampfrunde.',
      ],
    );
  }
  return TwoWeaponActionOption(
    type: TwoWeaponActionType.extraOffhandAttack,
    label: 'Zusatzangriff links',
    description: 'Quelle: ${sources.join(' / ')}',
    isAvailable: true,
    offhandAttackTarget: offhandAttackTarget,
    exclusionNotes: const <String>[
      'Nicht kumulativ mit Doppelangriff oder zusätzlichen Paraden.',
    ],
  );
}

/// Baut die Zusatzparaden-Option fuer Nebenhand oder Parierwaffe.
TwoWeaponActionOption _buildExtraOffhandParryOption({
  required bool hasBeidhaendigerKampfII,
  required bool hasParryWeapon,
  required bool hasParierwaffenII,
  required bool attackCapablePair,
  required bool offhandRequiresLinkhandViolation,
  required int? offhandParryTarget,
  required int parryWeaponParryTarget,
}) {
  final sources = <String>[];
  int? parryTarget;
  if (hasBeidhaendigerKampfII && attackCapablePair) {
    sources.add('Beidhändiger Kampf II');
    parryTarget = offhandParryTarget;
  }
  if (hasParierwaffenII && hasParryWeapon) {
    sources.add('Parierwaffen II');
    parryTarget ??= parryWeaponParryTarget;
  }
  if (sources.isEmpty) {
    return const TwoWeaponActionOption(
      type: TwoWeaponActionType.extraOffhandParry,
      label: 'Zusatzparade links',
      description: 'Keine zusätzliche Abwehrquelle aktiv.',
      isAvailable: false,
      availabilityReason:
          'Aktiviere Beidhändiger Kampf II oder Parierwaffen II für eine Zusatzparade.',
    );
  }
  if (offhandRequiresLinkhandViolation) {
    return TwoWeaponActionOption(
      type: TwoWeaponActionType.extraOffhandParry,
      label: 'Zusatzparade links',
      description: 'Quelle: ${sources.join(' / ')}',
      isAvailable: false,
      availabilityReason: 'Parierwaffen erfordern Linkhand.',
    );
  }
  if (parryTarget == null) {
    return TwoWeaponActionOption(
      type: TwoWeaponActionType.extraOffhandParry,
      label: 'Zusatzparade links',
      description: 'Quelle: ${sources.join(' / ')}',
      isAvailable: false,
      availabilityReason:
          'Für diese Nebenhand liegt kein separater Paradewert vor.',
    );
  }
  return TwoWeaponActionOption(
    type: TwoWeaponActionType.extraOffhandParry,
    label: 'Zusatzparade links',
    description: 'Quelle: ${sources.join(' / ')}',
    isAvailable: true,
    offhandParryTarget: parryTarget,
    exclusionNotes: const <String>[
      'Nicht kumulativ mit Doppelangriff oder zusätzlichen Angriffen.',
    ],
  );
}

/// Baut die Doppelangriff-Option fuer zwei attackefaehige Einhandwaffen.
TwoWeaponActionOption _buildDoubleAttackOption({
  required bool hasBeidhaendigerKampfI,
  required bool hasDoppelangriff,
  required bool attackCapablePair,
  required bool distanceClassesCompatible,
  required bool identicalWeapons,
  required int mainAttackTarget,
  required int? offhandAttackTarget,
}) {
  if (!attackCapablePair) {
    return const TwoWeaponActionOption(
      type: TwoWeaponActionType.doubleAttack,
      label: 'Doppelangriff',
      description: 'Gleichzeitiger Angriff mit beiden Waffen.',
      isAvailable: false,
      availabilityReason: 'Beide Waffen müssen einhändige Nahkampfwaffen sein.',
    );
  }
  if (!hasBeidhaendigerKampfI) {
    return const TwoWeaponActionOption(
      type: TwoWeaponActionType.doubleAttack,
      label: 'Doppelangriff',
      description: 'Gleichzeitiger Angriff mit beiden Waffen.',
      isAvailable: false,
      availabilityReason: 'Beidhändiger Kampf I fehlt.',
    );
  }
  if (!hasDoppelangriff) {
    return const TwoWeaponActionOption(
      type: TwoWeaponActionType.doubleAttack,
      label: 'Doppelangriff',
      description: 'Gleichzeitiger Angriff mit beiden Waffen.',
      isAvailable: false,
      availabilityReason: 'Das Manöver Doppelangriff ist aktuell nicht aktiv.',
    );
  }
  if (!distanceClassesCompatible) {
    return const TwoWeaponActionOption(
      type: TwoWeaponActionType.doubleAttack,
      label: 'Doppelangriff',
      description: 'Gleichzeitiger Angriff mit beiden Waffen.',
      isAvailable: false,
      availabilityReason: 'Beide Waffen brauchen dieselbe Distanzklasse.',
    );
  }
  if (offhandAttackTarget == null) {
    return const TwoWeaponActionOption(
      type: TwoWeaponActionType.doubleAttack,
      label: 'Doppelangriff',
      description: 'Gleichzeitiger Angriff mit beiden Waffen.',
      isAvailable: false,
      availabilityReason: 'Für die Nebenhand fehlt ein AT-Wert.',
    );
  }
  final offhandPenalty = identicalWeapons ? -2 : -6;
  return TwoWeaponActionOption(
    type: TwoWeaponActionType.doubleAttack,
    label: 'Doppelangriff',
    description: identicalWeapons
        ? 'Beide Waffen sind identisch.'
        : 'Nicht identische Waffen erschweren die Nebenhand zusätzlich.',
    isAvailable: true,
    mainAttackTarget: mainAttackTarget - 2,
    offhandAttackTarget: offhandAttackTarget + offhandPenalty,
    exclusionNotes: const <String>[
      'Schließt Zusatzangriffe und Zusatzparaden derselben Kampfrunde aus.',
      'Beide Teilangriffe werden separat gewürfelt.',
    ],
  );
}

bool _hasCombatAbility(CombatSpecialRules rules, String abilityId) {
  return rules.activeCombatSpecialAbilityIds.contains(abilityId);
}

bool _hasManeuver(CombatSpecialRules rules, String maneuverId) {
  final normalized = normalizeManeuverIds(rules.activeManeuvers);
  return normalized.contains(maneuverId);
}

bool _distanceClassesCompatible({
  required MainWeaponSlot mainWeapon,
  required MainWeaponSlot? offhandWeapon,
}) {
  if (offhandWeapon == null) {
    return false;
  }
  final mainDistance = normalizeCombatToken(mainWeapon.distanceClass);
  final offhandDistance = normalizeCombatToken(offhandWeapon.distanceClass);
  if (mainDistance.isEmpty || offhandDistance.isEmpty) {
    return true;
  }
  return mainDistance == offhandDistance;
}

bool _identicalWeapons({
  required MainWeaponSlot mainWeapon,
  required MainWeaponSlot? offhandWeapon,
}) {
  if (offhandWeapon == null) {
    return false;
  }
  final mainToken = normalizeCombatToken(
    mainWeapon.weaponType.trim().isEmpty
        ? mainWeapon.name
        : mainWeapon.weaponType,
  );
  final offhandToken = normalizeCombatToken(
    offhandWeapon.weaponType.trim().isEmpty
        ? offhandWeapon.name
        : offhandWeapon.weaponType,
  );
  return mainToken.isNotEmpty && mainToken == offhandToken;
}

String _signed(int value) {
  if (value > 0) {
    return '+$value';
  }
  return value.toString();
}
