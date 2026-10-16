import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_skill_tree.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';

import 'skill_tree_branch.dart';

/// Kompakte Kachel für eine Fähigkeit ohne Vor- oder Nachstufe.
///
/// Statt einer vollen Zeile mit 216×112-Knoten liegen solche Einträge in einem
/// Raster; Tippen öffnet dieselben Erwerbsdetails wie ein Baumknoten.
class SkillTreeChip extends StatelessWidget {
  /// Zeigt Name, Kosten und Status eines freistehenden Knotens.
  const SkillTreeChip({super.key, required this.node, required this.onSelect});

  /// Breite einer Kachel; schmale Fenster strecken sie auf die Zeilenbreite.
  static const breite = 216.0;

  final SkillTreeNode node;
  final ValueChanged<SkillTreeNode>? onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.codexTheme;
    final theme = Theme.of(context);
    final color = skillTreeStatusFarbe(context, node.status);
    final option = node.option!;
    final icon = option.kind == AdvancementKind.maneuver
        ? Icons.sports_martial_arts
        : Icons.auto_awesome;
    final kosten = option.apCost == null
        ? 'AP nach Auswahl'
        : '${option.apCost} AP';
    return Semantics(
      button: true,
      label: node.label,
      child: Material(
        color: colors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kartoRadiusOder(context, 8)),
          side: BorderSide(
            color: color,
            width: node.status == SkillTreeStatus.planned ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('skill-node-${node.id}'),
          onTap: onSelect == null ? null : () => onSelect!(node),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Tooltip(
                        message: node.label,
                        child: Text(
                          node.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SkillTreeStatusLabel(status: node.status),
                    Text(kosten, style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
