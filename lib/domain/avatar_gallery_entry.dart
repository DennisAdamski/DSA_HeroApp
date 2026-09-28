import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

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
    this.gesichtsbefund,
    this.gesichtsbefundVersion,
    this.unbekannteFelder = const <String, Object?>{},
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

  /// Gesichtsbefund, erkannt beim Anlegen des Bildes.
  ///
  /// Wird **nur** beim Hochladen oder Generieren gesetzt, weil der Held dabei
  /// ohnehin gespeichert wird. Nachtraeglich darf er nie in einen Helden
  /// geschrieben werden: das Feld geht in `heroContentHash` ein, und ein
  /// Nachtragen fuer Bestandsbilder loeste beim Konto-Sync Konflikte aus.
  /// Bestandsbilder nutzen stattdessen den lokalen Cache
  /// (`AvatarGesichtService`).
  final AvatarGesichtsbefund? gesichtsbefund;

  /// `kAvatarGesichtDetektorVersion`, mit der [gesichtsbefund] entstand.
  final int? gesichtsbefundVersion;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest — einschliesslich der nur bedingt
  /// geschriebenen; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'fileName',
    'quelle',
    'stilId',
    'erstelltAm',
    'promptAuszug',
    'headerFocusX',
    'headerFocusY',
    'headerZoom',
    'gesicht',
  };

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
    AvatarGesichtsbefund? gesichtsbefund,
    int? gesichtsbefundVersion,
    Map<String, Object?>? unbekannteFelder,
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
      gesichtsbefund: gesichtsbefund ?? this.gesichtsbefund,
      gesichtsbefundVersion:
          gesichtsbefundVersion ?? this.gesichtsbefundVersion,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'id': id,
    'fileName': fileName,
    'quelle': quelle,
    'stilId': stilId,
    'erstelltAm': erstelltAm,
    'promptAuszug': promptAuszug,
    if (headerFocusX != null) 'headerFocusX': headerFocusX,
    if (headerFocusY != null) 'headerFocusY': headerFocusY,
    if (headerZoom != null) 'headerZoom': headerZoom,
    // Nur bei belegtem Wert: sonst aendert sich das JSON jedes
    // Bestandseintrags und mit ihm `heroContentHash`.
    if (gesichtsbefund != null)
      'gesicht': {'v': gesichtsbefundVersion ?? 0, ...gesichtsbefund!.toJson()},
  }, unbekannteFelder);

  static AvatarGalleryEntry fromJson(Map<String, dynamic> json) {
    final rohGesicht = json['gesicht'];
    final gesichtsbefund = AvatarGesichtsbefund.fromJson(rohGesicht);
    final rohVersion = rohGesicht is Map ? rohGesicht['v'] : null;
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
      gesichtsbefund: gesichtsbefund,
      gesichtsbefundVersion: gesichtsbefund == null || rohVersion is! num
          ? null
          : rohVersion.toInt(),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
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
