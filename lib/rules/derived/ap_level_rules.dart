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

/// AP-Kosten pro epischer Stufe (entspricht dem Abstand zwischen Stufe 21 und 22).
const int epicApCostPerLevel = 2100;

/// Gibt die aktuelle epische Stufe zurueck (1-basiert), oder 0 wenn nicht episch.
int computeEpicLevel(bool isEpisch, int apSpent, int epicStartAp) {
  if (!isEpisch) return 0;
  final delta = apSpent - epicStartAp;
  return 1 + (delta < 0 ? 0 : delta ~/ epicApCostPerLevel);
}

/// Gibt die AP bis zur naechsten epischen Stufe zurueck (0 wenn nicht episch).
int computeApUntilNextEpicLevel(bool isEpisch, int apSpent, int epicStartAp) {
  if (!isEpisch) return 0;
  final delta = apSpent - epicStartAp;
  if (delta < 0) return epicApCostPerLevel;
  return epicApCostPerLevel - (delta % epicApCostPerLevel);
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

/// Klassifikation eines Helden nach Zauber-Tiefe (fuer epische AsP-Boni).
enum ZaubererKategorie { keine, viertel, halb, voll }

/// AsP-Stufenbonus fuer epische Stufen.
///
/// Regelquelle: Hausregel „Epische Stufen", Kap. 2.2 —
/// Stufenboni gibt es nur noch auf AsP, und Halbzauberer bekommen
/// nur 1 AsP je Stufe, Viertelzauberer gar nichts mehr.
///
/// Der Standardwert fuer Vollzauberer (6 AsP) entspricht der in den
/// Grundregeln ueblichen Menge und kann ueber [fullCasterBonus] ueberschrieben
/// werden, um mit abweichenden Hausregeln kompatibel zu bleiben.
/// Liefert 0, wenn die Regel inaktiv ist oder der Held nicht episch ist.
int epicAspStufenbonus({
  required ZaubererKategorie kategorie,
  required bool ruleActive,
  required bool isEpisch,
  int fullCasterBonus = 6,
}) {
  if (!ruleActive || !isEpisch) return 0;
  return switch (kategorie) {
    ZaubererKategorie.voll => fullCasterBonus,
    ZaubererKategorie.halb => 1,
    ZaubererKategorie.viertel => 0,
    ZaubererKategorie.keine => 0,
  };
}
