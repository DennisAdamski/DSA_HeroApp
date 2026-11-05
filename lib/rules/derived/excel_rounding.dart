int excelRound(num value) => value.round();
int excelCeil(num value) => value.ceil();

// Rundet in Richtung Null (entspricht truncate).
int roundDownTowardsZero(num value) => value.truncate();

// Rundet weg von Null (ceil fuer positive, floor fuer negative Werte).
int roundUpAwayFromZero(num value) {
  if (value == value.truncateToDouble()) {
    return value.toInt();
  }
  if (value > 0) {
    return value.ceil();
  }
  return value.floor();
}

/// Hälfte von [wert], aufgerundet; Werte ≤ 0 ergeben 0.
///
/// Halbierungen werden aufgerundet (Wege der Helden S. 6).
int halbiertAufgerundet(int wert) => wert <= 0 ? 0 : (wert + 1) ~/ 2;

/// [zaehler] / [nenner] echt gerundet: ab ,5 weg von 0 (Wege der Helden S. 6).
///
/// `echtGerundet(21, 2)` ist 11 (10,5), `echtGerundet(7, 4)` ist 2,
/// `echtGerundet(5, 4)` ist 1. [nenner] muss positiv sein.
int echtGerundet(int zaehler, int nenner) {
  assert(nenner > 0, 'Nenner muss positiv sein');
  final betrag = (zaehler.abs() * 2 + nenner) ~/ (2 * nenner);
  return zaehler < 0 ? -betrag : betrag;
}

int clampNonNegative(int value) => value < 0 ? 0 : value;
int clampNonPositive(int value) => value > 0 ? 0 : value;
