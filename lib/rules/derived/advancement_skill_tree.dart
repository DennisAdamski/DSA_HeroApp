import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'advancement_options.dart';
import 'requirement_evaluation_rules.dart';
import 'special_ability_variant_rules.dart';

/// Sichtbarer Erwerbszustand, unabhängig von Farben und Layout.
enum SkillTreeStatus { owned, planned, available, blocked, review }

/// Fähigkeit oder logischer Verknüpfungspunkt im Erwerbsgraphen.
class SkillTreeNode {
  /// Hält eine stabile Identität auch beim Neuberechnen der Sitzung.
  const SkillTreeNode({required this.id, required this.label,
    required this.category, required this.status, this.option});
  final String id;
  final String label;
  final String category;
  final SkillTreeStatus status;
  final AdvancementOption? option;
}

/// Gerichtete Kante von einer Voraussetzung zu ihrem Erwerbsziel.
typedef SkillTreeEdge = ({String from, String to});

/// Vollständige Verknüpfungen mit suchbaren, zusammenhängenden Teilbäumen.
class AdvancementSkillTree {
  /// Schützt die fachlichen Verknüpfungen vor Änderungen durch die Oberfläche.
  AdvancementSkillTree(Map<String, SkillTreeNode> nodes, List<SkillTreeEdge> edges)
      : nodes = Map.unmodifiable(nodes), edges = List.unmodifiable(edges);
  final Map<String, SkillTreeNode> nodes;
  final List<SkillTreeEdge> edges;

  /// Behält bei der Suche den gesamten Zusammenhang eines Treffers sichtbar.
  List<List<String>> components({String query = '', String? category}) {
    final adjacency = <String, Set<String>>{
      for (final id in nodes.keys) id: <String>{},
    };
    for (final edge in edges) {
      adjacency[edge.from]!.add(edge.to);
      adjacency[edge.to]!.add(edge.from);
    }
    final remaining = nodes.keys.toSet();
    final result = <List<String>>[];
    while (remaining.isNotEmpty) {
      final pending = [remaining.first];
      final component = <String>[];
      while (pending.isNotEmpty) {
        final id = pending.removeLast();
        if (!remaining.remove(id)) continue;
        component.add(id);
        pending.addAll(adjacency[id]!);
      }
      final matches = component.any((id) {
        final node = nodes[id]!;
        return node.option != null &&
            (category == null || node.category == category) &&
            node.label.toLowerCase().contains(query.toLowerCase());
      });
      if (matches) result.add(component);
    }
    result.sort((a, b) => _componentName(a).compareTo(_componentName(b)));
    return result;
  }

  // Knoten ohne eigene Erwerbsoption beeinflussen die alphabetische Ordnung nicht.
  String _componentName(List<String> ids) {
    final labels = ids.map((id) => nodes[id]!).where((n) => n.option != null)
        .map((n) => n.label.toLowerCase()).toList()..sort();
    return labels.first;
  }

  /// Ordnet Vorstufen links an; zyklische Katalogbezüge enden deterministisch.
  Map<String, int> levels(List<String> ids) {
    final included = ids.toSet();
    final result = <String, int>{};
    final pending = ids.toSet();
    while (pending.isNotEmpty) {
      var progressed = false;
      for (final id in pending.toList()) {
        final parents = edges.where((e) => e.to == id && included.contains(e.from));
        if (parents.any((e) => !result.containsKey(e.from))) continue;
        var level = 0;
        for (final edge in parents) {
          final next = result[edge.from]! + 1;
          if (next > level) level = next;
        }
        result[id] = level;
        pending.remove(id);
        progressed = true;
      }
      if (!progressed) {
        // Eine Rückkante bleibt sichtbar; sie darf keine Endlosschleife erzeugen.
        final cycleRoot = pending.first;
        result[cycleRoot] = 0;
        pending.remove(cycleRoot);
      }
    }
    return result;
  }
}

