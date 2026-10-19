/// Adresse der Avesmaps-Karte (Nachfolger von Avespfade).
///
/// Die Seite lässt sich nicht einbetten (`X-Frame-Options: DENY`); die App
/// verlinkt deshalb nur und übernimmt keine Karten- oder Ortsdaten.
const String kAvesmapsHost = 'avesmaps.de';

/// Höchstlänge eines gespeicherten Standorts.
const int kStandortMaxLaenge = 120;

/// Bereinigt eine Eingabe zum Standort: Leerraum außen entfernt, innere
/// Leerraumfolgen zu einem Leerzeichen, auf [kStandortMaxLaenge] gekürzt.
///
/// Ein leerer Rückgabewert bedeutet „kein Standort“ und wird nicht in den
/// Zustand geschrieben.
String bereinigeStandort(String eingabe) {
  final einzeilig = eingabe.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (einzeilig.length <= kStandortMaxLaenge) return einzeilig;
  return einzeilig.substring(0, kStandortMaxLaenge).trimRight();
}

/// Link auf die Avesmaps-Karte für den Ort [standort] oder `null`.
///
/// Avesmaps öffnet Siedlungen über den Seitennamen im Wiki Aventurica
/// (`?siedlung=Gareth`). Ein Standort, der keine Siedlung ist (etwa
/// „Auf der Reichsstraße“), führt dort ins Leere; die Oberfläche weist darauf
/// hin, statt den Link zu verstecken.
Uri? avesmapsLink(String standort) {
  final name = bereinigeStandort(standort);
  if (name.isEmpty) return null;
  return Uri.https(kAvesmapsHost, '/', <String, String>{'siedlung': name});
}
