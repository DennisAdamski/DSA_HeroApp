/// Modelle fuer den Sonderfertigkeiten-Skilltree.
///
/// Bewusst reine Dart-Datenklassen ohne Flutter-Abhaengigkeit, damit die
/// Parser-, Graph- und Bewertungslogik vollstaendig unit-testbar bleibt.
library;

/// Art eines Knotens im Skilltree.
enum SkillNodeKind {
  /// Kampf-Sonderfertigkeit (aus `combatSpecialAbilities`).
  combatSf,

  /// Magische Sonderfertigkeit (aus `magicSpecialAbilities`).
  magicSf,

  /// Standard-Talent/Kampftechnik, die als Voraussetzung dient.
  talent,

  /// Zauber, der als Voraussetzung dient.
  spell,
}

/// Zustand eines Knotens bezogen auf einen konkreten Helden.
enum SkillNodeState {
  /// Bereits gelernt bzw. (bei Talent/Zauber) Mindestwert erreicht.
  learned,

  /// Alle (auswertbaren) Voraussetzungen erfuellt, keine offenen Unklarheiten.
  learnable,

  /// Mindestens eine auswertbare Voraussetzung ist nicht erfuellt.
  locked,

  /// Voraussetzungen erfuellt, aber es bleiben nicht auswertbare Reste.
  unknownRequirements,
}

/// Welche Sonderfertigkeitskategorie ein Baum darstellt.
enum SkillTreeCategory { combat, magic }

/// Eine geparste Einzelvoraussetzung einer Sonderfertigkeit.
sealed class SkillRequirement {
  const SkillRequirement();
}

/// Verweis auf eine andere Sonderfertigkeit (z. B. „SF Ausweichen I“).
class AbilityRequirement extends SkillRequirement {
  const AbilityRequirement(this.name);

  /// Anzeigename inkl. Stufe (z. B. „Ausweichen II“).
  final String name;

  @override
  bool operator ==(Object other) =>
      other is AbilityRequirement && other.name == name;

  @override
  int get hashCode => Object.hash('ability', name);

  @override
  String toString() => 'AbilityRequirement($name)';
}

/// Mindest-Talentwert (TaW) eines Standard-/Kampftalents.
class TalentRequirement extends SkillRequirement {
  const TalentRequirement(this.name, this.minTaW);

  final String name;
  final int minTaW;

  @override
  bool operator ==(Object other) =>
      other is TalentRequirement && other.name == name && other.minTaW == minTaW;

  @override
  int get hashCode => Object.hash('talent', name, minTaW);

  @override
  String toString() => 'TalentRequirement($name, $minTaW)';
}

/// Mindest-Zauberfertigkeitswert (ZfW) eines Zaubers.
class SpellRequirement extends SkillRequirement {
  const SpellRequirement(this.name, this.minZfW);

  final String name;
  final int minZfW;

  @override
  bool operator ==(Object other) =>
      other is SpellRequirement && other.name == name && other.minZfW == minZfW;

  @override
  int get hashCode => Object.hash('spell', name, minZfW);

  @override
  String toString() => 'SpellRequirement($name, $minZfW)';
}

/// Mindestwert einer Grundeigenschaft.
class AttributeRequirement extends SkillRequirement {
  const AttributeRequirement(this.attribute, this.min);

  /// Kleingeschriebener interner Schluessel: mu, kl, inn, ch, ff, ge, ko, kk.
  final String attribute;
  final int min;

  @override
  bool operator ==(Object other) =>
      other is AttributeRequirement &&
      other.attribute == attribute &&
      other.min == min;

  @override
  int get hashCode => Object.hash('attribute', attribute, min);

  @override
  String toString() => 'AttributeRequirement($attribute, $min)';
}

/// Voraussetzung eines Vorteils (z. B. „Vorteil Beidhändig“).
class TraitRequirement extends SkillRequirement {
  const TraitRequirement(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      other is TraitRequirement && other.name == name;

  @override
  int get hashCode => Object.hash('trait', name);

  @override
  String toString() => 'TraitRequirement($name)';
}

/// Rassenvoraussetzung (z. B. „Rasse Achaz“).
class RaceRequirement extends SkillRequirement {
  const RaceRequirement(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      other is RaceRequirement && other.name == name;

  @override
  int get hashCode => Object.hash('race', name);

  @override
  String toString() => 'RaceRequirement($name)';
}

/// Oder-Verknuepfung mehrerer Alternativvoraussetzungen.
class OrRequirement extends SkillRequirement {
  const OrRequirement(this.options);

