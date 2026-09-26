/// Normierter Rahmen eines erkannten Gesichts.
///
/// Alle Werte sind Anteile der Bildbreite bzw. -hoehe (0..1). Der Rahmen
/// entspricht der Box des Detektors und reicht etwa von den Brauen bis zum
/// Kinn; Haar und Stirn liegen darueber.
class AvatarGesichtsrahmen {
  const AvatarGesichtsrahmen({
    required this.links,
    required this.oben,
    required this.breite,
    required this.hoehe,
  });

  final double links;
  final double oben;
  final double breite;
  final double hoehe;

  double get mitteX => links + breite / 2;
  double get mitteY => oben + hoehe / 2;

  Map<String, dynamic> toJson() => {
    'l': links,
    'o': oben,
    'b': breite,
    'h': hoehe,
  };

  /// Liest einen Rahmen; unvollstaendige oder leere Werte ergeben `null`.
  static AvatarGesichtsrahmen? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final links = _zahl(raw['l']);
    final oben = _zahl(raw['o']);
    final breite = _zahl(raw['b']);
    final hoehe = _zahl(raw['h']);
    if (links == null || oben == null || breite == null || hoehe == null) {
      return null;
    }
    if (breite <= 0 || hoehe <= 0) return null;
    return AvatarGesichtsrahmen(
      links: links,
      oben: oben,
      breite: breite,
      hoehe: hoehe,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarGesichtsrahmen &&
      other.links == links &&
      other.oben == oben &&
      other.breite == breite &&
      other.hoehe == hoehe;

  @override
  int get hashCode => Object.hash(links, oben, breite, hoehe);

  @override
  String toString() =>
      'AvatarGesichtsrahmen(links: $links, oben: $oben, '
      'breite: $breite, hoehe: $hoehe)';
}

/// Ergebnis der Gesichtserkennung fuer ein Avatarbild.
///
/// Traegt immer die Originalgroesse des Bildes, auch wenn kein Gesicht
/// gefunden wurde: Die Rahmung braucht sie fuer den Rueckfall-Ausschnitt.
/// Neue Bilder tragen ihn beim Anlegen am Galerieeintrag
/// (`AvatarGalleryEntry.gesichtsbefund`), Bestandsbilder nur im lokalen Cache
/// (`AvatarGesichtService`) — nachgetragen wird er nie in einen Helden.
class AvatarGesichtsbefund {
  const AvatarGesichtsbefund({
    required this.bildBreite,
    required this.bildHoehe,
    this.gesicht,
    this.konfidenz = 0,
  });

  /// Breite des Originalbildes in Pixeln.
  final int bildBreite;

  /// Hoehe des Originalbildes in Pixeln.
  final int bildHoehe;

  /// Erkanntes Gesicht, oder `null` wenn keines gefunden wurde.
  final AvatarGesichtsrahmen? gesicht;

  /// Score des Detektors (0..1); 0 ohne Gesicht.
  final double konfidenz;

  Map<String, dynamic> toJson() => {
    'w': bildBreite,
    'h': bildHoehe,
    if (gesicht != null) 'g': gesicht!.toJson(),
    if (gesicht != null) 'k': konfidenz,
  };

  /// Liest einen Befund; ohne gueltige Bildgroesse ergibt sich `null`.
  static AvatarGesichtsbefund? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final breite = _zahl(raw['w'])?.round();
    final hoehe = _zahl(raw['h'])?.round();
    if (breite == null || hoehe == null || breite <= 0 || hoehe <= 0) {
      return null;
    }
    final gesicht = AvatarGesichtsrahmen.fromJson(raw['g']);
    return AvatarGesichtsbefund(
      bildBreite: breite,
      bildHoehe: hoehe,
      gesicht: gesicht,
      konfidenz: gesicht == null ? 0 : (_zahl(raw['k']) ?? 0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarGesichtsbefund &&
      other.bildBreite == bildBreite &&
      other.bildHoehe == bildHoehe &&
      other.gesicht == gesicht &&
      other.konfidenz == konfidenz;

  @override
  int get hashCode => Object.hash(bildBreite, bildHoehe, gesicht, konfidenz);

  @override
  String toString() =>
      'AvatarGesichtsbefund(${bildBreite}x$bildHoehe, gesicht: $gesicht, '
      'konfidenz: $konfidenz)';
}

double? _zahl(Object? raw) {
  if (raw is num && raw.isFinite) return raw.toDouble();
  return null;
}
