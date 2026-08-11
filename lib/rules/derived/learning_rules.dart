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

/// Mindest-TaW fuer eine weitere Talentspezialisierung.
///
/// [bestehendeAnzahl] ist die Zahl bereits vorhandener Spezialisierungen
/// desselben Talents; 0 -> TaW 7 (1.), 1 -> TaW 14 (2.), usw.
/// (Wege des Schwerts S. 17: TaW 7/14/21/28 fuer die 1./2./3./4.
/// Spezialisierung).
int requiredTawForSpecialization(int bestehendeAnzahl) {
  return 7 * (bestehendeAnzahl + 1);
}

/// Aktivierungsfaktor je Lernkomplexitaet (SKT-Zeile "Faktor", Wege des
/// Schwerts S. 169) — Grundlage der Talentspezialisierungs-Kosten.
const Map<String, int> kAktivierungsfaktoren = {
  'A*': 1,
  'A': 1,
  'B': 2,
  'C': 3,
  'D': 4,
  'E': 5,
  'F': 8,
  'G': 10,
  'H': 20,
};

/// AP-Kosten fuer den Erwerb einer Talentspezialisierung.
///
/// [basisKomplexitaet] ist die Steigerungskategorie des Talents
/// (`TalentDef.steigerung`), [specializationOrdinal] die 1-basierte
/// Ordnungszahl (1. Spezialisierung = 1, 2. = 2, ...). Begabung senkt die
/// Kategorie wie beim regulaeren Steigern um eine Stufe.
/// Formel: 20 AP * Aktivierungsfaktor(Kategorie) * Ordnungszahl
/// (Wege des Schwerts S. 17, S. 169).
int talentSpecializationApCost({
  required String basisKomplexitaet,
  required bool gifted,
  required int specializationOrdinal,
}) {
  final komplexitaet = effectiveTalentLernkomplexitaet(
    basisKomplexitaet: basisKomplexitaet,
    gifted: gifted,
  );
  final faktor = kAktivierungsfaktoren[komplexitaet] ?? 1;
  return 20 * faktor * specializationOrdinal;
}

/// Mindest-ZfW fuer eine weitere Zauberspezialisierung.
///
/// Wege der Helden S. 292 nennt ZfW 7/14/21/28 fuer die 1./2./3./4.
/// Spezialisierung — dieselbe Staffelung wie bei Talenten. Kein Zufall: Die
/// Zauberspezialisierung ist regeltechnisch als Gegenstueck zur
/// Talentspezialisierung formuliert. Daher wird bewusst dieselbe Funktion
/// verwendet, statt die Zahlen ein zweites Mal zu pflegen.
int requiredZfwForSpecialization(int bestehendeAnzahl) =>
    requiredTawForSpecialization(bestehendeAnzahl);

/// Hoechstzahl an Spezialisierungen je Zauber (Wege der Helden S. 292).
const int kMaxZauberspezialisierungen = 4;

/// AP-Kosten fuer den Erwerb einer Zauberspezialisierung.
///
/// [basisKomplexitaet] ist die Steigerungskategorie des Zaubers
/// (`SpellDef.steigerung`), [specializationOrdinal] die 1-basierte
/// Ordnungszahl innerhalb desselben Zaubers. Formel wie bei Talenten:
/// 20 AP * Aktivierungsfaktor(Kategorie) * Ordnungszahl
/// (Wege der Helden S. 292-293).
int spellSpecializationApCost({
  required String basisKomplexitaet,
  required bool gifted,
  required int specializationOrdinal,
}) {
  return talentSpecializationApCost(
    basisKomplexitaet: basisKomplexitaet,
    gifted: gifted,
    specializationOrdinal: specializationOrdinal,
  );
}
