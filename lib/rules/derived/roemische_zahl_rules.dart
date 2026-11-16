/// Römische Zahlen für Stufenangaben (Sonderfertigkeiten, Rüstungsgewöhnung).
library;

const List<String> _roemischeZahlen = <String>[
  '',
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
];

/// Römische Schreibweise von [wert] (1 bis 7); außerhalb der Reihe die Ziffer.
String roemischeZahl(int wert) => wert > 0 && wert < _roemischeZahlen.length
    ? _roemischeZahlen[wert]
    : '$wert';

/// Wert eines römischen Tokens (`I` bis `VII`, ohne Groß-/Kleinschreibung);
/// `null` für alles andere.
int? roemischeZahlWert(String token) {
  final gesucht = token.trim().toUpperCase();
  if (gesucht.isEmpty) return null;
  final index = _roemischeZahlen.indexOf(gesucht);
  return index > 0 ? index : null;
}
