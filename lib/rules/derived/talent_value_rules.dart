/// Berechnet den angezeigten Talentwert nach Anwendung von Modifikator, eBE
/// und optionalem Inventar-Modifikator.
///
/// Formel:
/// `TaW_berechnet = TaW + Mod + eBE + inventoryMod`
int computeTalentComputedTaw({
  required int? talentValue,
  required int modifier,
  required int ebe,
  int inventoryMod = 0,
}) {
  return (talentValue ?? 0) + modifier + ebe + inventoryMod;
}
