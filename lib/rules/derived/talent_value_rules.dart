/// Berechnet den angezeigten Talentwert nach Anwendung von Modifikator und eBE.
///
/// Formel:
/// `TaW_berechnet = TaW + Mod + eBE`
int computeTalentComputedTaw({
  required int talentValue,
  required int modifier,
  required int ebe,
}) {
  return talentValue + modifier + ebe;
}
