/// Kuratierte Korrekturen fuer den Skilltree.
///
/// Der `voraussetzungen`-Freitext ist heterogen; einige Sonderfertigkeiten
/// lassen sich nicht zuverlaessig parsen (generische „zugehoerige Kampftechnik“,
/// „oder“-Grossmeisterketten, Merkmalskenntnis-Magie). Diese Map ergaenzt oder
/// korrigiert die automatisch ermittelten Kanten/Kosten gezielt pro SF-ID.
///
/// Bewusst als Dart-Konstante gehalten (kein zusaetzlicher `pubspec`-Asset-
/// Eintrag noetig) — kann spaeter nach JSON wandern.
class SkillTreeOverride {
  const SkillTreeOverride({
    this.extraPrerequisiteIds = const <String>[],
    this.removePrerequisiteNames = const <String>[],
    this.apCostOverride,
    this.tierHint,
    this.ignore = false,
  });

  /// Zusaetzliche Voraussetzungs-Knoten (IDs von SF/Talenten/Zaubern),
  /// die als Kante ergaenzt werden sollen.
  final List<String> extraPrerequisiteIds;

  /// Geparste Voraussetzungsnamen (case-insensitiv), die entfernt werden.
  final List<String> removePrerequisiteNames;

  /// Erzwingt feste AP-Kosten (statt des geparsten Werts).
  final int? apCostOverride;

  /// Optionaler Tier-Hinweis fuer das Layout.
  final int? tierHint;

  /// Blendet den Knoten vollstaendig aus.
  final bool ignore;
}

/// Override-Tabelle: SF-ID → Korrektur. Initial leer; gezielt befuellbar.
const Map<String, SkillTreeOverride> skillTreeOverrides = <String, SkillTreeOverride>{
  // Beispiel (auskommentiert):
  // 'eksf_grossmeister_xyz': SkillTreeOverride(
  //   extraPrerequisiteIds: ['ksf_waffenmeister_schild'],
  //   apCostOverride: 1000,
  // ),
};
