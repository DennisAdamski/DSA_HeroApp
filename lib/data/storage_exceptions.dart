/// Fehler beim Aufloesen oder Vorbereiten eines Heldenspeicherpfads.
class HeroStoragePathException implements Exception {
  /// Erstellt eine neue Speicherausnahme mit Nutzertext.
  const HeroStoragePathException(this.message);

  /// Nutzerlesbare Fehlerbeschreibung.
  final String message;

  @override
  String toString() => message;
}
