/// Gemeinsame Probearten fuer die Wuerfel-Engine.
enum ProbeType {
  genericRoll,
  attribute,
  talent,
  spell,
  combatAttack,
  combatParry,
  dodge,
  initiative,
  damage,
}

/// Kennzeichnet automatische Sonderausgaenge einer Probe.
enum AutomaticOutcome { none, success, failure }

/// Quelle der Wuerfelergebnisse.
enum ProbeRollMode { digital, manual }

/// Rohbeschreibung eines Wuerfelpools wie `3W20` oder `2W6+4`.
class DiceSpec {
  /// Erzeugt eine immutable Wuerfelbeschreibung.
  const DiceSpec({required this.count, required this.sides, this.modifier = 0});

  /// Anzahl der zu wuerfelnden Wuerfel.
  final int count;

  /// Seitenzahl der einzelnen Wuerfel.
  final int sides;

  /// Fester Modifikator, der auf die Summe addiert wird.
  final int modifier;

  /// Formatiert die Wuerfelbeschreibung als lesbaren Ausdruck.
  String get label {
    final sign = modifier >= 0 ? '+' : '';
    if (modifier == 0) {
      return '${count}W$sides';
    }
    return '${count}W$sides$sign$modifier';
  }
}

/// Ein einzelner Zielwert innerhalb einer Probe.
class ProbeTargetValue {
  /// Erzeugt einen Zielwert mit Anzeigename.
  const ProbeTargetValue({required this.label, required this.value});

  /// Anzeigename des Zielwerts, z. B. `MU` oder `AT`.
  final String label;

  /// Effektiver Ausgangswert vor situativen Anpassungen.
  final int value;
}

/// Vollstaendig aufgeloeste Probe fuer die UI und die Regelengine.
class ResolvedProbeRequest {
  /// Erzeugt eine immutable Probeanfrage.
  const ResolvedProbeRequest({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.ruleHint,
    required this.diceSpec,
    required this.targets,
    this.basePool = 0,
    this.specializationBonus = 0,
    this.initialSpecializationApplied = false,
    this.initialSituationalModifier = 0,
    this.fixedRollTotal,
  });

  /// Fachliche Probeart.
  final ProbeType type;

  /// Anzeigename der Probe.
  final String title;

  /// Sekundaere Beschreibung, z. B. Eigenschaftskette oder Waffe.
  final String subtitle;

  /// Kurzer Regelhinweis fuer den Dialogkopf.
  final String ruleHint;

  /// Wuerfelpool der Probe.
  final DiceSpec diceSpec;

  /// Zielwerte, gegen die gewertet wird.
  final List<ProbeTargetValue> targets;

  /// Startpool fuer Talent-/Zauberkompensation.
  final int basePool;

  /// Optionaler Spezialisierungsbonus fuer Talentproben.
  final int specializationBonus;

  /// Initialer Zustand des Spezialisierungs-Toggles.
  final bool initialSpecializationApplied;

  /// Initialer situativer Modifikator.
  final int initialSituationalModifier;

  /// Fester Ersatz fuer den Wurf, z. B. Aufmerksamkeit mit `+6/+12`.
  final int? fixedRollTotal;

  /// Kennzeichnet Talent- und Zauberproben mit Kompensationspool.
  bool get usesCompensationPool =>
      type == ProbeType.talent || type == ProbeType.spell;

  /// Kennzeichnet reine Vergleichsproben mit einem Zielwert.
  bool get usesBinaryCheck =>
      type == ProbeType.attribute ||
      type == ProbeType.combatAttack ||
      type == ProbeType.combatParry ||
      type == ProbeType.dodge;

  /// Kennzeichnet Proben, die nur ein Gesamtergebnis liefern.
  bool get usesSummedTotal =>
      type == ProbeType.initiative || type == ProbeType.damage;

  /// Kennzeichnet einen verfuegbaren Spezialisierungs-Toggle.
  bool get supportsSpecialization => specializationBonus != 0;
}

/// Konkrete Eingabe einer Probe, digital erzeugt oder manuell gesetzt.
class ProbeRollInput {
  /// Erzeugt eine immutable Wurfeingabe.
  const ProbeRollInput({
    required this.mode,
    required this.diceValues,
    required this.situationalModifier,
    required this.specializationApplied,
  });

  /// Herkunft der Wuerfelwerte.
  final ProbeRollMode mode;

  /// Einzelne Wuerfelwerte in Wurfreihenfolge.
  final List<int> diceValues;

  /// Situativer Modifikator; positive Werte erleichtern, negative erschweren.
  final int situationalModifier;

  /// Aktiviert einen optionalen Spezialisierungsbonus.
  final bool specializationApplied;
}

/// Vollstaendiges Auswertungsergebnis einer Probe.
class ProbeResult {
  /// Erzeugt ein immutable Ergebnisobjekt.
  const ProbeResult({
    required this.request,
    required this.input,
    required this.diceValues,
    required this.effectiveTargetValues,
    required this.targetOverflows,
    required this.compensationPoolStart,
    required this.remainingPool,
    required this.appliedAttributePenalty,
    required this.total,
    required this.success,
    required this.automaticOutcome,
    required this.specialExperience,
    required this.usedFixedRollTotal,
  });

  /// Urspruengliche Probe.
  final ResolvedProbeRequest request;

  /// Verwendete Eingabe.
  final ProbeRollInput input;

  /// Gewertete Wuerfelwerte.
  final List<int> diceValues;

  /// Endgueltige Zielwerte nach Malus/Bonus.
  final List<int> effectiveTargetValues;

  /// Ueberschreitungen je Einzelwurf gegen den Zielwert.
  final List<int> targetOverflows;

  /// Startwert des Kompensationspools nach allen Modifikationen.
  final int compensationPoolStart;

  /// Verbleibender Kompensationspool nach Auswertung.
  final int remainingPool;

  /// Malus, der bei negativen Pools auf alle Zielwerte umgelegt wurde.
  final int appliedAttributePenalty;

  /// Gesamtsumme fuer Initiative- oder Schadenswurf.
  final int total;

  /// Enderfolg der Probe.
  final bool success;

  /// Automatischer Erfolg oder Fehlschlag.
  final AutomaticOutcome automaticOutcome;

  /// Kennzeichnet eine Spezielle Erfahrung durch Doppel-1.
  final bool specialExperience;

  /// Kennzeichnet Faelle ohne echten Wurf, z. B. Aufmerksamkeit.
  final bool usedFixedRollTotal;
}
