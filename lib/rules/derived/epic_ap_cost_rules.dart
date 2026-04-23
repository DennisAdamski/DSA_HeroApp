/// Wendet den epischen AP-Aufschlag auf Lernkosten an.
///
/// Regelquelle: Hausregel „Epische Stufen", Kap. 2.2 —
/// „Normale Eigenschaften, Talente und Zauber kosten 25 % mehr AP".
/// Ausgenommen sind Begabungen, Sondererfahrungen und epische Inhalte
/// (fuer epische SF gelten keine Verbilligungen, die nicht explizit
/// episch sind — aber auch kein Aufschlag).
///
/// Parameter `lehrmeisterHebtAuf` entspricht der Klarstellung im
/// Regeltext: ein Lehrmeister hebt den Aufschlag auf, anstatt zusaetzlich
/// zu verbilligen. Diese Entscheidung wird durch die UI uebergeben.
int applyEpicApSurcharge(
  int baseApCost, {
  required bool ruleActive,
  required bool isEpisch,
  bool isEpicContent = false,
  bool isBegabung = false,
  bool isSpecialExperience = false,
  bool lehrmeisterHebtAuf = false,
}) {
  if (baseApCost <= 0) return baseApCost;
  if (!ruleActive || !isEpisch) return baseApCost;
  if (isEpicContent || isBegabung || isSpecialExperience) return baseApCost;
  if (lehrmeisterHebtAuf) return baseApCost;
  return (baseApCost * 1.25).round();
}

/// Liefert den Aufschlagsanteil (25 %) fuer Anzeige-Zwecke.
/// Gibt 0 zurueck, wenn die Regel nicht greift.
int computeEpicApSurchargeDelta(
  int baseApCost, {
  required bool ruleActive,
  required bool isEpisch,
  bool isEpicContent = false,
  bool isBegabung = false,
  bool isSpecialExperience = false,
  bool lehrmeisterHebtAuf = false,
}) {
  final adjusted = applyEpicApSurcharge(
    baseApCost,
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    isEpicContent: isEpicContent,
    isBegabung: isBegabung,
    isSpecialExperience: isSpecialExperience,
    lehrmeisterHebtAuf: lehrmeisterHebtAuf,
  );
  return adjusted - baseApCost;
}
