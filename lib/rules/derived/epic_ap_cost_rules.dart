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
///
/// Parameter `isMainAttribute` deckt die Ausnahme aus Kap. 2.1 ab: die
/// beiden gewaehlten Haupteigenschaften (je eine geistige und eine
/// koerperliche) steigern sich weiterhin zum Normalpreis. Ob eine
/// Eigenschaft Haupteigenschaft ist, entscheidet `isEpicMainAttribute`
/// in `epic_main_attribute_rules.dart`.
int applyEpicApSurcharge(
  int baseApCost, {
  required bool ruleActive,
  required bool isEpisch,
  bool isEpicContent = false,
  bool isBegabung = false,
  bool isSpecialExperience = false,
  bool isMainAttribute = false,
  bool lehrmeisterHebtAuf = false,
}) {
  if (baseApCost <= 0) return baseApCost;
  if (!ruleActive || !isEpisch) return baseApCost;
  if (isEpicContent || isBegabung || isSpecialExperience) return baseApCost;
  if (isMainAttribute) return baseApCost;
  if (lehrmeisterHebtAuf) return baseApCost;
  return (baseApCost * 1.25).round();
}

/// Ob der epische Aufschlag ohne Lehrmeister auf die Kosten greifen wuerde.
///
/// Nur dann hebt ein Lehrmeister die Verteuerung auf: Hausregel „Epische
/// Stufen", Kap. 2.2 — „ein Lehrmeister [verbilligt] in Zukunft die Kosten
/// nicht ..., sondern [hebt] diese Verteuerung auf". Er verbilligt die Kosten
/// also nicht zusaetzlich um 20 %; ein epischer Held mit Lehrmeister zahlt den
/// Normalpreis. Wo kein Aufschlag anfaellt (Haupteigenschaft, Begabung,
/// epischer Inhalt), gilt der gewohnte Nachlass des Lehrmeisters.
bool epicApSurchargeApplies({
  required bool ruleActive,
  required bool isEpisch,
  bool isEpicContent = false,
  bool isBegabung = false,
  bool isSpecialExperience = false,
  bool isMainAttribute = false,
}) {
  const probe = 100;
  return applyEpicApSurcharge(
        probe,
        ruleActive: ruleActive,
        isEpisch: isEpisch,
        isEpicContent: isEpicContent,
        isBegabung: isBegabung,
        isSpecialExperience: isSpecialExperience,
        isMainAttribute: isMainAttribute,
      ) !=
      probe;
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
  bool isMainAttribute = false,
  bool lehrmeisterHebtAuf = false,
}) {
  final adjusted = applyEpicApSurcharge(
    baseApCost,
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    isEpicContent: isEpicContent,
    isBegabung: isBegabung,
    isSpecialExperience: isSpecialExperience,
    isMainAttribute: isMainAttribute,
    lehrmeisterHebtAuf: lehrmeisterHebtAuf,
  );
  return adjusted - baseApCost;
}
