/// Normalisiert einen Kampf-Token robust fuer Vergleiche.
///
/// Umlaute werden zu Digraphen aufgeloest, Sonderzeichen und Leerzeichen
/// entfernt und das Ergebnis in Kleinbuchstaben zurueckgegeben.
String normalizeCombatToken(String raw) {
  var value = raw.trim().toLowerCase();
  value = value
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