  final List<SkillRequirement> options;

  @override
  bool operator ==(Object other) {
    if (other is! OrRequirement) return false;
    if (other.options.length != options.length) return false;
    for (var i = 0; i < options.length; i++) {
      if (other.options[i] != options[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash('or', Object.hashAll(options));

  @override
  String toString() => 'OrRequirement($options)';
}

/// Nicht maschinell auswertbarer Rest (Prosa, Sonderregeln).
class UnknownRequirement extends SkillRequirement {
  const UnknownRequirement(this.rawText);

  final String rawText;

  @override
  bool operator ==(Object other) =>
      other is UnknownRequirement && other.rawText == rawText;

  @override
  int get hashCode => Object.hash('unknown', rawText);

  @override
  String toString() => 'UnknownRequirement($rawText)';
}

/// Ein Knoten im Skilltree.
class SkillNode {
  const SkillNode({
    required this.id,
    required this.name,
    required this.kind,
    this.requirements = const <SkillRequirement>[],
    this.apCost,
    this.voraussetzungenRaw = '',
    this.kostenRaw = '',
    this.beschreibung = '',
    this.nurEpisch = false,
  });

  /// Stabile ID (SF-Katalog-ID bzw. Talent-/Zauber-ID).
  final String id;
  final String name;
  final SkillNodeKind kind;

  /// Geparste Voraussetzungen (inkl. nicht aufloesbarer Reste).
  final List<SkillRequirement> requirements;

  /// Aus dem `kosten`-Freitext geparste AP-Kosten (null = unbekannt).
  final int? apCost;

  final String voraussetzungenRaw;
  final String kostenRaw;
  final String beschreibung;
  final bool nurEpisch;

  /// Ob es sich um eine Sonderfertigkeit (lernbar) handelt.
  bool get isSpecialAbility =>
      kind == SkillNodeKind.combatSf || kind == SkillNodeKind.magicSf;
}

/// Gerichtete Kante: [fromId] ist Voraussetzung fuer [toId].
class SkillEdge {
  const SkillEdge({
    required this.fromId,
    required this.toId,
    this.isAlternative = false,
  });

  final String fromId;
  final String toId;

  /// Teil einer Oder-Verknuepfung (alternative Voraussetzung).
  final bool isAlternative;

  @override
  bool operator ==(Object other) =>
      other is SkillEdge &&
      other.fromId == fromId &&
      other.toId == toId &&
      other.isAlternative == isAlternative;

  @override
  int get hashCode => Object.hash(fromId, toId, isAlternative);

  @override
  String toString() => 'SkillEdge($fromId -> $toId, alt: $isAlternative)';
}

/// Vollstaendiger, helden-unabhaengiger Abhaengigkeitsgraph einer Kategorie.
class SkillGraph {
  const SkillGraph({
    required this.nodes,
    required this.edges,
    required this.rootIds,
  });

  /// Knoten nach ID.
  final Map<String, SkillNode> nodes;

  /// Alle Kanten.
  final List<SkillEdge> edges;

  /// Knoten ohne eingehende Kanten (Wurzeln des Baums).
  final List<String> rootIds;

  /// Kanten, die von [id] ausgehen (Knoten, fuer die [id] Voraussetzung ist).
  Iterable<SkillEdge> outgoing(String id) =>
      edges.where((edge) => edge.fromId == id);

  /// Kanten, die in [id] eingehen (Voraussetzungen von [id]).
  Iterable<SkillEdge> incoming(String id) =>
      edges.where((edge) => edge.toId == id);
}

/// Ein Knoten samt heldenbezogenem Zustand.
class EvaluatedNode {
  const EvaluatedNode({
    required this.node,
    required this.state,
    this.unmetRequirements = const <SkillRequirement>[],
    this.canAfford = false,
  });

  final SkillNode node;
  final SkillNodeState state;

  /// Nicht erfuellte (auswertbare) Voraussetzungen.
  final List<SkillRequirement> unmetRequirements;

  /// Ob die geparsten AP-Kosten aus den verfuegbaren AP bezahlbar sind.
  final bool canAfford;
}

/// Bewerteter Baum fuer einen konkreten Helden.
class SkillTreeView {
  const SkillTreeView({
    required this.graph,
    required this.evaluated,
    required this.category,
  });

  final SkillGraph graph;
  final Map<String, EvaluatedNode> evaluated;
  final SkillTreeCategory category;
}
