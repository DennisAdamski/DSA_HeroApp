/// Fortschritt eines Heldenimports im Vorgangsjournal (ARCH-06).
enum ImportSchritt {
  /// Bilder werden abgelegt; der Held ist noch nicht (sicher) gespeichert.
  bilderAblegen,

  /// Der Held ist gespeichert; es fehlt höchstens noch sein Zustand.
  heldGespeichert,
}

/// Journaleintrag eines laufenden Heldenimports.
///
/// Hält fest, was der Wiederanlauf braucht, um einen abgebrochenen Import zu
/// Ende zu führen (Zustand nachtragen) oder auszugleichen (abgelegte, aber
/// unbenutzte Bilder löschen). Wird nur im Journal gespeichert, nie am
/// Helden; das Format darf sich deshalb mit der App ändern, unbekannte
/// Einträge bleiben liegen.
class ImportVorgang {
  /// Erzeugt einen Eintrag.
  const ImportVorgang({
    required this.id,
    required this.heroId,
    required this.begonnen,
    required this.schritt,
    required this.heldHashVorher,
    required this.dateien,
    required this.zustand,
  });

  /// Kennung der Vorgangsart im Journal.
  static const String art = 'heldImportieren';

  /// Schlüssel im Journal.
  final String id;

  /// Ziel-ID des importierten Helden.
  final String heroId;

  /// Beginn des Imports.
  final DateTime begonnen;

  /// Erreichter Schritt.
  final ImportSchritt schritt;

  /// `heroContentHash` des Helden vor dem Import; `null`, wenn es ihn noch
  /// nicht gab. Weicht der gespeicherte Held davon ab, ist der Import-Held
  /// geschrieben, auch wenn [schritt] das noch nicht vermerkt.
  final String? heldHashVorher;

  /// Vom Import abgelegte Bilddateien.
  final List<String> dateien;

  /// Laufzeitzustand des Exports als JSON.
  final Map<String, Object?> zustand;

  /// Kopie mit einer weiteren abgelegten Datei.
  ImportVorgang mitDatei(String dateiname) =>
      _kopie(dateien: <String>[...dateien, dateiname]);

  /// Kopie, die den gespeicherten Helden vermerkt.
  ImportVorgang alsHeldGespeichert() =>
      _kopie(schritt: ImportSchritt.heldGespeichert);

  ImportVorgang _kopie({ImportSchritt? schritt, List<String>? dateien}) {
    return ImportVorgang(
      id: id,
      heroId: heroId,
      begonnen: begonnen,
      schritt: schritt ?? this.schritt,
      heldHashVorher: heldHashVorher,
      dateien: dateien ?? this.dateien,
      zustand: zustand,
    );
  }

  /// JSON für das Journal.
  Map<String, Object?> toJson() => <String, Object?>{
    'art': art,
    'heroId': heroId,
    'begonnen': begonnen.toUtc().toIso8601String(),
    'schritt': schritt.name,
    'heldHashVorher': heldHashVorher,
    'dateien': dateien,
    'zustand': zustand,
  };

  /// Liest einen Journaleintrag; `null` bei fremder Art oder unbekanntem
  /// Schritt — solche Einträge fasst der Wiederanlauf nicht an.
  static ImportVorgang? fromJson(String id, Map<String, Object?> json) {
    if (json['art'] != art) {
      return null;
    }
    final schritt = ImportSchritt.values
        .where((s) => s.name == json['schritt'])
        .firstOrNull;
    final heroId = json['heroId'];
    final zustand = json['zustand'];
    if (schritt == null || heroId is! String || zustand is! Map) {
      return null;
    }
    return ImportVorgang(
      id: id,
      heroId: heroId,
      begonnen:
          DateTime.tryParse(json['begonnen'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      schritt: schritt,
      heldHashVorher: json['heldHashVorher'] as String?,
      dateien: <String>[
        for (final datei in json['dateien'] as List? ?? const <Object?>[])
          if (datei is String) datei,
      ],
      zustand: zustand.cast<String, Object?>(),
    );
  }
}
