/// Einzelner Eintrag in der Avatar-Galerie eines Helden.
class AvatarGalleryEntry {
  const AvatarGalleryEntry({
    required this.id,
    required this.fileName,
    this.quelle = 'upload',
    this.stilId = '',
    this.erstelltAm = '',
    this.promptAuszug = '',
  });

  /// Eindeutige ID (UUID).
  final String id;

  /// Dateiname im Avatare-Verzeichnis (z.B. '{heroId}_{uuid}.png').
  final String fileName;

  /// Herkunft des Bildes: 'ki' oder 'upload'.
  final String quelle;

  /// AvatarStyle-Name falls KI-generiert (leer bei Upload).
  final String stilId;

  /// ISO-8601 Zeitstempel der Erstellung.
  final String erstelltAm;

  /// Gekuerzter Prompt (optional, fuer KI-generierte Bilder).
  final String promptAuszug;

  AvatarGalleryEntry copyWith({
    String? id,
    String? fileName,
    String? quelle,
    String? stilId,
    String? erstelltAm,
    String? promptAuszug,
  }) {
    return AvatarGalleryEntry(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      quelle: quelle ?? this.quelle,
      stilId: stilId ?? this.stilId,
      erstelltAm: erstelltAm ?? this.erstelltAm,
      promptAuszug: promptAuszug ?? this.promptAuszug,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'quelle': quelle,
        'stilId': stilId,
        'erstelltAm': erstelltAm,
        'promptAuszug': promptAuszug,
      };

  static AvatarGalleryEntry fromJson(Map<String, dynamic> json) {
    return AvatarGalleryEntry(
      id: (json['id'] as String?) ?? '',
      fileName: (json['fileName'] as String?) ?? '',
      quelle: (json['quelle'] as String?) ?? 'upload',
      stilId: (json['stilId'] as String?) ?? '',
      erstelltAm: (json['erstelltAm'] as String?) ?? '',
      promptAuszug: (json['promptAuszug'] as String?) ?? '',
    );
  }
}
