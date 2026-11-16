import 'dart:math' as math;
import 'dart:ui';

// Kartenstil nach dem Vorbild von Avesmaps.
//
// Herkunft: Designkanon `avesmaps.json` im ausgelieferten Bundle von
// avesmaps.de (`gemeinsam-*.js`, Abschnitte `colour`, `marker`, `label`,
// `capital`, `structure`, `spacing`, `mapLabel`, `route`), gelesen am
// 13.11.2026. Übernommen sind nur Zahlen und Farben, kein Code. Ändert
// Avesmaps seinen Stil, bleibt dieser Stand, bis jemand nachzieht.

/// Farben der Karte. Wie bei Avesmaps kippen Marken nicht mit dem Theme;
/// nur Papier und Rückfallflächen haben eine dunkle Fassung.
abstract final class KartenFarben {
  /// Kartenpapier (`mapPaper`).
  static const Color papier = Color(0xFFF4EFE4);

  /// Kartenpapier im dunklen Theme (`pageBgDeep`).
  static const Color papierDunkel = Color(0xFF2B2721);

  /// Land im Rückfall ohne Kartenbild, aus der Ortsdichte geschätzt.
  static const Color land = Color(0xFFE4D7B8);

  /// Land im Rückfall, dunkles Theme.
  static const Color landDunkel = Color(0xFF3C352B);

  /// Gitterlinien im Rückfall (`textMuted`, schwach).
  static const Color gitter = Color(0x1F706557);

  /// Siedlung (`markerSettlement`).
  static const Color siedlung = Color(0xFFCC2F2A);

  /// Kontur der Marken (`markerSettlementContour`).
  static const Color kontur = Color(0xFFFFFFFF);

  /// Dunkle 1-px-Haarlinie um jede Marke (`markerHairline`).
  static const Color haarlinie = Color(0x8C000000);

  /// Bauwerk und Stadtviertel (`markerSettlementSite`).
  static const Color bauwerk = Color(0xFF635497);

  /// Ring der Metropolen (`markerCapitalRing`).
  static const Color hauptstadtRing = Color(0xFFE7B04A);

  /// Rand des Metropolenrings (`markerCapitalRingEdge`).
  static const Color hauptstadtRand = Color(0x59000000);

  /// Auswahl auf der Karte (`mapSelection`).
  static const Color auswahl = Color(0xFFFFD72E);

  /// Schein der Auswahl (`mapSelectionGlow`).
  static const Color auswahlSchein = Color(0xEBFFE64A);

  /// Route (`route`).
  static const Color route = Color(0xFF1452F7);

  /// Saum der Route (`routeHalo`).
  static const Color routeSaum = Color(0xFFFFFFFF);

  /// Wegpunkt (`markerWaypoint`).
  static const Color wegpunkt = Color(0xFFE33B35);

  /// Kern bzw. Rand des Wegpunkts (`markerWaypointCore`).
  static const Color wegpunktKern = Color(0xFF2E2119);

  /// Goldring des Wegpunkts (`markerWaypointRing`).
  static const Color wegpunktRing = Color(0xFFDCB877);

  /// Reisender, Scheitel (`travelerLightTip`).
  static const Color reisenderSpitze = Color(0xFFF3C08C);

  /// Reisender, Fuß (`travelerLightBase`).
  static const Color reisenderFuss = Color(0xFFC07A3E);

  /// Reisender, Rand (`travelerRim`).
  static const Color reisenderRand = Color(0xFF4A3218);

  /// Ortsnamen (`mapLabel.families.place.color`).
  static const Color beschriftung = Color(0xFFFFFFFF);

  /// Saum der Ortsnamen (`mapLabel.families.place.haloColor`).
  static const Color beschriftungSaum = Color(0xFF000000);

  /// Bedienknopf (`button`).
  static const Color knopf = Color(0xFF5B5548);

  /// Rand des Bedienknopfs (`buttonBorder`).
  static const Color knopfRand = Color(0xFF635B4D);

  /// Schrift auf dem Bedienknopf (`buttonText`).
  static const Color knopfText = Color(0xFFF6EFE1);

  /// Tafel (`panel`).
  static const Color tafel = Color(0xFFFFFDF9);

  /// Text (`text`).
  static const Color text = Color(0xFF2E271E);

  /// Leiser Text (`textMuted`).
  static const Color textLeise = Color(0xFF706557);

  /// Rahmen (`border`).
  static const Color rahmen = Color(0xFFDDD3C3);

  /// Kompass, Nordhälfte hell (`compassNorthLight`).
  static const Color kompassNordHell = Color(0xFFBFA03A);

