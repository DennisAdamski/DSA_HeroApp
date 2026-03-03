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

int clampNonNegative(int value) => value < 0 ? 0 : value;
