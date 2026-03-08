/// Berechnet den finalen FK-Wert einer Fernkampfwaffe.
int computeFkValue({
  required int fkBase,
  required int talentValue,
  required int weaponFkMod,
  required int ebeAttackPart,
  required int specializationBonus,
  required int projectileFkMod,
  required int manualFkMod,
}) {
  return fkBase +
      talentValue +
      weaponFkMod +
      ebeAttackPart +
      specializationBonus +
      projectileFkMod +
      manualFkMod;
}

/// Addiert Distanz- und Geschossmodifikator auf den TP-Gesamtwert.
int computeRangedTpCalc({
  required int baseTpCalc,
  required int distanceTpMod,
  required int projectileTpMod,
}) {
  return baseTpCalc + distanceTpMod + projectileTpMod;
}
