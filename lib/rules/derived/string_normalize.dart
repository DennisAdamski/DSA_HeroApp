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

/// Faltet Text für die tolerante Suche (`contains`-Filter).
///
/// Nicht für Gleichheitsvergleiche: Die Faltung kürzt jedes `ae`, `oe` und
/// `ue` und lässt so verschiedene Namen zusammenfallen; dafür gibt es
/// [vergleichsSchluessel].
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

/// Vergleichsschlüssel für Namen: klein, Umlaute als Digraphen (`ä` zu `ae`,
/// `ß` zu `ss`), alle übrigen Zeichen außer Buchstaben und Ziffern als ein
/// einzelnes Leerzeichen, ohne Randleerzeichen.
///
/// Anders als [suchFaltung] bleiben `ae` und `a` verschieden; der Schlüssel
/// dient dem genauen Abgleich gleichnamiger Einträge (Sonderfertigkeiten,
/// Vor- und Nachteile, Traditionen), nicht der toleranten Suche.
String vergleichsSchluessel(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

/// Prüft, ob ein benanntes Token (z. B. 'flink', 'behaebig') im Text vorkommt.
///
/// Deutsche Umlaute werden vor dem Vergleich normalisiert (ae, oe, ue, ss),
/// weil Nutzer Vorteile unterschiedlich eintippen koennen
/// ('Behäbig', 'Behaebig', 'BEHÄBIG'). Die Zeichencodes sind Unicode-Codepoints
/// der Umlaute: 228=ä, 246=ö, 252=ü, 223=ß.
/// Anschliessend wird der Text an nicht-alphanumerischen Zeichen in Tokens
/// aufgeteilt und jeder Token gegen die Ziel-Menge geprueft.
bool containsNamedToken(String text, Set<String> targets) {
  for (final rawFragment in text.split(RegExp(r'[\n,;]+'))) {
    final fragment = rawFragment.trim();
    if (fragment.isEmpty) {
      continue;
    }
    final normalizedFragment = fragment
        .toLowerCase()
        .replaceAll(String.fromCharCode(228), 'a')
        .replaceAll(String.fromCharCode(246), 'o')
        .replaceAll(String.fromCharCode(252), 'u')
        .replaceAll(String.fromCharCode(223), 'ss');
    final tokens = normalizedFragment
        .split(RegExp(r'[^a-z0-9]+'))
        .where((entry) => entry.isNotEmpty);
    for (final token in tokens) {
      if (targets.contains(token)) {
        return true;
      }
    }
  }
  return false;
}

/// Ob [text] die Suchanfrage [anfrage] enthält, tolerant gegenüber Groß-
/// und Kleinschreibung, Randleerzeichen und Umlaut-Schreibweisen
/// (siehe [suchFaltung]). Eine leere Anfrage passt immer.
bool passtZurSuche(String text, String anfrage) =>
    suchFaltung(text).contains(suchFaltung(anfrage));
