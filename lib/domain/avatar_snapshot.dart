/// Snapshot der Heldendaten zum Zeitpunkt der Primaerbild-Festlegung.
///
/// Wird gespeichert, um bei erneuter KI-Generierung Abweichungen
/// zum aktuellen Heldenzustand erkennen und im Prompt beruecksichtigen
/// zu koennen.
class AvatarSnapshot {
  const AvatarSnapshot({
    this.erstelltAm = '',
    this.attributes = const {},
    this.alter = '',
    this.vorteileText = '',
    this.nachteileText = '',
    this.rasse = '',
    this.geschlecht = '',
    this.haarfarbe = '',
    this.augenfarbe = '',
  });

  /// ISO-8601 Zeitstempel der Snapshot-Erstellung.
  final String erstelltAm;

  /// Eigenschaftswerte zum Snapshot-Zeitpunkt (z.B. {'MU': 14, 'KL': 12}).
  final Map<String, int> attributes;

  /// Alter des Helden zum Snapshot-Zeitpunkt.
  final String alter;

  /// Vorteile-Freitext zum Snapshot-Zeitpunkt.
  final String vorteileText;

  /// Nachteile-Freitext zum Snapshot-Zeitpunkt.
  final String nachteileText;

  /// Rasse zum Snapshot-Zeitpunkt.
  final String rasse;

  /// Geschlecht zum Snapshot-Zeitpunkt.
  final String geschlecht;

  /// Haarfarbe zum Snapshot-Zeitpunkt.
  final String haarfarbe;

  /// Augenfarbe zum Snapshot-Zeitpunkt.
  final String augenfarbe;

  Map<String, dynamic> toJson() => {
        'erstelltAm': erstelltAm,
        'attributes': attributes,
        'alter': alter,
        'vorteileText': vorteileText,
        'nachteileText': nachteileText,
        'rasse': rasse,
        'geschlecht': geschlecht,
        'haarfarbe': haarfarbe,
        'augenfarbe': augenfarbe,
      };

  static AvatarSnapshot fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['attributes'];
    final attributes = <String, int>{};
    if (rawAttributes is Map) {
      for (final entry in rawAttributes.entries) {
        final key = entry.key as String;
        final value = entry.value;
        if (value is int) {
          attributes[key] = value;
        } else if (value is num) {
          attributes[key] = value.toInt();
        }
      }
    }

    return AvatarSnapshot(
      erstelltAm: (json['erstelltAm'] as String?) ?? '',
      attributes: attributes,
      alter: (json['alter'] as String?) ?? '',
      vorteileText: (json['vorteileText'] as String?) ?? '',
      nachteileText: (json['nachteileText'] as String?) ?? '',
      rasse: (json['rasse'] as String?) ?? '',
      geschlecht: (json['geschlecht'] as String?) ?? '',
      haarfarbe: (json['haarfarbe'] as String?) ?? '',
      augenfarbe: (json['augenfarbe'] as String?) ?? '',
    );
  }
}
