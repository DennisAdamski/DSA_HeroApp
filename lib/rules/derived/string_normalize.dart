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

/// Faltet Text für die tolerante Suche und für Vergleichsschlüssel.
///
/// Klein geschrieben, ohne Randleerzeichen; Umlaute und ihre Umschreibungen
/// fallen zusammen (`ä`, `ae` und `a` werden `a`, ebenso `ö`/`oe` und
/// `ü`/`ue`; `ß` wird `ss`). So finden sich „Betäubung“, „Betaeubung“ und
/// „Betaubung“ gegenseitig, weil am Spieltisch oft ohne Umlaute getippt wird.
/// Anfrage und Text müssen beide gefaltet werden; Leerzeichen bleiben stehen.
String suchFaltung(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss')
    .replaceAll('ae', 'a')
    .replaceAll('oe', 'o')
    .replaceAll('ue', 'u');
