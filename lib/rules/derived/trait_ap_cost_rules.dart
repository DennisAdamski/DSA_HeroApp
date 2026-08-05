/// AP-Kostenfaktoren fuer den nachtraeglichen Kauf/Abbau von Vor- und
/// Nachteilen nach der Heldenerschaffung.
///
/// Regelquelle: Wege des Schwerts S. 170 ("Abbau von Nachteilen" /
/// "Spaeterer Erwerb von Vor- und Nachteilen"). Diese optionale
/// Meisterregel rechnet den GP-Wert eines Vor-/Nachteils in AP um.
library;

import 'dart:math' as math;

/// Fuer den spaeteren Erwerb eines Vorteils: AP = 50 x GP-Wert.
const int kVorteilErwerbFaktor = 50;

/// Fuer den Abbau eines Nachteils: AP = 100 x GP-Wert.
const int kNachteilAbbauFaktor = 100;

/// Fuer das Senken einer Schlechten Eigenschaft um 1 Punkt via Spezieller
/// Erfahrung: AP = 50 x GP-Wert.
const int kSchlechteEigenschaftSpezErfahrungFaktor = 50;

/// Fuer das Senken einer Schlechten Eigenschaft um 1 Punkt im
/// Selbststudium (1,5-facher Aufwand): AP = 75 x GP-Wert.
const int kSchlechteEigenschaftSelbststudiumFaktor = 75;

/// Berechnet die AP-Kosten aus einem GP-Wert und einem Canon-Faktor.
///
/// Das Vorzeichen des GP-Werts wird ignoriert (Nachteile haben in den
/// Katalogen negative GP-Werte), das Ergebnis ist stets nicht-negativ.
int computeTraitApCost(int gpWert, int faktor) {
  return math.max(0, gpWert.abs() * faktor);
}
