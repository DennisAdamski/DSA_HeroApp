import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';

/// Geordnete DSA-Lernkomplexitaeten von niedrig nach hoch.
const List<String> kLernkomplexitaeten = [
  'A*',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
];

/// Reduziert eine Lernkomplexitaet um [reductionSteps] Stufen.
///
/// Unbekannte Kategorien werden unveraendert zurueckgegeben. Die Untergrenze
/// ist immer `A*`.
String reduceLernkomplexitaet({
  required String basisKomplexitaet,
  required int reductionSteps,
}) {
  final index = kLernkomplexitaeten.indexOf(basisKomplexitaet.trim());
  if (index < 0 || reductionSteps <= 0) {
    return basisKomplexitaet;
  }
  final reducedIndex = (index - reductionSteps).clamp(
    0,
    kLernkomplexitaeten.length - 1,
  );
  return kLernkomplexitaeten[reducedIndex];
}

/// Erhoeht eine Lernkomplexitaet um [increaseSteps] Stufen.
///
/// Unbekannte Kategorien werden unveraendert zurueckgegeben. Die Obergrenze
/// ist immer `H`.
String increaseLernkomplexitaet({
  required String basisKomplexitaet,
  required int increaseSteps,
}) {
  final index = kLernkomplexitaeten.indexOf(basisKomplexitaet.trim());
  if (index < 0 || increaseSteps <= 0) {
    return basisKomplexitaet;
  }
  final increasedIndex = (index + increaseSteps).clamp(
    0,
    kLernkomplexitaeten.length - 1,
  );
  return kLernkomplexitaeten[increasedIndex];
}

/// Berechnet die effektive Lernkomplexitaet eines Talents.
String effectiveTalentLernkomplexitaet({
  required String basisKomplexitaet,
  required bool gifted,
}) {
  return reduceLernkomplexitaet(
    basisKomplexitaet: basisKomplexitaet,
    reductionSteps: gifted ? 1 : 0,
  );
}

/// Berechnet die effektive Lernkomplexitaet eines Zaubers.
///
/// Hauszauber, passende Merkmalskenntnisse und Begabung summieren sich jeweils
/// als eigene Reduktionsstufe.
String effectiveSpellLernkomplexitaet({
  required String basisKomplexitaet,
  required bool istHauszauber,
  required List<String> zauberMerkmale,
  required List<String> heldMerkmalskenntnisse,
  required bool gifted,
  int penaltySteps = 0,
}) {
  final hatMerkmalReduktion = zauberMerkmale.any(
    heldMerkmalskenntnisse.contains,
  );
  final reductionSteps =
      (istHauszauber ? 1 : 0) +
      (hatMerkmalReduktion ? 1 : 0) +
      (gifted ? 1 : 0);
  final penalizedKomplexitaet = increaseLernkomplexitaet(
    basisKomplexitaet: basisKomplexitaet,
    increaseSteps: penaltySteps,
  );
  return reduceLernkomplexitaet(
    basisKomplexitaet: penalizedKomplexitaet,
    reductionSteps: reductionSteps,
  );
}

/// Berechnet den maximalen Talentwert fuer ein regulaeres Talent.
///
/// Grundlage ist die hoechste an der Probe beteiligte Eigenschaft plus `3`
/// oder `5` bei Begabung.
int computeTalentMaxValue({
  required Attributes effectiveAttributes,
  required List<String> attributeNames,
  required bool gifted,
}) {
  var maxValue = 0;
  for (final name in attributeNames) {
    final code = parseAttributeCode(name);
    if (code == null) {
      continue;
    }
    final value = readAttributeValue(effectiveAttributes, code);
    if (value > maxValue) {
      maxValue = value;
    }
  }
  return maxValue + _giftedLimitBonus(gifted);
}

/// Berechnet den maximalen Talentwert fuer Kampftalente.
///
/// Nahkampf nutzt `GE` oder `KK`, Fernkampf `FF` oder `KK`.
int computeCombatTalentMaxValue({
  required Attributes effectiveAttributes,
  required String talentType,
  required bool gifted,
}) {
  final normalizedType = talentType.trim().toLowerCase();
  final relevantCodes = switch (normalizedType) {
    'nahkampf' => const <AttributeCode>[AttributeCode.ge, AttributeCode.kk],
    'fernkampf' => const <AttributeCode>[AttributeCode.ff, AttributeCode.kk],
    _ => const <AttributeCode>[],
  };
  var maxValue = 0;
  for (final code in relevantCodes) {
    final value = readAttributeValue(effectiveAttributes, code);
    if (value > maxValue) {
      maxValue = value;
    }
  }
  return maxValue + _giftedLimitBonus(gifted);
}

int _giftedLimitBonus(bool gifted) {
  return gifted ? 5 : 3;
}
