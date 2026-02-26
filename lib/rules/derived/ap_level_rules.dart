import 'dart:math' as math;

int computeLevelFromSpentAp(int spentAp) {
  final normalized = spentAp < 0 ? 0 : spentAp;
  final raw = math.sqrt(normalized / 50 + 0.25) + 0.5;
  final level = raw.floor();
  return level < 1 ? 1 : level;
}

int computeAvailableAp(int total, int spent) {
  final normalizedTotal = total < 0 ? 0 : total;
  final normalizedSpent = spent < 0 ? 0 : spent;
  final remaining = normalizedTotal - normalizedSpent;
  return remaining < 0 ? 0 : remaining;
}
