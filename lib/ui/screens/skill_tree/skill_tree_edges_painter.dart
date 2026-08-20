import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_layout.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';

/// Zeichnet die Abhaengigkeitskanten zwischen den Knoten als Bezier-Kurven.
class SkillTreeEdgesPainter extends CustomPainter {
  SkillTreeEdgesPainter({
    required this.edges,
    required this.layout,
    required this.color,
    required this.alternativeColor,
  });

  final List<SkillEdge> edges;
  final SkillTreeLayout layout;
  final Color color;
  final Color alternativeColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final from = layout.positions[edge.fromId];
      final to = layout.positions[edge.toId];
      if (from == null || to == null) continue;

      // Anker: rechte Mitte des Voraussetzungs-Knotens → linke Mitte des Ziels.
      final start = Offset(
        from.dx + layout.nodeWidth,
        from.dy + layout.nodeHeight / 2,
      );
      final end = Offset(to.dx, to.dy + layout.nodeHeight / 2);

      final paint = Paint()
        ..color = edge.isAlternative ? alternativeColor : color
        ..strokeWidth = edge.isAlternative ? 1.4 : 1.8
        ..style = PaintingStyle.stroke;

      final dx = (end.dx - start.dx).abs().clamp(40.0, 240.0);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + dx * 0.5,
          start.dy,
          end.dx - dx * 0.5,
          end.dy,
          end.dx,
          end.dy,
        );

      if (edge.isAlternative) {
        _drawDashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkillTreeEdgesPainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.layout != layout ||
        oldDelegate.color != color ||
        oldDelegate.alternativeColor != alternativeColor;
  }
}
