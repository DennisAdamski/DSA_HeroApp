/// Haelt die Aktivierungszustaende aller Kampfsonderfertigkeiten und Manoever.
///
/// Alle boolean-Felder sind standardmaessig `false`.
/// Aktive Manoever werden als deduplizierte, leerzeichen-bereinigte String-Liste
/// in [activeManeuvers] gespeichert.
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
class CombatSpecialRules {
  const CombatSpecialRules({
    this.kampfreflexe = false,
    this.kampfgespuer = false,
    this.schnellziehen = false,
    this.schnellladenBogen = false,
    this.schnellladenArmbrust = false,
    this.ausweichenI = false,
    this.ausweichenII = false,
    this.ausweichenIII = false,
    this.schildkampfI = false,
    this.schildkampfII = false,
    this.parierwaffenI = false,
    this.parierwaffenII = false,
    this.linkhandActive = false,
    this.flink = false,
    this.behaebig = false,
    this.axxeleratusActive = false,
    this.klingentaenzer = false,
    this.aufmerksamkeit = false,
    this.activeManeuvers = const <String>[],
  });

  /// Sonderfertigkeit Kampfreflexe aktiv.
  final bool kampfreflexe;

  /// Sonderfertigkeit Kampfgespuer aktiv.
  final bool kampfgespuer;

  /// Sonderfertigkeit Schnellziehen aktiv.
  final bool schnellziehen;

  /// Sonderfertigkeit Schnellladen (Bogen) aktiv.
  final bool schnellladenBogen;

  /// Sonderfertigkeit Schnellladen (Armbrust) aktiv.
  final bool schnellladenArmbrust;

  /// Ausweichen I aktiv.
  final bool ausweichenI;

  /// Ausweichen II aktiv.
  final bool ausweichenII;

  /// Ausweichen III aktiv.
  final bool ausweichenIII;

  /// Schildkampf I aktiv.
  final bool schildkampfI;

  /// Schildkampf II aktiv.
  final bool schildkampfII;

  /// Parierwaffen I aktiv.
  final bool parierwaffenI;

  /// Parierwaffen II aktiv.
  final bool parierwaffenII;

  /// Linkhand-Modus aktiv.
  final bool linkhandActive;

  /// Vorteil Flink aktiv.
  final bool flink;

  /// Nachteil Behäebig aktiv.
  final bool behaebig;

  /// Axxeleratus-Zauber aktiv.
  ///
  /// Verdoppelt den Ini-Basisanteil und den finalen GS-Wert
  /// und gewaehrt weitere kampfbezogene Boni.
  final bool axxeleratusActive;

  /// Klingentaenzer: wirft 2W6 statt 1W6 auf Initiative.
  final bool klingentaenzer;

  /// Aufmerksamkeit: ersetzt 1W6/2W6-Anzeige durch +6/+12 in der Uebersicht.
  final bool aufmerksamkeit;

  /// Liste der aktuell aktiven Manoever-IDs (dedupliziert, kein Leerstring).
  final List<String> activeManeuvers;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ///
  /// [activeManeuvers] wird automatisch dedupliziert und bereinigt.
  CombatSpecialRules copyWith({
    bool? kampfreflexe,
    bool? kampfgespuer,
    bool? schnellziehen,
    bool? schnellladenBogen,
    bool? schnellladenArmbrust,
    bool? ausweichenI,
    bool? ausweichenII,
    bool? ausweichenIII,
    bool? schildkampfI,
    bool? schildkampfII,
    bool? parierwaffenI,
    bool? parierwaffenII,
    bool? linkhandActive,
    bool? flink,
    bool? behaebig,
    bool? axxeleratusActive,
    bool? klingentaenzer,
    bool? aufmerksamkeit,
    List<String>? activeManeuvers,
  }) {
    return CombatSpecialRules(
      kampfreflexe: kampfreflexe ?? this.kampfreflexe,
      kampfgespuer: kampfgespuer ?? this.kampfgespuer,
      schnellziehen: schnellziehen ?? this.schnellziehen,
      schnellladenBogen: schnellladenBogen ?? this.schnellladenBogen,
      schnellladenArmbrust: schnellladenArmbrust ?? this.schnellladenArmbrust,
      ausweichenI: ausweichenI ?? this.ausweichenI,
      ausweichenII: ausweichenII ?? this.ausweichenII,
      ausweichenIII: ausweichenIII ?? this.ausweichenIII,
      schildkampfI: schildkampfI ?? this.schildkampfI,
      schildkampfII: schildkampfII ?? this.schildkampfII,
      parierwaffenI: parierwaffenI ?? this.parierwaffenI,
      parierwaffenII: parierwaffenII ?? this.parierwaffenII,
      linkhandActive: linkhandActive ?? this.linkhandActive,
      flink: flink ?? this.flink,
      behaebig: behaebig ?? this.behaebig,
      axxeleratusActive: axxeleratusActive ?? this.axxeleratusActive,
      klingentaenzer: klingentaenzer ?? this.klingentaenzer,
      aufmerksamkeit: aufmerksamkeit ?? this.aufmerksamkeit,
      activeManeuvers: _normalizeStringList(
        activeManeuvers ?? this.activeManeuvers,
      ),
    );
  }