  /// Kompass, Nordhälfte Schatten (`compassNorthShade`).
  static const Color kompassNordSchatten = Color(0xFF7E651D);

  /// Kompass, Südhälfte hell (`compassSouthLight`).
  static const Color kompassSuedHell = Color(0xFFCDBFA8);

  /// Kompass, Südhälfte Schatten (`compassSouthShade`).
  static const Color kompassSuedSchatten = Color(0xFF706557);
}

/// Schriftfamilie der Karte (`typography.fontFamily`, „Faculty Glyphic“).
const String kKartenSchrift = 'FacultyGlyphic';

/// Anzahl der Zoombänder; Band 8 erbt Band 7 (`bandCount`).
const int kKartenBaender = 9;

/// Kleinster Zoom der Kamera.
const double kKartenZoomMin = 0;

/// Größter Zoom der Kamera.
const double kKartenZoomMax = 8;

/// Ortsklassen in der Reihenfolge ihres Vorrangs, bedeutend zuerst.
const List<String> kKartenOrtsklassen = <String>[
  'metropole',
  'grossstadt',
  'stadt',
  'kleinstadt',
  'dorf',
  'gebaeude',
  'stadtviertel',
];

/// Vorrang einer Ortsklasse für Beschriftung und Zeichenfolge; größer ist
/// bedeutender. Unbekannte Klassen zählen wie ein Dorf.
int kartenVorrang(String art) {
  final index = kKartenOrtsklassen.indexOf(art);
  return kKartenOrtsklassen.length - (index < 0 ? 4 : index);
}

/// Äußerer Durchmesser der Ortsmarke in px je Band (`marker`).
const Map<String, List<double?>> kKartenMarkerTafel = <String, List<double?>>{
  'metropole': <double?>[6.65, 9.4, 13.3, 18.81, 26.6, 37.62, 53.2, 53.2, 53.2],
  'grossstadt': <double?>[
    3.99,
    5.86,
    8.6,
    12.62,
    18.52,
    27.18,
    39.9,
    39.9,
    39.9,
  ],
  'stadt': <double?>[1.33, 2.26, 3.84, 6.52, 11.07, 18.79, 31.92, 31.92, 31.92],
  'kleinstadt': <double?>[
    null,
    1.33,
    2.39,
    4.29,
    7.7,
    13.82,
    24.82,
    24.82,
    24.82,
  ],
  'dorf': <double?>[null, null, 1.33, 2.54, 4.86, 9.28, 17.74, 17.74, 17.74],
  'gebaeude': <double?>[null, null, null, 1.33, 2.8, 5.9, 12.42, 12.42, 12.42],
  'stadtviertel': <double?>[
    null,
    null,
    null,
    1.33,
    2.8,
    5.9,
    12.42,
    12.42,
    12.42,
  ],
};

/// Schriftgröße der Ortsnamen in pt je Band (`label`); die Karte rechnet
/// sie mit [kPunktZuPixel] in px um (Kalibrierfaktor 1,0).
const Map<String, List<double?>> kKartenBeschriftungTafel =
    <String, List<double?>>{
      'metropole': <double?>[8, 9, 11, 13, 17, 19, 19, 19, 19],
      'grossstadt': <double?>[8, 8.5, 10, 12, 15, 17, 17, 17, 17],
      'stadt': <double?>[null, null, 9, 11, 13, 15, 15, 15, 15],
      'kleinstadt': <double?>[null, null, null, 9.5, 11, 13, 13, 13, 13],
      'dorf': <double?>[null, null, null, null, 10, 11, 11, 11, 11],
      'gebaeude': <double?>[null, null, null, null, 9, 9, 9, 9, 9],
      'stadtviertel': <double?>[null, null, null, null, 9, 9, 9, 9, 9],
    };

/// Umrechnung der Ortsschrift von pt in px (Avesmaps: `* 4 / 3`).
const double kPunktZuPixel = 4 / 3;

/// Ab welchem Band Metropolen den Goldring tragen (`capital.fromBand`).
const int kHauptstadtAbBand = 3;

/// Mindestdurchmesser einer beringten Metropole (`capital.minDiameter`).
const double kHauptstadtMindestDurchmesser = 14;

/// Anteil des Rings am Durchmesser (`capital.ringRatio`).
const double kHauptstadtRingAnteil = .12;

/// Ab welchem Band Bauwerke und Stadtviertel als Raute stehen
/// (`structure.diamondFromBand`).
const int kRauteAbBand = 4;

