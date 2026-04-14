/// Einzelner Eintrag in der Avatar-Galerie eines Helden.
class AvatarGalleryEntry {
  const AvatarGalleryEntry({
    required this.id,
    required this.fileName,
    this.quelle = 'upload',
    this.stilId = '',
    this.erstelltAm = '',
    this.promptAuszug = '',
    this.headerFocusX,
    this.headerFocusY,
    this.headerZoom,
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

  /// Optionaler normalisierter Fokuspunkt fuer den Workspace-Header (0..1).
  final double? headerFocusX;

  /// Optionaler normalisierter Fokuspunkt fuer den Workspace-Header (0..1).
  final double? headerFocusY;

  /// Optionaler Zoom-Faktor fuer den Workspace-Header-Ausschnitt (>= 1.0).
  /// `null` oder `1.0` entsprechen dem Default-Cover-Ausschnitt.
  final double? headerZoom;

  AvatarGalleryEntry copyWith({
    String? id,
    String? fileName,
    String? quelle,
    String? stilId,
    String? erstelltAm,
    String? promptAuszug,
    double? headerFocusX,
    double? headerFocusY,
    double? headerZoom,
  }) {
    return AvatarGalleryEntry(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      quelle: quelle ?? this.quelle,
      stilId: stilId ?? this.stilId,
      erstelltAm: erstelltAm ?? this.erstelltAm,
      promptAuszug: promptAuszug ?? this.promptAuszug,
      headerFocusX: headerFocusX ?? this.headerFocusX,
      headerFocusY: headerFocusY ?? this.headerFocusY,
      headerZoom: headerZoom ?? this.headerZoom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'quelle': quelle,
    'stilId': stilId,
    'erstelltAm': erstelltAm,
    'promptAuszug': promptAuszug,
    if (headerFocusX != null) 'headerFocusX': headerFocusX,
    if (headerFocusY != null) 'headerFocusY': headerFocusY,
    if (headerZoom != null) 'headerZoom': headerZoom,
  };

  static AvatarGalleryEntry fromJson(Map<String, dynamic> json) {
    return AvatarGalleryEntry(
      id: (json['id'] as String?) ?? '',
      fileName: (json['fileName'] as String?) ?? '',
      quelle: (json['quelle'] as String?) ?? 'upload',
      stilId: (json['stilId'] as String?) ?? '',
      erstelltAm: (json['erstelltAm'] as String?) ?? '',
      promptAuszug: (json['promptAuszug'] as String?) ?? '',
      headerFocusX: _readNormalizedFocusValue(json['headerFocusX']),
      headerFocusY: _readNormalizedFocusValue(json['headerFocusY']),
      headerZoom: _readHeaderZoomValue(json['headerZoom']),
    );
  }
}

double? _readHeaderZoomValue(Object? rawValue) {
  final numericValue = switch (rawValue) {
    num value => value.toDouble(),
    _ => null,
  };
  if (numericValue == null) {
    return null;
  }
  if (numericValue < 1) {
    return 1;
  }
  if (numericValue > 8) {
    return 8;
  }
  return numericValue;
}

double? _readNormalizedFocusValue(Object? rawValue) {
  final numericValue = switch (rawValue) {
    num value => value.toDouble(),
    _ => null,
  };
  if (numericValue == null) {
    return null;
  }
  if (numericValue < 0) {
    return 0;
  }
  if (numericValue > 1) {
    return 1;
  }
  return numericValue;
}
