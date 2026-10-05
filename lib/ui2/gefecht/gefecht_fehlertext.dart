/// Sichtbarer Text eines Gefechtsfehlers ohne technisches Präfix.
///
/// Fachliche Gründe kommen als `StateError` oder `ArgumentError`; deren
/// `toString` stellt „Bad state:“ bzw. „Invalid argument(s):“ voran. Die
/// Oberfläche zeigt wie Abenteuer- und Merkmalsblatt nur die Nachricht.
String gefechtsFehlertext(Object fehler) => switch (fehler) {
  StateError(:final message) => message,
  ArgumentError(:final message?) => '$message',
  _ => '$fehler',
};
