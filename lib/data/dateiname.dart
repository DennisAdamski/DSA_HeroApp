/// Macht aus einem Wunschnamen einen zulässigen Dateinamen.
///
/// Zeichen, die unter Windows oder in Browser-Downloads verboten sind
/// (`< > : " / \ | ? *` und Steuerzeichen), werden zu `_`. [fallback] greift,
/// wenn der Wunschname leer ist oder nur Leerzeichen trägt. Eine Quelle für
/// native Plattformen und Web, damit beide dieselben Namen schreiben.
String bereinigeDateiname(String value, {required String fallback}) {
  final trimmed = value.trim().isEmpty ? fallback : value.trim();
  return trimmed.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
}
