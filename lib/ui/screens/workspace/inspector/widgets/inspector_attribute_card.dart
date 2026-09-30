import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Tippbare Karte fuer eine Eigenschaft (MU, KL, IN, ...).
///
/// Loest beim Tap eine Eigenschaftsprobe aus (Probe-Aufbau und
/// Dialog-Aufruf liegen beim Caller). [value] ist der Probenwert; senken
/// Wunden ihn ([wundAbzug] < 0), erscheint er in Fehlerfarbe mit Tooltip.
class InspectorAttributeCard extends StatelessWidget {
  const InspectorAttributeCard({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.wundAbzug = 0,
  });

  final String label;
  final int value;
  final VoidCallback onTap;

  /// Abzug durch Wunden (≤ 0), bereits in [value] enthalten.
  final int wundAbzug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final karte = _karte(theme, codex);
    if (wundAbzug == 0) {
      return karte;
    }
    return Tooltip(
      message: 'Wunden −${-wundAbzug} (ohne Wunden ${value - wundAbzug})',
      child: karte,
    );
  }

  Widget _karte(ThemeData theme, CodexTheme codex) {
    return Material(
      color: codex.parchment,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: codex.brassMuted, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: codex.brass,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: wundAbzug == 0 ? null : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
