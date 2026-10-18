/// Berechnet den finalen AT-Wert einer Fernkampfwaffe.
int computeRangedAtValue({
  required int rangedAtBase,
  required int talentAtValue,
  required int weaponAtMod,
  required int ebeAttackPart,
  required int specializationBonus,
  required int projectileAtMod,
  required int manualAtMod,
  int waffenmeisterAtBonus = 0,
  int zauberMalus = 0,
}) {
  return rangedAtBase +
      talentAtValue +
      weaponAtMod +
      waffenmeisterAtBonus +
      ebeAttackPart +
      specializationBonus +
      projectileAtMod +
      manualAtMod +
      zauberMalus;
}

/// Addiert Distanz- und Geschossmodifikator auf den TP-Gesamtwert.
int computeRangedTpCalc({
  required int baseTpCalc,
  required int distanceTpMod,
  required int projectileTpMod,
}) {
  return baseTpCalc + distanceTpMod + projectileTpMod;
}
