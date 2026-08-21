/// Grund, warum ein Avatarbild nicht geladen oder gespeichert werden konnte.
///
/// Ohne diese Unterscheidung fallen im Web sechs verschiedene Ursachen auf
/// denselben stummen Platzhalter zusammen und sind von aussen nicht mehr
/// auseinanderzuhalten.
enum AvatarLoadFailure {
  /// Kein angemeldeter Nutzer — der Cloud-Pfad braucht eine uid.
  nichtAngemeldet,

  /// Die Storage-Regel hat den Zugriff abgelehnt.
  keineBerechtigung,

  /// Das Bild ueberschreitet das Ladelimit von `getData()`.
  zuGross,

  /// Netzwerkfehler beim Abruf der Bytes.
  netzwerk,

  /// Alles Uebrige, inklusive unerwarteter Typfehler im Plugin.
  unbekannt,
}

/// Fehlschlag beim Zugriff auf ein Avatarbild.
///
/// Implementiert bewusst [Exception]: Bestehende Aufrufer mit
/// `on Exception`-Zweig (z. B. das Gruppen-Thumbnail) fangen sie damit weiter.
class AvatarLoadException implements Exception {
  /// Erstellt einen Fehlschlag mit [grund] und optionalen [details].
  const AvatarLoadException(this.grund, {this.details});

  /// Kategorie des Fehlschlags.
  final AvatarLoadFailure grund;

  /// Technische Zusatzinfo fuer Logs und Tooltip.
  final String? details;

  /// Kurzer deutscher Text fuer Tooltip und Statuszeile.
  String get meldung => switch (grund) {
    AvatarLoadFailure.nichtAngemeldet =>
      'Nicht angemeldet — Avatarbilder liegen im Konto-Speicher.',
    AvatarLoadFailure.keineBerechtigung =>
      'Keine Berechtigung für dieses Bild.',
    AvatarLoadFailure.zuGross => 'Bild ist zu groß zum Laden.',
    AvatarLoadFailure.netzwerk =>
      'Bild konnte nicht geladen werden (Netzwerk).',
    // Bewusst anders formuliert als der Fallback fuer Nicht-
    // [AvatarLoadException]-Fehler im Widget: Sonst waeren beide Faelle im
    // Tooltip ununterscheidbar.
    AvatarLoadFailure.unbekannt => 'Bild konnte nicht gelesen werden.',
  };

  @override
  String toString() {
    final suffix = details == null ? '' : ' ($details)';
    return 'AvatarLoadException: $meldung$suffix';
  }
}