  /// Serialisiert die Sonderfertigkeiten zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'kampfreflexe': kampfreflexe,
      'kampfgespuer': kampfgespuer,
      'schnellziehen': schnellziehen,
      'schnellladenBogen': schnellladenBogen,
      'schnellladenArmbrust': schnellladenArmbrust,
      'ausweichenI': ausweichenI,
      'ausweichenII': ausweichenII,
      'ausweichenIII': ausweichenIII,
      'schildkampfI': schildkampfI,
      'schildkampfII': schildkampfII,
      'parierwaffenI': parierwaffenI,
      'parierwaffenII': parierwaffenII,
      'linkhandActive': linkhandActive,
      'flink': flink,
      'behaebig': behaebig,
      'axxeleratusActive': axxeleratusActive,
      'klingentaenzer': klingentaenzer,
      'aufmerksamkeit': aufmerksamkeit,
      'activeManeuvers': _normalizeStringList(activeManeuvers),
    };
  }

  /// Deserialisiert [CombatSpecialRules] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwerte werden gesetzt).
  static CombatSpecialRules fromJson(Map<String, dynamic> json) {
    bool getBool(String key) => (json[key] as bool?) ?? false;
    return CombatSpecialRules(
      kampfreflexe: getBool('kampfreflexe'),
      kampfgespuer: getBool('kampfgespuer'),
      schnellziehen: getBool('schnellziehen'),
      schnellladenBogen: getBool('schnellladenBogen'),
      schnellladenArmbrust: getBool('schnellladenArmbrust'),
      ausweichenI: getBool('ausweichenI'),
      ausweichenII: getBool('ausweichenII'),
      ausweichenIII: getBool('ausweichenIII'),
      schildkampfI: getBool('schildkampfI'),
      schildkampfII: getBool('schildkampfII'),
      parierwaffenI: getBool('parierwaffenI'),
      parierwaffenII: getBool('parierwaffenII'),
      linkhandActive: getBool('linkhandActive'),
      flink: getBool('flink'),
      behaebig: getBool('behaebig'),
      axxeleratusActive: getBool('axxeleratusActive'),
      klingentaenzer: getBool('klingentaenzer'),
      aufmerksamkeit: getBool('aufmerksamkeit'),
      activeManeuvers: _normalizeStringList(
        (json['activeManeuvers'] as List?) ?? const <dynamic>[],
      ),
    );
  }
}

/// Bereinigt und dedupliziert eine Liste von Manoever-IDs.
///
/// Entfernt Leerstrings, fuehrende/nachfolgende Leerzeichen und Duplikate.
/// Gibt eine unveraenderliche Liste zurueck.
List<String> _normalizeStringList(Iterable<dynamic> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final text = value.toString().trim();
    if (text.isEmpty || seen.contains(text)) {
      continue;
    }
    seen.add(text);
    normalized.add(text);
  }
  return List<String>.unmodifiable(normalized);
}
