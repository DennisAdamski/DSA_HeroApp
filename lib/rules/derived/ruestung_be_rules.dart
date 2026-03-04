import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';

// Gesamtruestungsschutz der aktiven Ruestungsteile.
int computeRsTotal(List<ArmorPiece> activePieces) {
  var sum = 0;
  for (final piece in activePieces) {
    sum += clampNonNegative(piece.rs);
  }
  return sum;
}

// Rohwert der Gesamtbehinderung aus aktiven Ruestungsteilen.
int computeBeTotalRaw(List<ArmorPiece> activePieces) {
  var sum = 0;
  for (final piece in activePieces) {
    sum += clampNonNegative(piece.be);
  }
  return sum;
}

// Ruestungsgewoehnungs-Reduktion (RG I/II/III).
int computeRgReduction({
  required int globalArmorTrainingLevel,
  required List<ArmorPiece> activePieces,
}) {
  final normalizedTraining =
      globalArmorTrainingLevel == 1 ||
          globalArmorTrainingLevel == 2 ||
          globalArmorTrainingLevel == 3
      ? globalArmorTrainingLevel
      : 0;
  if (normalizedTraining == 3) {
    return 2;
  }
  if (normalizedTraining == 2) {
    return 1;
  }
  if (normalizedTraining != 1) {
    return 0;
  }
  final hasAnyActiveRg1 = activePieces.any((piece) => piece.rg1Active);
  return hasAnyActiveRg1 ? 1 : 0;
}

// Effektive Kampfbehinderung nach Ruestungsgewoehnungs-Abzug.
int computeBeKampf(int beTotalRaw, int rgReduction) {
  return clampNonNegative(beTotalRaw - rgReduction);
}

// Effektive Behinderung (eBE) fuer den gewaehlten Waffenslot.
int computeEbe({required int beKampf, required int beMod}) {
  return _min(0, -beKampf - beMod);
}

// AT-Anteil der eBE (Truncate in Richtung Null).
int computeAtEbePart(int ebe) {
  return roundDownTowardsZero(ebe / 2);
}

// PA-Anteil der eBE (traegt die groessere Haelfte bei ungeradem eBE).
int computePaEbePart(int ebe) {
  return roundUpAwayFromZero(ebe / 2);
}

// Parst den BE-Modifier eines Katalogtalents als Ganzzahl.
int parseBeModifier(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '-') {
    return 0;
  }
  final parsed = int.tryParse(trimmed);
  return parsed ?? 0;
}

// Berechnet die effektive Behinderung (eBE) eines einzelnen Talents
// anhand der Katalog-BE-Regel (z. B. "-", "-3", "x2").
int computeTalentEbe({required int baseBe, required String talentBeRule}) {
  final normalizedBase = baseBe < 0 ? 0 : baseBe;
  final compactRule = talentBeRule.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    '',
  );
  if (compactRule.isEmpty || compactRule == '-') {
    return 0;
  }

  if (compactRule.startsWith('x')) {
    final factorRaw = compactRule.substring(1);
    final factor = int.tryParse(factorRaw);
    if (factor == null || factor < 0) {
      return 0;
    }
    final reduction = normalizedBase * factor;
    return _clampNonPositive(-reduction);
  }

  final numeric = int.tryParse(compactRule);
  if (numeric == null || numeric >= 0) {
    return 0;
  }
  final offset = -numeric;
  final reduction = normalizedBase - offset;
  final effectiveReduction = reduction < 0 ? 0 : reduction;
  return _clampNonPositive(-effectiveReduction);
}

int _clampNonPositive(int value) => value > 0 ? 0 : value;
int _min(int a, int b) => a < b ? a : b;
