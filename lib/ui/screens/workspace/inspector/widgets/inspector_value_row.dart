import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';

/// Kompakte editierbare Zeile fuer Inspector-Werte.
///
/// Layout: {Name} [-] {Modifier} [+] [↺] … {Ergebnis} {/ Max}
///
/// Wird im neuen Inspector-Layout fuer Belastung (Erschoepfung,
/// Ueberanstrengung) und die Statuswerte (Ini, GS, AW, PA, AT, RS, BE)
/// verwendet.
class InspectorValueRow extends StatelessWidget {
  const InspectorValueRow({
    super.key,
    required this.label,
    required this.modifier,
    required this.result,
    required this.onDecrement,
    required this.onIncrement,
    this.onReset,
  });

  final String label;
  final int modifier;
  final int result;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onReset;

  static const double _columnGap = 2;
  static const double _modifierWidth = 20;
  static const double _resultWidth = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonSize = adaptiveMinTouchTarget(context);
    final sign = modifier > 0 ? '+' : '';
    final modColor = modifier > 0
        ? theme.colorScheme.primary
        : modifier < 0
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        const SizedBox(width: _columnGap),
        _StepButton(
          icon: Icons.remove,
          tooltip: '$label verringern',
          onPressed: onDecrement,
        ),
        SizedBox(
          width: _modifierWidth,
          child: Align(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$sign$modifier',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: modColor,
                ),
              ),
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          tooltip: '$label erhöhen',
          onPressed: onIncrement,
        ),
        const SizedBox(width: _columnGap),
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: onReset == null
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: '$label zurücksetzen',
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  onPressed: onReset,
                  icon: const Icon(Icons.replay),
                ),
        ),
        const SizedBox(width: _columnGap),
        SizedBox(
          width: _resultWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$result',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nur-Lese-Zeile fuer MR und vergleichbare Statuswerte.
class InspectorReadOnlyValueRow extends StatelessWidget {
  const InspectorReadOnlyValueRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final buttonSize = adaptiveMinTouchTarget(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          width: buttonSize * 2 + 20 + 2 + buttonSize + 2,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final size = adaptiveMinTouchTarget(context);
    return SizedBox(
      width: size,
      height: size,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        iconSize: 14,
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
