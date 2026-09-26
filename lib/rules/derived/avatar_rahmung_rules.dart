import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';

/// Wie eng eine beschnittene Avatarflaeche das Gesicht fasst.
enum AvatarRahmung {
  /// Kopf mit etwas Schulter: runde Heldenmarke, Albumkachel, Thumbnail.
  portraet(gesichtsAnteil: 0.36, gesichtsMitte: 0.52),

  /// Enger auf das Gesicht: der breite, niedrige Workspace-Header.
  kopfzeile(gesichtsAnteil: 0.42, gesichtsMitte: 0.56);

  const AvatarRahmung({
    required this.gesichtsAnteil,
    required this.gesichtsMitte,
  });

  /// Anteil der Ausschnitthoehe, den der Gesichtsrahmen einnimmt.
  ///
  /// Der Detektor rahmt etwa Brauen bis Kinn; bei 0,36 fuellt der ganze Kopf
  /// gut die Haelfte der Hoehe, Haar und Kopfbedeckung bleiben im Bild.
  final double gesichtsAnteil;

  /// Hoehe der Gesichtsmitte im Ausschnitt, von oben (0..1).
  final double gesichtsMitte;
}

/// Normierter Quellausschnitt eines Bildes (Anteile von Breite und Hoehe).
class AvatarAusschnitt {
  const AvatarAusschnitt({
    required this.links,
    required this.oben,
    required this.breite,
    required this.hoehe,
  });

  /// Das ganze Bild.
  static const AvatarAusschnitt ganz = AvatarAusschnitt(
    links: 0,
    oben: 0,
    breite: 1,
    hoehe: 1,
  );

  final double links;
  final double oben;
  final double breite;
  final double hoehe;

  @override
  bool operator ==(Object other) =>
      other is AvatarAusschnitt &&
      other.links == links &&
      other.oben == oben &&
      other.breite == breite &&
      other.hoehe == hoehe;

  @override
  int get hashCode => Object.hash(links, oben, breite, hoehe);

  @override
  String toString() =>
      'AvatarAusschnitt(links: $links, oben: $oben, '
      'breite: $breite, hoehe: $hoehe)';
}

/// Hoechster Zoom gegenueber dem groesstmoeglichen Ausschnitt.
///
/// Darueber wuerden kleine Gesichter in grossen Bildern verpixeln.
const double kAvatarMaxZoom = 4;

/// Hoehe der Bildmitte des Rueckfall-Ausschnitts bei Hochformat.
///
/// Ohne erkanntes Gesicht sitzt der Kopf in Portraets fast immer in der
/// oberen Bildhaelfte; die Bildmitte zeigte dort Brust oder Guertel.
const double kAvatarRueckfallMitteHochformat = 0.38;

/// Berechnet den Quellausschnitt fuer eine Zielflaeche.
///
/// Der Ausschnitt hat in Pixeln exakt das [seitenverhaeltnis] (Breite durch
/// Hoehe) der Zielflaeche und liegt immer vollstaendig im Bild. Mit Gesicht
/// wird es nach [rahmung] gefasst; ohne Gesicht gilt der groesstmoegliche
/// Ausschnitt, horizontal mittig und bei Hochformat in der oberen Bildhaelfte.
AvatarAusschnitt berechneAvatarAusschnitt({
  required int bildBreite,
  required int bildHoehe,
  required double seitenverhaeltnis,
  required AvatarRahmung rahmung,
  AvatarGesichtsrahmen? gesicht,
}) {
  if (bildBreite <= 0 ||
      bildHoehe <= 0 ||
      !seitenverhaeltnis.isFinite ||
      seitenverhaeltnis <= 0) {
    return AvatarAusschnitt.ganz;
  }
  final w = bildBreite.toDouble();
  final h = bildHoehe.toDouble();

  // Groesstmoeglicher Ausschnitt im Zielformat (entspricht BoxFit.cover).
  final double maxBreite;
  final double maxHoehe;
  if (w / h > seitenverhaeltnis) {
    maxHoehe = h;
    maxBreite = h * seitenverhaeltnis;
  } else {
    maxBreite = w;
    maxHoehe = w / seitenverhaeltnis;
  }

  if (gesicht == null) {
    final mitteY = h > w ? h * kAvatarRueckfallMitteHochformat : h / 2;
    return _normiert(
      links: (w - maxBreite) / 2,
      oben: mitteY - maxHoehe / 2,
      breite: maxBreite,
      hoehe: maxHoehe,
      bildBreite: w,
      bildHoehe: h,
    );
  }

  final gesichtBreite = gesicht.breite * w;
  final gesichtHoehe = gesicht.hoehe * h;
  var hoehe = gesichtHoehe / rahmung.gesichtsAnteil;
  // Breite Gesichter (Seitenansicht, Helm) duerfen nicht angeschnitten werden.
  final mindestBreite = gesichtBreite / 0.8;
  if (hoehe * seitenverhaeltnis < mindestBreite) {
    hoehe = mindestBreite / seitenverhaeltnis;
  }
  hoehe = hoehe.clamp(maxHoehe / kAvatarMaxZoom, maxHoehe).toDouble();
  final breite = hoehe * seitenverhaeltnis;

  return _normiert(
    links: gesicht.mitteX * w - breite / 2,
    oben: gesicht.mitteY * h - rahmung.gesichtsMitte * hoehe,
    breite: breite,
    hoehe: hoehe,
    bildBreite: w,
    bildHoehe: h,
  );
}

AvatarAusschnitt _normiert({
  required double links,
  required double oben,
  required double breite,
  required double hoehe,
  required double bildBreite,
  required double bildHoehe,
}) {
  final x = links.clamp(0.0, math.max(bildBreite - breite, 0.0)).toDouble();
  final y = oben.clamp(0.0, math.max(bildHoehe - hoehe, 0.0)).toDouble();
  return AvatarAusschnitt(
    links: x / bildBreite,
    oben: y / bildHoehe,
    breite: breite / bildBreite,
    hoehe: hoehe / bildHoehe,
  );
}