/// Baut Abhängigkeiten aus den bereits ausgewerteten Katalogvoraussetzungen.
AdvancementSkillTree buildAdvancementSkillTree({
  required List<AdvancementOption> options, required Set<String> plannedTargets,
  required int availableAp,
}) {
  final nodes = <String, SkillTreeNode>{};
  final edges = <SkillTreeEdge>[];
  final abilityOptions = options.where((o) => !o.isValueAdvancement).toList();
  for (final option in abilityOptions) {
    final id = '${option.kind.name}:${option.targetId}';
    nodes[id] = SkillTreeNode(id: id, label: option.label,
      category: _category(option.kind), option: option,
      status: _status(option, plannedTargets.contains(id), availableAp));
  }
  final skills = nodes.values.toList();
  for (final skill in skills) {
    for (var i = 0; i < skill.option!.requirements.length; i++) {
      final check = skill.option!.requirements[i];
      if (!_hasSkillReference(check.requirement)) continue;
      final parent = _requirementNode(check, '${skill.id}:r$i', skill.category,
          skills, nodes, edges);
      edges.add((from: parent, to: skill.id));
    }
  }
  return AdvancementSkillTree(nodes, edges);
}

// Explizite ODER-/UND-Knoten erhalten die Verschachtelung auch bei Mischbedingungen.
String _requirementNode(RequirementCheckResult check, String id, String category,
    List<SkillTreeNode> skills, Map<String, SkillTreeNode> nodes,
    List<SkillTreeEdge> edges) {
  final requirement = check.requirement;
  final group = requirement.art == RequirementArt.oderGruppe ||
      requirement.art == RequirementArt.undGruppe;
  if (!group) {
    final matches = skills.where((node) => _matchesReference(node, requirement));
    if (matches.length == 1) return matches.single.id;
  }
  final label = group
      ? (requirement.art == RequirementArt.oderGruppe ? 'ODER' : 'UND')
      : check.sollText;
  nodes[id] = SkillTreeNode(id: id, label: label, category: category,
    status: check.istOffen ? SkillTreeStatus.blocked
        : check.status == RequirementStatus.hinweis ? SkillTreeStatus.review
        : SkillTreeStatus.available);
  for (var i = 0; i < check.teilergebnisse.length; i++) {
    final parent = _requirementNode(check.teilergebnisse[i], '$id:$i', category,
        skills, nodes, edges);
    edges.add((from: parent, to: id));
  }
  return id;
}

bool _hasSkillReference(SpecialAbilityRequirement r) =>
    r.art == RequirementArt.sonderfertigkeit || r.art == RequirementArt.manoever ||
    r.bedingungen.any(_hasSkillReference);

// Qualifizierte Fernkampfmanöver verweisen auf genau denselben Talentzweig.
bool _matchesReference(SkillTreeNode node, SpecialAbilityRequirement r) {
  final maneuver = node.option!.kind == AdvancementKind.maneuver;
  if (r.art == RequirementArt.manoever && !maneuver) return false;
  if (r.art == RequirementArt.sonderfertigkeit && maneuver) return false;
  if (r.art != RequirementArt.manoever && r.art != RequirementArt.sonderfertigkeit) {
    return false;
  }
  final names = [node.label, ...node.option!.ability!.alleNamen];
  if (r.stufe != null) {
    final stage = besessenStufeFuer(node.label, r.name);
    return stage == r.stufe || (stage == 0 && r.stufe == 1);
  }
  final needle = normalizeSpecialAbilityName(r.name);
  return names.any((name) => normalizeSpecialAbilityName(name) == needle);
}

SkillTreeStatus _status(AdvancementOption option, bool planned, int ap) {
  if (planned) return SkillTreeStatus.planned;
  if (option.isOwned) return SkillTreeStatus.owned;
  if (option.unavailableReason != null ||
      !alleVoraussetzungenErfuellt(option.requirements) ||
      (option.apCost != null && option.apCost! > ap)) {
    return SkillTreeStatus.blocked;
  }
  if (option.apCost == null ||
      option.requirements.any(_needsReview)) {
    return SkillTreeStatus.review;
  }
  return SkillTreeStatus.available;
}

bool _needsReview(RequirementCheckResult check) =>
    check.status == RequirementStatus.hinweis || check.teilergebnisse.any(_needsReview);

String _category(AdvancementKind kind) => switch (kind) {
  AdvancementKind.combatAbility || AdvancementKind.maneuver => 'Kampf',
  AdvancementKind.magicAbility => 'Magie',
  AdvancementKind.karmalAbility => 'Karma',
  _ => 'Allgemein',
};
