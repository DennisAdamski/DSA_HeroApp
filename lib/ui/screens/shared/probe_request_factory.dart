import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

/// Baut eine aufgeloeste Eigenschaftsprobe.
ResolvedProbeRequest buildAttributeProbeRequest({
  required String label,
  required int effectiveValue,
}) {
  return ResolvedProbeRequest(
    type: ProbeType.attribute,
    title: 'Eigenschaftsprobe: $label',
    subtitle: label,
    ruleHint: '1W20 auf den Eigenschaftswert; 1 ist immer Erfolg, 20 immer Misslingen.',
    diceSpec: const DiceSpec(count: 1, sides: 20),
    targets: <ProbeTargetValue>[ProbeTargetValue(label: label, value: effectiveValue)],
  );
}

/// Baut eine aufgeloeste Talentprobe.
ResolvedProbeRequest buildTalentProbeRequest({
  required String title,
  required List<ProbeTargetValue> targets,
  required int basePool,
  bool hasSpecialization = false,
}) {
  return ResolvedProbeRequest(
    type: ProbeType.talent,
    title: 'Talentprobe: $title',
    subtitle: targets.map((target) => target.label).join(' / '),
    ruleHint:
        '3W20 mit TaW-Kompensation; ab zwei 20ern automatisch misslungen, ab zwei 1ern automatisch gelungen mit Spezieller Erfahrung.',
    diceSpec: const DiceSpec(count: 3, sides: 20),
    targets: targets,
    basePool: basePool,
    specializationBonus: hasSpecialization ? 2 : 0,
  );
}

/// Baut eine aufgeloeste Zauberprobe.
ResolvedProbeRequest buildSpellProbeRequest({
  required String title,
  required List<ProbeTargetValue> targets,
  required int basePool,
}) {
  return ResolvedProbeRequest(
    type: ProbeType.spell,
    title: 'Zauberprobe: $title',
    subtitle: targets.map((target) => target.label).join(' / '),
    ruleHint:
        '3W20 mit ZfW-Kompensation; Varianten und spontane Modifikationen bleiben in v1 außen vor.',
    diceSpec: const DiceSpec(count: 3, sides: 20),
    targets: targets,
    basePool: basePool,
  );
}

/// Baut eine aufgeloeste Kampfprobe fuer AT, PA oder Ausweichen.
ResolvedProbeRequest buildCombatCheckProbeRequest({
  required ProbeType type,
  required String title,
  required int targetValue,
}) {
  return ResolvedProbeRequest(
    type: type,
    title: title,
    subtitle: 'Kampfprobe',
    ruleHint: '1W20 gegen den aktuellen Kampfwert; v1 wertet nur das normale <= Ergebnis.',
    diceSpec: const DiceSpec(count: 1, sides: 20),
    targets: <ProbeTargetValue>[
      ProbeTargetValue(label: title.split(':').last.trim(), value: targetValue),
    ],
  );
}

/// Baut einen Initiativwurf aus der aktiven Kampfvorschau.
ResolvedProbeRequest buildInitiativeProbeRequest({
  required String title,
  required DiceSpec diceSpec,
  int? fixedRollTotal,
}) {
  return ResolvedProbeRequest(
    type: ProbeType.initiative,
    title: title,
    subtitle: fixedRollTotal == null ? diceSpec.label : 'Aufmerksamkeit aktiv',
    ruleHint: fixedRollTotal == null
        ? 'Initiativewurf mit dem aktuellen W6/2W6-Setup.'
        : 'Aufmerksamkeit ersetzt den Wurf durch einen festen Bonus.',
    diceSpec: diceSpec,
    targets: const <ProbeTargetValue>[],
    fixedRollTotal: fixedRollTotal,
  );
}

/// Baut einen Schadenswurf aus der aktiven Kampfvorschau.
ResolvedProbeRequest buildDamageProbeRequest({
  required String title,
  required DiceSpec diceSpec,
}) {
  return ResolvedProbeRequest(
    type: ProbeType.damage,
    title: title,
    subtitle: diceSpec.label,
    ruleHint: 'Schadenswurf auf Basis der aktuell aktiven Kampfvorschau.',
    diceSpec: diceSpec,
    targets: const <ProbeTargetValue>[],
  );
}
