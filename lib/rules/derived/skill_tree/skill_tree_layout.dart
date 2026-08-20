import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';

/// Ordnet jedem Knoten eine Schicht (Tier) zu.
///
/// Tier 0 = Wurzeln (keine eingehenden Kanten). Sonst ist das Tier der
/// laengste Pfad von einer Wurzel. Zyklen werden defensiv abgefangen.
Map<String, int> computeTiers(SkillGraph graph) {
  final memo = <String, int>{};
  final visiting = <String>{};

  int tierOf(String id) {
    final cached = memo[id];
    if (cached != null) return cached;
    if (!visiting.add(id)) {
      // Zyklus: defensiv mit 0 abbrechen.
      return 0;
    }
    var tier = 0;
    for (final edge in graph.incoming(id)) {
      if (graph.nodes.containsKey(edge.fromId)) {
        tier = math.max(tier, tierOf(edge.fromId) + 1);
      }
    }
    visiting.remove(id);
    memo[id] = tier;
    return tier;
  }

  for (final id in graph.nodes.keys) {
    tierOf(id);
  }
  return memo;
}

/// Ergebnis eines Schichten-Layouts.
class SkillTreeLayout {
  const SkillTreeLayout({
    required this.positions,
    required this.size,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  /// Linke obere Ecke je Knoten-ID.
  final Map<String, Offset> positions;

  /// Gesamtgroesse der Zeichenflaeche.
  final Size size;

  final double nodeWidth;
  final double nodeHeight;

  /// Mittelpunkt eines Knotens (fuer Kanten-Anker).
  Offset center(String id) {
    final pos = positions[id];
    if (pos == null) return Offset.zero;
    return Offset(pos.dx + nodeWidth / 2, pos.dy + nodeHeight / 2);
  }
}

/// Berechnet ein deterministisches Schichten-Layout (Tiers von links nach
/// rechts; innerhalb eines Tiers stabil nach Name sortiert).
SkillTreeLayout layoutGraph(
  SkillGraph graph, {
  double nodeWidth = 176,
  double nodeHeight = 72,
  double horizontalGap = 64,
  double verticalGap = 24,
  double padding = 24,
}) {
  final tiers = computeTiers(graph);

  // Knoten je Tier sammeln, stabil nach Name sortieren.
  final byTier = <int, List<String>>{};
  for (final entry in tiers.entries) {
    byTier.putIfAbsent(entry.value, () => <String>[]).add(entry.key);
  }
  for (final list in byTier.values) {
    list.sort((a, b) {
      final nameA = graph.nodes[a]?.name ?? a;
      final nameB = graph.nodes[b]?.name ?? b;
      final byName = nameA.toLowerCase().compareTo(nameB.toLowerCase());
      return byName != 0 ? byName : a.compareTo(b);
    });
  }

  final positions = <String, Offset>{};
  var maxTier = 0;
  var maxRows = 0;
  for (final entry in byTier.entries) {
    final tier = entry.key;
    maxTier = math.max(maxTier, tier);
    maxRows = math.max(maxRows, entry.value.length);
    for (var row = 0; row < entry.value.length; row++) {
      final id = entry.value[row];
      positions[id] = Offset(
        padding + tier * (nodeWidth + horizontalGap),
        padding + row * (nodeHeight + verticalGap),
      );
    }
  }

  final width = padding * 2 + (maxTier + 1) * nodeWidth + maxTier * horizontalGap;
  final height =
      padding * 2 + maxRows * nodeHeight + math.max(0, maxRows - 1) * verticalGap;

  return SkillTreeLayout(
    positions: positions,
    size: Size(width, height),
    nodeWidth: nodeWidth,
    nodeHeight: nodeHeight,
  );
}
