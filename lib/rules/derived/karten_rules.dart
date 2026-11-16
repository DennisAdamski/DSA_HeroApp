import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';

// Was die Aventurien-Karte zeigt: Stationen mit Position und der Ausschnitt,
// der Route und Standort umfasst. Gerechnet wird im Koordinatensystem von
// Avesmaps (0 … 1024, Ursprung Südwest, `y` wächst nach Norden).

/// Kantenlänge der Karte in Karteneinheiten.
const double kKartenKante = 1024;

/// Achsenparalleles Rechteck in Karteneinheiten (`y` wächst nach Norden).
class KartenRechteck {
  /// Erstellt das Rechteck; [minX] ≤ [maxX], [minY] ≤ [maxY].
  const KartenRechteck(this.minX, this.minY, this.maxX, this.maxY);

  /// Westrand.
  final double minX;

  /// Südrand.
  final double minY;

  /// Ostrand.
  final double maxX;

  /// Nordrand.
  final double maxY;

  /// Breite (Ost-West).
  double get breite => maxX - minX;

  /// Höhe (Süd-Nord).
  double get hoehe => maxY - minY;

  /// Mittelpunkt Ost-West.
  double get mitteX => (minX + maxX) / 2;

  /// Mittelpunkt Süd-Nord.
  double get mitteY => (minY + maxY) / 2;

  /// Das Rechteck um [x], [y] mit der halben Kantenlänge [halb].
  factory KartenRechteck.um(double x, double y, double halb) =>
      KartenRechteck(x - halb, y - halb, x + halb, y + halb);

  @override
  bool operator ==(Object other) =>
      other is KartenRechteck &&
      other.minX == minX &&
      other.minY == minY &&
      other.maxX == maxX &&
      other.maxY == maxY;

  @override
  int get hashCode => Object.hash(minX, minY, maxX, maxY);

  @override
  String toString() => 'KartenRechteck($minX, $minY, $maxX, $maxY)';
}

/// Die ganze Karte.
const KartenRechteck kKartenWelt = KartenRechteck(
  0,
  0,
  kKartenKante,
  kKartenKante,
);

/// Eine Station der Reiseroute, die auf der Karte steht.
class KartenRoutenPunkt {
  /// Erstellt den Punkt.
  const KartenRoutenPunkt({
    required this.station,
    required this.nummer,
    required this.x,
    required this.y,
  });

  /// Die Station.
  final HeroReiseStation station;

  /// Laufende Nummer der Etappe (wie in Tabelle und Zeitleiste).
  final int nummer;

  /// Kartenposition Ost-West.
  final double x;

  /// Kartenposition Süd-Nord.
  final double y;
}

/// Die Etappen mit Kartenposition, in zeitlicher Reihenfolge.
///
/// Stationen ohne Position fallen weg; die Nummer bleibt die der Etappe,
/// damit Karte und Tabelle dieselbe Zahl zeigen.
List<KartenRoutenPunkt> kartenRoutenPunkte(List<ReiseEtappe> etappen) {
  return List<KartenRoutenPunkt>.unmodifiable(<KartenRoutenPunkt>[
    for (final etappe in etappen)
      if (etappe.station.hatKartenposition)
        KartenRoutenPunkt(
          station: etappe.station,
          nummer: etappe.nummer,
          x: etappe.station.kartenX!,
          y: etappe.station.kartenY!,
        ),
  ]);
}

/// Das kleinste Rechteck um alle [orte], oder die ganze Karte ohne Orte.
KartenRechteck kartenBegrenzung(List<AvesmapsOrt> orte) {
  if (orte.isEmpty) return kKartenWelt;
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final ort in orte) {
    minX = math.min(minX, ort.x);
    minY = math.min(minY, ort.y);
    maxX = math.max(maxX, ort.x);
    maxY = math.max(maxY, ort.y);
  }
  return KartenRechteck(minX, minY, maxX, maxY);
}

/// Rand um die Punkte eines Ausschnitts in Karteneinheiten (30 Meilen).
const double kKartenAusschnittRand = 10;

/// Mindestkantenlänge eines Ausschnitts in Karteneinheiten (240 Meilen):
/// Ein einzelner Ort steht so mit seiner Umgebung da.
const double kKartenAusschnittMindestKante = 80;

/// Ausschnitt um die [punkte] (`(x, y)`) mit [rand], mindestens
/// [mindestKante] breit und hoch.
///
/// Ohne Punkte gilt [ohnePunkte] (meist die Begrenzung des
/// Ortsverzeichnisses).
KartenRechteck kartenAusschnitt(
  List<(double, double)> punkte, {
  KartenRechteck ohnePunkte = kKartenWelt,
  double rand = kKartenAusschnittRand,
  double mindestKante = kKartenAusschnittMindestKante,
}) {
  if (punkte.isEmpty) return ohnePunkte;
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final (x, y) in punkte) {
    minX = math.min(minX, x);
    minY = math.min(minY, y);
    maxX = math.max(maxX, x);
    maxY = math.max(maxY, y);
  }
  final halbB = math.max((maxX - minX) / 2 + rand, mindestKante / 2);
  final halbH = math.max((maxY - minY) / 2 + rand, mindestKante / 2);
  final mx = (minX + maxX) / 2;
  final my = (minY + maxY) / 2;
  return KartenRechteck(mx - halbB, my - halbH, mx + halbB, my + halbH);
}
