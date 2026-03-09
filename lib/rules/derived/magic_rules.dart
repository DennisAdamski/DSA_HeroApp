import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';

// Magie-Regelfunktionen (pure Dart, keine Seiteneffekte).
//
// Enthaelt Logik fuer:
// - Parsing von Zauber-Verfuegbarkeits-Strings
// - Filterung nach Held-Repraesentationen
// - Parsing von Merkmalen

/// Ein einzelner Eintrag in der Verfuegbarkeitsliste eines Zaubers.
///
/// Beispiel: "Mag6" -> tradition='Mag', learnedRepresentation='Mag'
/// Beispiel: "Dru(Elf)2" -> tradition='Dru', learnedRepresentation='Elf'
class SpellAvailabilityEntry {
  const SpellAvailabilityEntry({
    required this.tradition,
    required this.learnedRepresentation,
    required this.verbreitung,
  });

  /// Haupttradition, die den Zugang zu diesem Availability-Eintrag erlaubt.
  final String tradition;

  /// Die konkrete Repraesentation, in der der Zauber gelernt wird.
  final String learnedRepresentation;

  final int verbreitung;

  /// Kennzeichnet Eintraege wie `Dru(Elf)2`, also Lernen in Fremdrepr.
  bool get isForeignRepresentation => learnedRepresentation != tradition;

  /// Liefert ein stabiles Label zur Persistenz und fuer Dropdowns.
  String get storageKey => '$tradition->$learnedRepresentation';

  /// Liefert ein kompaktes Anzeigenlabel fuer Katalogtabellen und Auswahl-UI.
  String get displayLabel {
    if (isForeignRepresentation) {
      return '$tradition -> $learnedRepresentation $verbreitung';
    }
    return '$learnedRepresentation $verbreitung';
  }
}

/// Regex zum Parsen einzelner Verfuegbarkeits-Tokens.
///
/// Erkennt Formate wie: "Mag6", "Dru(Elf)2", "Hex(Mag)3"
final RegExp _availabilityPattern = RegExp(
  r'([A-Za-z\u00c4\u00d6\u00dc\u00e4\u00f6\u00fc]+)(?:\(([A-Za-z\u00c4\u00d6\u00dc\u00e4\u00f6\u00fc]+)\))?(\d+)',
);

/// Parst den availability-String eines Zaubers in strukturierte Eintraege.
///
/// Input: "Mag6, Hex3, Dru(Elf)2"
/// Output: [SpellAvailabilityEntry('Mag', null, 6), ...]
List<SpellAvailabilityEntry> parseSpellAvailability(String availability) {
  if (availability.isEmpty) {
    return const [];
  }
  final entries = <SpellAvailabilityEntry>[];
  for (final part in availability.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final match = _availabilityPattern.firstMatch(trimmed);
    if (match == null) {
      continue;
    }
    entries.add(
      SpellAvailabilityEntry(
        tradition: match.group(1)!,
        learnedRepresentation: match.group(2) ?? match.group(1)!,
        verbreitung: int.parse(match.group(3)!),
      ),
    );
  }
  return entries;
}

/// Extrahiert die gelernten Repraesentationen aus einem availability-String.
///
/// Duplikate werden entfernt, die Reihenfolge bleibt stabil.
List<String> extractLearnedRepresentations(String availability) {
  final entries = parseSpellAvailability(availability);
  final seen = <String>{};
  final result = <String>[];
  for (final entry in entries) {
    if (seen.add(entry.learnedRepresentation)) {
      result.add(entry.learnedRepresentation);
    }
  }
  return result;
}

/// Extrahiert die Haupttraditions-Kuerzel aus einem availability-String.
///
/// Duplikate werden entfernt.
List<String> extractTraditions(String availability) {
  final entries = parseSpellAvailability(availability);
  final seen = <String>{};
  final result = <String>[];
  for (final entry in entries) {
    if (seen.add(entry.tradition)) {
      result.add(entry.tradition);
    }
  }
  return result;
}

/// Filtert Availability-Eintraege auf die Haupttraditionen des Helden.
///
/// Fuer `Dru(Elf)2` reicht also ein Held mit `Dru`, auch wenn `Elf` selbst
/// keine Helden-Repr. ist.
List<SpellAvailabilityEntry> availableSpellEntriesForRepresentations(
  String availability,
  List<String> heroRepresentations,
) {
  if (heroRepresentations.isEmpty) {
    return const [];
  }
  final entries = parseSpellAvailability(availability);
  return entries
      .where((entry) => heroRepresentations.contains(entry.tradition))
      .toList(growable: false);
}

/// Prueft, ob ein Held genau diesen Availability-Eintrag lernen darf.
bool canLearnSpellFromEntry(
  SpellAvailabilityEntry entry,
  List<String> heroRepresentations,
) {
  return heroRepresentations.contains(entry.tradition);
}

/// Sucht einen Availability-Eintrag ueber gelernte Repr. und Herkunft.
///
/// [originTradition] ist optional, sollte fuer persistierte Zauber aber
/// mitgegeben werden, damit mehrdeutige Faelle eindeutig bleiben.
SpellAvailabilityEntry? findSpellAvailabilityEntry({
  required String availability,
  required String learnedRepresentation,
  String? originTradition,
}) {
  for (final entry in parseSpellAvailability(availability)) {
    if (entry.learnedRepresentation != learnedRepresentation) {
      continue;
    }
    if (originTradition != null && entry.tradition != originTradition) {
      continue;
    }
    return entry;
  }
  return null;
}

