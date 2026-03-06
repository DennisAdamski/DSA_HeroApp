// Magie-Regelfunktionen (pure Dart, keine Seiteneffekte).
//
// Enthält Logik fuer:
// - Parsing von Zauber-Verfuegbarkeits-Strings
// - Filterung nach Held-Repraesentationen
// - Berechnung der effektiven Steigerungskategorie

/// Ein einzelner Eintrag in der Verfuegbarkeitsliste eines Zaubers.
///
/// Beispiel: "Mag6" → tradition='Mag', subTradition=null, verbreitung=6
/// Beispiel: "Dru(Elf)2" → tradition='Dru', subTradition='Elf', verbreitung=2
class SpellAvailabilityEntry {
  const SpellAvailabilityEntry({
    required this.tradition,
    this.subTradition,
    required this.verbreitung,
  });

  final String tradition;
  final String? subTradition;
  final int verbreitung;
}

/// Regex zum Parsen einzelner Verfuegbarkeits-Tokens.
///
/// Erkennt Formate wie: "Mag6", "Dru(Elf)2", "Hex(Mag)3"
final RegExp _availabilityPattern = RegExp(
  r'([A-Za-zÄÖÜäöü]+)(?:\(([A-Za-zÄÖÜäöü]+)\))?(\d+)',
);

/// Parst den availability-String eines Zaubers in strukturierte Eintraege.
///
/// Input: "Mag6, Hex3, Dru(Elf)2"
/// Output: [SpellAvailabilityEntry('Mag', null, 6), ...]
List<SpellAvailabilityEntry> parseSpellAvailability(String availability) {
  if (availability.isEmpty) return const [];
  final entries = <SpellAvailabilityEntry>[];
  for (final part in availability.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final match = _availabilityPattern.firstMatch(trimmed);
    if (match == null) continue;
    entries.add(
      SpellAvailabilityEntry(
        tradition: match.group(1)!,
        subTradition: match.group(2),
        verbreitung: int.parse(match.group(3)!),
      ),
    );
  }
  return entries;
}

/// Extrahiert die Traditions-Kuerzel aus einem availability-String.
///
/// Gibt nur die Haupttradition jedes Eintrags zurueck (z.B. "Mag", "Hex").
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

/// Prueft, ob ein Zauber fuer die gewaehlten Repraesentationen verfuegbar ist.
///
/// Gibt die beste (niedrigste) Verbreitungsstufe zurueck oder null,
/// wenn der Zauber nicht verfuegbar ist.
///
/// Beruecksichtigt auch Sub-Traditionen: "Dru(Elf)2" passt, wenn der Held
/// sowohl "Dru" als auch "Elf" als Repraesentation hat.
int? spellAvailabilityForRepresentations(
  String availability,
  List<String> heroRepresentations,
) {
  if (heroRepresentations.isEmpty) return null;
  final entries = parseSpellAvailability(availability);
  int? bestVerbreitung;
  for (final entry in entries) {
    final matchesTradition = heroRepresentations.contains(entry.tradition);
    if (!matchesTradition) continue;
    // Sub-Tradition: Held muss auch die Zweit-Repraesentation haben.
    if (entry.subTradition != null &&
        !heroRepresentations.contains(entry.subTradition)) {
      continue;
    }
    if (bestVerbreitung == null || entry.verbreitung < bestVerbreitung) {
      bestVerbreitung = entry.verbreitung;
    }
  }
  return bestVerbreitung;
}

/// Die sechs DSA-Steigerungskategorien in aufsteigender Reihenfolge.
const List<String> _steigerungsKategorien = ['A', 'B', 'C', 'D', 'E', 'F'];

/// Berechnet die effektive Steigerungskategorie eines Zaubers.
///
/// Die Kategorie wird um eine Stufe reduziert (z.B. C → B) wenn:
/// - der Zauber als Hauszauber markiert ist, ODER
/// - der Held Merkmalskenntnisse besitzt, die mindestens ein Merkmal
///   des Zaubers abdecken.
///
/// Hauszauber und Merkmalskenntnisse werden NICHT kumuliert —
/// die maximale Reduktion betraegt eine Stufe.
/// Minimum ist 'A', Maximum ist 'F'.
String effectiveSteigerung({
  required String basisSteigerung,
  required bool istHauszauber,
  required List<String> zauberMerkmale,
  required List<String> heldMerkmalskenntnisse,
}) {
  final index = _steigerungsKategorien.indexOf(basisSteigerung);
  if (index < 0) return basisSteigerung;

  final hatMerkmalReduktion = zauberMerkmale.any(
    (merkmal) => heldMerkmalskenntnisse.contains(merkmal),
  );

  if (istHauszauber || hatMerkmalReduktion) {
    final reducedIndex = (index - 1).clamp(
      0,
      _steigerungsKategorien.length - 1,
    );
    return _steigerungsKategorien[reducedIndex];
  }
  return basisSteigerung;
}

/// Parst den Merkmale-String eines Zaubers in eine Liste.
///
/// Input: "Eigenschaften, Elementar (Erz)"
/// Output: ['Eigenschaften', 'Elementar (Erz)']
List<String> parseSpellTraits(String traits) {
  if (traits.isEmpty) return const [];
  return traits
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
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
