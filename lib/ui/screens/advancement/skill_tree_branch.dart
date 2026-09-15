import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_skill_tree.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

const _nodeWidth = 216.0;
const _nodeHeight = 112.0;
const _columnGap = 64.0;
const _rowGap = 18.0;

/// Ein zusammenhängender Skilltree-Zweig mit lesbaren Knoten und gerichteten Linien.
class SkillTreeBranch extends StatelessWidget {
  /// Erhält bereits bestimmte Zusammenhänge; Layout enthält keine Erwerbsregeln.
  const SkillTreeBranch({super.key, required this.graph, required this.ids,
    required this.onSelect});
  final AdvancementSkillTree graph;
  final List<String> ids;
  final ValueChanged<SkillTreeNode>? onSelect;

  /// Ordnet Stufen links nach rechts an und hält Text in Originalgröße lesbar.
  @override
  Widget build(BuildContext context) {
    final levels = graph.levels(ids);
    final columns = <int, List<String>>{};
    for (final id in ids) { columns.putIfAbsent(levels[id]!, () => []).add(id); }
    final positions = <String, Offset>{};
    var rowCount = 1;
    for (final entry in columns.entries) {
      entry.value.sort((a,b) => graph.nodes[a]!.label.compareTo(graph.nodes[b]!.label));
      rowCount = math.max(rowCount, entry.value.length);
      for (var row = 0; row < entry.value.length; row++) {
        positions[entry.value[row]] = Offset(12 + entry.key * (_nodeWidth + _columnGap),
            12 + row * (_nodeHeight + _rowGap));
      }
    }
    final maxLevel = levels.values.reduce(math.max);
    final size = Size(24 + (maxLevel + 1) * _nodeWidth + maxLevel * _columnGap,
        24 + rowCount * _nodeHeight + (rowCount - 1) * _rowGap);
    final colors = context.codexTheme;
    return DecoratedBox(decoration: BoxDecoration(color: colors.parchmentStrong,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.rule)),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: SizedBox.fromSize(size: size, child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _ConnectionsPainter(
            graph: graph, positions: positions, color: colors.brass))),
          for (final id in ids)
            Positioned(left: positions[id]!.dx, top: positions[id]!.dy,
              width: _nodeWidth, height: _nodeHeight,
              child: _Node(node: graph.nodes[id]!, onSelect: onSelect)),
        ])),
      ));
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.node, required this.onSelect});
  final SkillTreeNode node;
  final ValueChanged<SkillTreeNode>? onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.codexTheme;
    final color = _statusColor(context, node.status);
    final option = node.option;
    final gate = option == null;
    final icon = gate ? Icons.call_merge
        : option.kind == AdvancementKind.maneuver ? Icons.sports_martial_arts
        : Icons.auto_awesome;
    return Semantics(button: !gate, label: node.label,
      child: Material(color: colors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(gate ? 24 : 8),
          side: BorderSide(color: color, width: node.status == SkillTreeStatus.planned ? 2 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(key: ValueKey('skill-node-${node.id}'),
          onTap: gate || onSelect == null ? null : () => onSelect!(node),
          child: Padding(padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 18, color: color), const SizedBox(width: 6),
                Expanded(child: Tooltip(message: node.label, child: Text(node.label,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall))),
              ]),
              const Spacer(),
              if (option != null)
                Text(option.apCost == null ? 'AP nach Auswahl'
                    : '${option.apCost} AP', style: Theme.of(context).textTheme.bodySmall),
              SkillTreeStatusLabel(status: node.status),
            ])),
        )));
  }
}

/// Text und Symbol vermitteln den Status auch ohne Farbwahrnehmung.
class SkillTreeStatusLabel extends StatelessWidget {
  /// Zeigt den fachlichen Status eines Knotens oder eines Legendeneintrags.
  const SkillTreeStatusLabel({super.key, required this.status});
  final SkillTreeStatus status;

  /// Nutzt dieselben Statusfarben wie die Knotenrahmen.
  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      SkillTreeStatus.owned => ('Erworben', Icons.check_circle_outline),
      SkillTreeStatus.planned => ('Geplant', Icons.schedule),
      SkillTreeStatus.available => ('Erlernbar', Icons.add_circle_outline),
      SkillTreeStatus.blocked => ('Gesperrt', Icons.lock_outline),
      SkillTreeStatus.review => ('Prüfen', Icons.help_outline),
    };
    final color = _statusColor(context, status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color), const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
    ]);
  }
}

Color _statusColor(BuildContext context, SkillTreeStatus status) {
  final colors = context.codexTheme;
  return switch (status) {
    SkillTreeStatus.owned => colors.success,
    SkillTreeStatus.planned => colors.accent,
    SkillTreeStatus.available => colors.brass,
    SkillTreeStatus.blocked => colors.inkMuted,
    SkillTreeStatus.review => colors.warning,
  };
}

class _ConnectionsPainter extends CustomPainter {
  _ConnectionsPainter({required this.graph, required this.positions, required this.color});
  final AdvancementSkillTree graph;
  final Map<String, Offset> positions;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (final edge in graph.edges) {
      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from == null || to == null) continue;
      final start = from + const Offset(_nodeWidth, _nodeHeight / 2);
      final end = to + const Offset(0, _nodeHeight / 2);
      final path = Path()..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx + 32, start.dy, end.dx - 32, end.dy, end.dx, end.dy);
      canvas.drawPath(path, paint);
      canvas.drawPath(Path()..moveTo(end.dx - 7, end.dy - 4)
        ..lineTo(end.dx, end.dy)..lineTo(end.dx - 7, end.dy + 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionsPainter oldDelegate) =>
      graph != oldDelegate.graph || positions != oldDelegate.positions || color != oldDelegate.color;
}