/// Formatiert alle Verbreitungs-Eintraege fuer die Kataloganzeige.
String formatAvailabilityEntries(String availability) {
  final entries = parseSpellAvailability(availability);
  if (entries.isEmpty) {
    return '-';
  }
  return entries.map((entry) => entry.displayLabel).join('; ');
}

/// Legacy-Helfer fuer Altpfade, die noch eine einzelne Verbreitungszahl erwarten.
///
/// Neue Anzeige- und Auswahlpfade sollen stattdessen mit
/// [availableSpellEntriesForRepresentations] arbeiten.
int? spellAvailabilityForRepresentations(
  String availability,
  List<String> heroRepresentations,
) {
  final entries = availableSpellEntriesForRepresentations(
    availability,
    heroRepresentations,
  );
  int? bestVerbreitung;
  for (final entry in entries) {
    if (bestVerbreitung == null || entry.verbreitung < bestVerbreitung) {
      bestVerbreitung = entry.verbreitung;
    }
  }
  return bestVerbreitung;
}

/// Kennzeichnet eine gespeicherte Zauber-Repr. als Fremdrepr. des Eintrags.
bool isForeignSpellRepresentation({
  required String availability,
  required String learnedRepresentation,
  String? originTradition,
}) {
  final entry = findSpellAvailabilityEntry(
    availability: availability,
    learnedRepresentation: learnedRepresentation,
    originTradition: originTradition,
  );
  if (entry == null) {
    return false;
  }
  return entry.isForeignRepresentation;
}

/// Berechnet die effektive Steigerungskategorie eines Zaubers.
///
/// Hauszauber, passende Merkmalskenntnisse und Begabung summieren sich jeweils
/// um eine Reduktionsstufe. Fremdrepr. erhoeht die Basis vorher um 2 Stufen.
/// Minimum ist `A*`.
String effectiveSteigerung({
  required String basisSteigerung,
  required bool istHauszauber,
  required List<String> zauberMerkmale,
  required List<String> heldMerkmalskenntnisse,
  bool istBegabt = false,
  int fremdReprPenaltySteps = 0,
}) {
  return effectiveSpellLernkomplexitaet(
    basisKomplexitaet: basisSteigerung,
    istHauszauber: istHauszauber,
    zauberMerkmale: zauberMerkmale,
    heldMerkmalskenntnisse: heldMerkmalskenntnisse,
    gifted: istBegabt,
    penaltySteps: fremdReprPenaltySteps,
  );
}

/// Parst den Merkmale-String eines Zaubers in eine Liste.
///
/// Input: "Eigenschaften, Elementar (Erz)"
/// Output: ['Eigenschaften', 'Elementar (Erz)']
List<String> parseSpellTraits(String traits) {
  if (traits.isEmpty) {
    return const [];
  }
  return traits
      .split(',')
      .map((trait) => trait.trim())
      .where((trait) => trait.isNotEmpty)
      .toList(growable: false);
}

/// Der feste TP-Bonus des Axxeleratus auf Nahkampfangriffe.
int computeAxxeleratusTpBonus({required bool axxeleratusActive}) {
  return axxeleratusActive ? 2 : 0;
}

/// Der feste Bonus des Axxeleratus auf den Parade-Basiswert.
int computeAxxeleratusPaBaseBonus({required bool axxeleratusActive}) {
  return axxeleratusActive ? 2 : 0;
}

/// Der zusaetzliche Axxeleratus-Bonus auf Ausweichen.
///
/// Dieser Bonus kommt zusaetzlich zur indirekten Erhoehung durch den
/// verbesserten Parade-Basiswert hinzu.
int computeAxxeleratusAusweichenBonus({required bool axxeleratusActive}) {
  return axxeleratusActive ? 2 : 0;
}

/// Verdoppelt den Eigenschaftsanteil der Initiative, wenn Axxeleratus aktiv ist.
int computeAxxeleratusIniBase({
  required int iniBase,
  required bool axxeleratusActive,
}) {
  return axxeleratusActive ? iniBase * 2 : iniBase;
}

/// Liefert den Axxeleratus-Zusatz auf die Heldeninitiative.
///
/// Das ist genau der zweite Ini-Basisanteil, der bei aktivem Zauber
/// auf die normale Ini-Basis addiert wird.
int computeAxxeleratusIniBonus({
  required int iniBase,
  required bool axxeleratusActive,
}) {
  return axxeleratusActive ? iniBase : 0;
}

/// Verdoppelt den final berechneten GS-Wert des Helden.
int computeAxxeleratusGs({required int gs, required bool axxeleratusActive}) {
  return axxeleratusActive ? gs * 2 : gs;
}

/// Reiner Anzeigehinweis fuer beschleunigte Nahkampfangriffe.
String buildAxxeleratusDefenseHint({required bool axxeleratusActive}) {
  if (!axxeleratusActive) {
    return '';
  }
  return 'Abwehr des beschleunigten Nahkampfangriffs: Automatische Finte +2';
}
