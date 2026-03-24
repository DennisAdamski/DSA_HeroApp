import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Kompakte Wertekarte fuer Summary-Rails und Statusblöcke.
class CodexMetricTile extends StatelessWidget {
  /// Erstellt eine kompakte Metrikkarte.
  const CodexMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.combinedValueText,
    this.icon,
    this.helper,
    this.highlight = false,
  });

  /// Bezeichnung der Kennzahl.
  final String label;

  /// Sichtbarer Wert.
  final String value;

  /// Optionaler kombinierter Text fuer Label-und-Wert-Assertions.
  final String? combinedValueText;

  /// Optionales Icon fuer schnelle Erkennbarkeit.
  final IconData? icon;

  /// Zusatztext unter dem Wert.
  final String? helper;

  /// Hebt die Karte farblich an.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    final background = highlight
        ? codex.brass.withValues(alpha: 0.12)
        : codex.panelRaised.withValues(alpha: 0.95);
    final border = highlight ? codex.brass.withValues(alpha: 0.35) : codex.rule;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(codex.panelRadius),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: codex.inkMuted),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: codex.inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            combinedValueText ?? value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: codex.ink,
            ),
          ),
          if (helper != null && helper!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(helper!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
