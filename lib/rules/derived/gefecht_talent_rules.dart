import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

import 'gefecht_ablauf_rules.dart';
import 'gefecht_rules.dart';

/// Zeitbedarf einer Talent- oder Eigenschaftsprobe im Gefecht (WdS S. 55).
enum GefechtsZeitbedarf {
  /// Reaktion oder vom Meister verlangte Probe ohne eigene Aktion.
  ohneAktion,

  /// Freie Aktion, etwa ein kurzer Blick.
  freieAktion,

  /// Eine Aktion; die meisten geforderten Proben (Körperbeherrschung, Reiten).
  aktion,

  /// Talenteinsatz über mehrere Aktionen; TaP* verkürzen die Dauer.
  laengerfristig,
}

/// Sichtbarer Name eines Zeitbedarfs.
String gefechtsZeitbedarfName(GefechtsZeitbedarf z) => switch (z) {
  GefechtsZeitbedarf.ohneAktion => 'Ohne Aktion',
  GefechtsZeitbedarf.freieAktion => 'Freie Aktion',
  GefechtsZeitbedarf.aktion => 'Eine Aktion',
  GefechtsZeitbedarf.laengerfristig => 'Talenteinsatz',
};

/// Vorgabe: Talente kosten eine Aktion, Eigenschaftsproben keine.
///
/// WdS S. 55: „Die meisten regeltechnisch geforderten Proben auf
/// Körperbeherrschung, Reiten etc. benötigen eine Aktion.“ Eigenschaftsproben
/// sind meist Reaktionen (etwa GE gegen Stürzen).
GefechtsZeitbedarf gefechtsZeitbedarfVorgabe(ProbeType typ) =>
    typ == ProbeType.talent
    ? GefechtsZeitbedarf.aktion
    : GefechtsZeitbedarf.ohneAktion;

/// Prüft das Budget für den ersten Teil des gewählten Zeitbedarfs.
///
/// `null` bedeutet: es wird keine Aktionsmarke gebucht. Längerfristige
/// Handlungen bezahlen jetzt eine reguläre Aktion, den Rest über
/// „Fortsetzen“; Zusatzaktionen dürfen sie nicht bezahlen (WdS S. 55).
Gefechtspruefung? pruefeGefechtsZeitbedarf(
  Gefechtszustand s,
  Gefechtswerte w,
  GefechtsZeitbedarf z,
) => switch (z) {
  GefechtsZeitbedarf.ohneAktion => null,
  GefechtsZeitbedarf.freieAktion => pruefeGefechtsaktion(
    s,
    w,
    Gefechtsaktion.freieAktion,
  ),
  GefechtsZeitbedarf.aktion || GefechtsZeitbedarf.laengerfristig =>
    pruefeManuelleGefechtsaktion(s, w, kosten: 1),
};

/// Gesamtdauer eines Talenteinsatzes nach der Probe zu Beginn.
///
/// WdS S. 55: Die geplanten Aktionen werden um die übrig behaltenen TaP*
/// verkürzt. App-Konvention: mindestens eine Aktion; eine misslungene Probe
/// verkürzt nichts (das weitere Vorgehen klärt der Tisch).
int gefechtsTalenteinsatzDauer(int geplant, ProbeResult ergebnis) {
  if (geplant < 1) throw ArgumentError('Mindestens eine Aktion planen.');
  if (!ergebnis.success) return geplant;
  final rest = geplant - ergebnis.remainingPool;
  return rest < 1 ? 1 : rest;
}
