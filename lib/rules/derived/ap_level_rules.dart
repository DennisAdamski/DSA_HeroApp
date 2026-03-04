import 'dart:math' as math;

/// Berechnet die Heldenstufe aus ausgegebenen Abenteuerpunkten.
///
/// Formel: level = floor(sqrt(apSpent / 50 + 0.25) + 0.5)
/// Die Konstante 50 legt den AP-Aufwand je Stufenschritt fest.
/// Die Summanden 0.25 und 0.5 sorgen fuer mathematisch korrekte Rundung
/// auf die naechste ganze Stufe (aequivalent zu round(sqrt(...) - 0.5)).
/// Mindestwert ist immer 1 (kein Held hat Stufe 0).
int computeLevelFromSpentAp(int spentAp) {
  final normalized = spentAp < 0 ? 0 : spentAp;
  final raw = math.sqrt(normalized / 50 + 0.25) + 0.5;
  final level = raw.floor();
  return level < 1 ? 1 : level;
}

/// Berechnet die verbleibenden (verfuegbaren) Abenteuerpunkte.
///
/// Beide Eingaben werden auf 0 begrenzt, damit negative Rohwerte
/// (z. B. durch Import-Fehler) keine ungueltigen Ergebnisse liefern.
int computeAvailableAp(int total, int spent) {
  final normalizedTotal = total < 0 ? 0 : total;
  final normalizedSpent = spent < 0 ? 0 : spent;
  final remaining = normalizedTotal - normalizedSpent;
  return remaining < 0 ? 0 : remaining;
}
