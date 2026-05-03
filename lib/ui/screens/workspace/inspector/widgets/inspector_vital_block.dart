import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Untergrenze fuer manuell veraenderbare Vitalwerte.
const int kVitalFloor = -10;

/// Sorte des Vitalwerts – steuert nur die Farbgebung.
enum VitalKind { lep, aup, asp, kap }

/// Prominente Vitalwert-Karte mit ±5/±1-Steppern, Reset und Bar.
///
/// Repliziert das Layout aus dem Polished-Codex-Mockup. Anpassungen
/// werden via [onChanged] mit dem neuen Wert delegiert; Persistenz
/// liegt beim Caller.
class InspectorVitalBlock extends StatelessWidget {
  const InspectorVitalBlock({
    super.key,
    required this.label,
    required this.subtitle,
    required this.current,
    required this.max,
    required this.kind,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final int current;
  final int max;
  final VitalKind kind;
  final void Function(int next) onChanged;

  int _clampFloor(int next) => next < kVitalFloor ? kVitalFloor : next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final color = _kindColor(codex);
    final fillRatio = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final isOverMax = current > max;
    final isCritical = max > 0 && current <= (max / 3).ceil();

    final valueColor = isOverMax
        ? codex.brass
        : isCritical
            ? theme.colorScheme.error
            : theme.colorScheme.onSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: codex.parchment,
        borderRadius: BorderRadius.circular(codex.panelRadius),
        border: Border.all(color: codex.brassMuted, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: codex.brass,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$current',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: valueColor,
                        ),
                      ),
                      TextSpan(
                        text: ' / $max',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: current != max
                      ? IconButton(
                          key: const ValueKey('vital-block-reset'),
                          tooltip: '$label zurücksetzen',
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.replay),
                          onPressed: () => onChanged(max),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fillRatio,
                minHeight: 8,
                backgroundColor: codex.parchmentStrong,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StepButton(
                  key: const ValueKey('vital-block-minus-5'),
                  label: '-5',
                  onPressed: () => onChanged(_clampFloor(current - 5)),
                ),
                const SizedBox(width: 4),
                _StepButton(
                  key: const ValueKey('vital-block-minus-1'),
                  label: '-1',
                  onPressed: () => onChanged(_clampFloor(current - 1)),
                ),
                const Spacer(),
                _StepButton(
                  key: const ValueKey('vital-block-plus-1'),
                  label: '+1',
                  onPressed: () => onChanged(current + 1),
                ),
                const SizedBox(width: 4),
                _StepButton(
                  key: const ValueKey('vital-block-plus-5'),
                  label: '+5',
                  onPressed: () => onChanged(current + 5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _kindColor(CodexTheme codex) {
    switch (kind) {
      case VitalKind.lep:
        return codex.danger;
      case VitalKind.aup:
        return codex.warning;
      case VitalKind.asp:
        return codex.accent;
      case VitalKind.kap:
        return codex.brass;
    }
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}
