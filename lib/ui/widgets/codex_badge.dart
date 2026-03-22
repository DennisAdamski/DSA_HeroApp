import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Visuelle Varianten fuer kleine Codex-Badges.
enum CodexBadgeTone { neutral, accent, success, warning, danger }

/// Kompakter Badge im Codex-Stil fuer Status, Kategorien und Hinweise.
class CodexBadge extends StatelessWidget {
  /// Erstellt einen kleinen Status-Badge.
  const CodexBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = CodexBadgeTone.neutral,
  });

  /// Badge-Text.
  final String label;

  /// Optionales Icon vor dem Label.
  final IconData? icon;

  /// Farbliche Semantik des Badges.
  final CodexBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final colors = _colorsForTone(codex, tone);
    final textStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: colors.foreground);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(codex.panelRadius),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 6),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }

  _CodexBadgeColors _colorsForTone(CodexTheme codex, CodexBadgeTone tone) {
    switch (tone) {
      case CodexBadgeTone.accent:
        return _CodexBadgeColors(
          background: codex.accent.withValues(alpha: 0.12),
          foreground: codex.accent,
          border: codex.accent.withValues(alpha: 0.35),
        );
      case CodexBadgeTone.success:
        return _CodexBadgeColors(
          background: codex.success.withValues(alpha: 0.12),
          foreground: codex.success,
          border: codex.success.withValues(alpha: 0.35),
        );
      case CodexBadgeTone.warning:
        return _CodexBadgeColors(
          background: codex.warning.withValues(alpha: 0.14),
          foreground: codex.warning,
          border: codex.warning.withValues(alpha: 0.38),
        );
      case CodexBadgeTone.danger:
        return _CodexBadgeColors(
          background: codex.danger.withValues(alpha: 0.14),
          foreground: codex.danger,
          border: codex.danger.withValues(alpha: 0.38),
        );
      case CodexBadgeTone.neutral:
        return _CodexBadgeColors(
          background: codex.panelRaised,
          foreground: codex.ink,
          border: codex.rule,
        );
    }
  }
}

class _CodexBadgeColors {
  const _CodexBadgeColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
