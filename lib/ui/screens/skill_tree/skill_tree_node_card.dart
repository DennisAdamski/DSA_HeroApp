import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Liefert die Codex-Farbe fuer einen Knotenzustand.
Color skillNodeStateColor(CodexTheme codex, SkillNodeState state) {
  switch (state) {
    case SkillNodeState.learned:
      return codex.success;
    case SkillNodeState.learnable:
      return codex.accent;
    case SkillNodeState.unknownRequirements:
      return codex.warning;
    case SkillNodeState.locked:
      return codex.inkMuted;
  }
}

/// Kurzbeschriftung eines Knotenzustands.
String skillNodeStateLabel(SkillNodeState state) {
  switch (state) {
    case SkillNodeState.learned:
      return 'Gelernt';
    case SkillNodeState.learnable:
      return 'Lernbar';
    case SkillNodeState.unknownRequirements:
      return 'Unbestimmt';
    case SkillNodeState.locked:
      return 'Gesperrt';
  }
}

/// Eine Knoten-Karte im Skilltree (feste Groesse fuer das Layout).
class SkillTreeNodeCard extends StatelessWidget {
  const SkillTreeNodeCard({
    super.key,
    required this.evaluated,
    required this.width,
    required this.height,
    required this.onTap,
    this.subtitle = '',
  });

  final EvaluatedNode evaluated;
  final double width;
  final double height;
  final VoidCallback onTap;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    final stateColor = skillNodeStateColor(codex, evaluated.state);
    final isTalentOrSpell = !evaluated.node.isSpecialAbility;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: codex.panel,
        borderRadius: BorderRadius.circular(codex.panelRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(codex.panelRadius),
              border: Border.all(color: stateColor, width: 2),
              gradient: LinearGradient(
                colors: [
                  stateColor.withValues(alpha: 0.14),
                  codex.panel.withValues(alpha: 0.0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isTalentOrSpell
                            ? Icons.bookmark_border
                            : Icons.auto_awesome,
                        size: 14,
                        color: stateColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          evaluated.node.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: codex.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      skillNodeStateLabel(evaluated.state),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: stateColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: codex.inkMuted,
                          ),
                        ),
                      ),
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