/// Weiße Kontur in Prozent des Kernhalbmessers (`spacing.kontur`).
const double kKonturAnteil = .33;

/// Haarlinie um jede Marke in px (`spacing.haarlinie`).
const double kHaarlinie = 1;

/// Abstand zwischen Marke und Name in px (`spacing.namensspalt`).
const double kNamensspalt = 2;

/// Kollisionspuffer zwischen Namen in px (`spacing.spalt`).
const double kBeschriftungsPuffer = 4;

/// Saumbreite der Ortsnamen im Verhältnis zur Schriftgröße
/// (`mapLabel.families.place.haloWidthRatio`).
const double kSaumBreiteAnteil = .07;

/// Weichzeichnung des Saums im Verhältnis zur Schriftgröße
/// (`haloBlurRatio`).
const double kSaumWeichAnteil = .05;

/// Breite der Routenlinie in px (`route.width`).
const double kRoutenBreite = 7;

/// Breite des weißen Saums der Route in px (`route.haloWidth`).
const double kRoutenSaum = 2;

/// Strichlänge der Pillen für Luftlinie bzw. Querfeldein in px
/// (`route.offroadDash[0]`).
const double kPillenStrich = 10;

/// Lücke zwischen den Pillen in px (`route.offroadDash[1]`).
const double kPillenLuecke = 14;

/// Durchmesser der Wegpunkt-Scheibe in px (`route.markerDisc`).
const double kWegpunktScheibe = 34;

/// Höhe des Reisenden in px (`route.travelerSize`).
const double kReisenderGroesse = 30;

/// Wert aus einer Band-Tafel bei [zoom], linear zwischen den Bändern.
///
/// `null`, solange die Klasse in diesem Band nicht erscheint. Zwischen einem
/// leeren und einem belegten Band bleibt sie unsichtbar, bis das belegte
/// Band erreicht ist (wie der Zoomfilter von Avesmaps).
double? kartenBandWert(List<double?> tafel, double zoom) {
  final z = zoom.clamp(0.0, (kKartenBaender - 1).toDouble());
  final unten = z.floor();
  final a = tafel[unten];
  if (a == null) return null;
  if (unten >= tafel.length - 1) return a;
  final b = tafel[unten + 1] ?? a;
  return a + (b - a) * (z - unten);
}

/// Äußerer Durchmesser der Marke einer Ortsklasse [art] bei [zoom] in px,
/// oder `null` (unsichtbar). Unbekannte Klassen zeichnen wie ein Dorf.
double? markerDurchmesser(String art, double zoom) => kartenBandWert(
  kKartenMarkerTafel[art] ?? kKartenMarkerTafel['dorf']!,
  zoom,
);

/// Schriftgröße des Ortsnamens einer Ortsklasse [art] bei [zoom] in px, oder
/// `null` (kein Name).
double? beschriftungsGroesse(String art, double zoom) {
  final pt = kartenBandWert(
    kKartenBeschriftungTafel[art] ?? kKartenBeschriftungTafel['dorf']!,
    zoom,
  );
  return pt == null ? null : pt * kPunktZuPixel;
}

/// Form einer Ortsmarke.
enum KartenMarkenForm {
  /// Kreis mit Haarlinie, weißer Kontur und rotem Kern.
  kreis,

  /// Wie [kreis], zusätzlich mit Goldring (Metropolen).
  hauptstadt,

  /// Raute (Bauwerke und Stadtviertel ab [kRauteAbBand]).
  raute,
}

/// Form der Marke für [art] bei [zoom] und [durchmesser].
KartenMarkenForm markenForm(String art, double zoom, double durchmesser) {
  final band = zoom.clamp(0.0, 8.0).floor();
  if ((art == 'gebaeude' || art == 'stadtviertel') && band >= kRauteAbBand) {
    return KartenMarkenForm.raute;
  }
  if (art == 'metropole' &&
      band >= kHauptstadtAbBand &&
      durchmesser >= kHauptstadtMindestDurchmesser) {
    return KartenMarkenForm.hauptstadt;
  }
  return KartenMarkenForm.kreis;
}

/// Kernfarbe der Marke einer Ortsklasse.
Color markenFarbe(String art) => art == 'gebaeude' || art == 'stadtviertel'
    ? KartenFarben.bauwerk
    : KartenFarben.siedlung;

/// Halbmesser des Kerns bei äußerem Halbmesser [aussen]: innerhalb der
/// Haarlinie liegt die weiße Kontur mit [kKonturAnteil] des Kerns.
double kernHalbmesser(double aussen) =>
    math.max(0, aussen - kHaarlinie) / (1 + kKonturAnteil);
