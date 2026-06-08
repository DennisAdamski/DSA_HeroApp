/// Extrahiert die fuehrende AP-Zahl aus dem Katalogfeld `kosten`.
///
/// Tausenderpunkte werden toleriert („2.500 AP“ → 2500); bei Mehrfachangaben
/// („400 / 550 / 700 AP …“) wird die erste Stufe genommen. Gibt `null` zurueck,
/// wenn keine Zahl gefunden wird (z. B. „Je nach Waffe“).
int? parseApCost(String kosten) {
  // Zuerst Zahlen mit Tausenderpunkten, sonst einfache Ziffernfolgen.
  final match = RegExp(r'\d{1,3}(?:\.\d{3})+|\d+').firstMatch(kosten);
  if (match == null) {
    return null;
  }
  final normalized = match.group(0)!.replaceAll('.', '');
  return int.tryParse(normalized);
}
