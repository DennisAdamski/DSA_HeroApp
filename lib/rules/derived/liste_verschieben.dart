/// Verschiebt den Eintrag an [von] so, dass er danach an [nach] steht.
///
/// [nach] wird an die Liste geklemmt. Ein ungültiges [von] oder keine
/// Bewegung liefern [liste] selbst; sonst entsteht eine neue, unveränderliche
/// Liste. Gemeinsam für Spielkacheln und häufige Proben.
List<T> verschiebeListenEintrag<T>(List<T> liste, int von, int nach) {
  if (von < 0 || von >= liste.length) return liste;
  final ziel = nach.clamp(0, liste.length - 1);
  if (ziel == von) return liste;
  final kopie = List<T>.of(liste);
  final eintrag = kopie.removeAt(von);
  kopie.insert(ziel, eintrag);
  return List<T>.unmodifiable(kopie);
}
