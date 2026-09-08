import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_layout.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';
import 'package:dsa_heldenverwaltung/ui/screens/skill_tree/skill_tree_edges_painter.dart';
import 'package:dsa_heldenverwaltung/ui/screens/skill_tree/skill_tree_node_card.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Zoom-/verschiebbare Graph-Darstellung eines bewerteten Skilltrees.
class SkillTreeGraphView extends StatelessWidget {
  const SkillTreeGraphView({
    super.key,
    required this.view,
    required this.onNodeTap,
  });

  final SkillTreeView view;
  final void Function(EvaluatedNode evaluated) onNodeTap;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final layout = layoutGraph(view.graph);

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(240),
      minScale: 0.3,
      maxScale: 2.5,
      child: SizedBox(
        width: layout.size.width,
        height: layout.size.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SkillTreeEdgesPainter(
                  edges: view.graph.edges,
                  layout: layout,
                  color: codex.brassMuted,
                  alternativeColor: codex.inkMuted,
                ),
              ),
            ),
            for (final entry in layout.positions.entries)
              if (view.evaluated[entry.key] != null)
                Positioned(
                  left: entry.value.dx,
                  top: entry.value.dy,
                  child: SkillTreeNodeCard(
                    evaluated: view.evaluated[entry.key]!,
                    width: layout.nodeWidth,
                    height: layout.nodeHeight,
                    subtitle: _subtitleFor(view.evaluated[entry.key]!),
                    onTap: () => onNodeTap(view.evaluated[entry.key]!),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(EvaluatedNode evaluated) {
    final cost = evaluated.node.apCost;
    if (evaluated.node.isSpecialAbility && cost != null) {
      return '$cost AP';
    }
    return '';
  }
}
