/// Best-effort-Extraktion numerischer Kosten aus Katalog-Freitexten.
///
/// Katalogtexte fuer Sonderfertigkeiten/Manoever ("kosten") und
/// Vorteile/Nachteile ("costText") sind heterogen formuliert (bedingte
/// Rabatte, Staffelungen, Verweise auf andere Werte). Diese Parser liefern
/// nur einen Vorschlagswert fuer Eingabefelder — nie eine verbindliche
/// Kostenberechnung. Bei nicht eindeutig parsbaren Texten liefern sie
/// `null`, damit Aufrufer auf manuelle Eingabe zurueckfallen koennen.
library;

final RegExp _apAmountPattern = RegExp(r'(\d[\d.]*)\s*AP\b', caseSensitive: false);
final RegExp _gpAmountPattern = RegExp(r'(-?\d[\d.]*)\s*GP\b', caseSensitive: false);

/// Extrahiert den ersten AP-Betrag aus einem Sonderfertigkeiten-/
/// Manoever-Kostentext, z. B. "400 AP" oder "200 AP pro Stufe" -> `200`.
int? parseLeadingApAmount(String kostenText) {
  final match = _apAmountPattern.firstMatch(kostenText);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!.replaceAll('.', ''));
}

/// Extrahiert den ersten (vorzeichenbehafteten) GP-Betrag aus einem
/// Vor-/Nachteil-Kostentext, z. B. "-7 GP" -> `-7`, "7 GP" -> `7`.
int? parseGpAmount(String costText) {
  final match = _gpAmountPattern.firstMatch(costText);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!.replaceAll('.', ''));
}
