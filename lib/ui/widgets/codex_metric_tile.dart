import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Kompakte Wertekarte fuer Summary-Rails und Statusblöcke.
class CodexMetricTile extends StatelessWidget {
  /// Erstellt eine kompakte Metrikkarte.
  const CodexMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.helper,
    this.highlight = false,
    this.compact = false,
    this.onTap,
  });

  /// Bezeichnung der Kennzahl.
  final String label;

  /// Sichtbarer Wert.
  final String value;

  /// Optionales Icon fuer schnelle Erkennbarkeit.
  final IconData? icon;

  /// Zusatztext unter dem Wert.
  final String? helper;

  /// Hebt die Karte farblich an.
  final bool highlight;

  /// Aktiviert die kompakte einzeilige Darstellung.
  final bool compact;

  /// Tap-Handler fuer interaktive Kacheln.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    final background = highlight
        ? codex.brass.withValues(alpha: 0.12)
        : codex.panelRaised.withValues(alpha: 0.95);
    final border = highlight ? codex.brass.withValues(alpha: 0.35) : codex.rule;

    final content = compact ? _buildCompact(theme, codex) : _buildExpanded(theme, codex);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(codex.panelRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(codex.panelRadius),
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
              : const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(codex.panelRadius),
            border: Border.all(color: border),
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildCompact(ThemeData theme, CodexTheme codex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: codex.inkMuted),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: codex.inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: codex.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(ThemeData theme, CodexTheme codex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: codex.inkMuted),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: codex.inkMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextSpan(
                      text: value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: codex.ink,
                      ),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (helper != null && helper!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(helper!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
