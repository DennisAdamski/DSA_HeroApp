/// Ein offener Zeitpunkt der gemeinsamen flüchtigen Runde.
class Gefechtszeitpunkt {
  /// Ursprungs-INI entscheidet Konkurrenz mit einer verzögerten Aktion.
  const Gefechtszeitpunkt({
    required this.id,
    required this.teilnehmerId,
    required this.name,
    required this.ini,
    required this.ursprungsIni,
    this.umgewandelt = false,
    this.reserve = false,
    this.gegner = false,
  });
  final String id, teilnehmerId, name;
  final int ini, ursprungsIni;
  final bool umgewandelt, reserve, gegner;
}

/// Ausdrücklich verbundene Helden und abgeschlossene Zeitpunkte einer Runde.
class Gefechtsinitiative {
  /// Ohne verbundene Helden bleiben bestehende Einzelgefechte unverändert.
  const Gefechtsinitiative({
    this.helden = const {},
    this.erledigt = const {},
    this.runde = 1,
    this.phase,
  });
  final Set<String> helden, erledigt;
  final int runde;
  final int? phase;

  /// Erhält die Gruppe bei frischen Phasen- und Rundenänderungen.
  Gefechtsinitiative copyWith({
    Set<String>? helden,
    Set<String>? erledigt,
    int? runde,
    int? phase,
    bool ohnePhase = false,
  }) => Gefechtsinitiative(
    helden: helden ?? this.helden,
    erledigt: erledigt ?? this.erledigt,
    runde: runde ?? this.runde,
    phase: ohnePhase ? null : phase ?? this.phase,
  );
}
