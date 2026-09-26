import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Untergrenze fuer manuell veraenderbare Vitalwerte.
const int kVitalFloor = -10;

/// Sorte des Vitalwerts – steuert nur die Farbgebung.
enum VitalKind { lep, aup, asp, kap }

/// Prominente Vitalwert-Karte mit ±5/±1-Steppern, Reset und Bar.
///
/// Repliziert das Layout aus dem Polished-Codex-Mockup. Anpassungen
/// werden via [onChanged] mit dem neuen Wert delegiert; Persistenz
/// liegt beim Caller.
///
/// Unter Kartograph ([kartoVariante]) dieselbe Bedienung in den Token der
/// Spielansicht: Ressourcenfarbe am Balken wie bei `KartoRessourcenwert`, der
/// Wert in Tabellenziffern, die Flaeche als `senke` im Dialog.
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
    final karto = kartoVariante(context);
    final color = karto == null ? _kindColor(codex) : _kartoFarbe(karto);
    final fillRatio = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final isOverMax = current > max;
    final isCritical = max > 0 && current <= (max / 3).ceil();

    // Messing ist unter Kartograph nie Textfarbe; Ueberheilung steht in Meer.
    final valueColor = isOverMax
        ? (karto?.meer ?? codex.brass)
        : isCritical
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    final labelStyle = karto == null
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: codex.brass,
          )
        : theme.textTheme.abschnitt;
    final wertStyle = karto == null
        ? theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          )
        : theme.textTheme.wertGross.copyWith(color: valueColor);
    final maxStyle = karto == null
        ? theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.wert.copyWith(color: karto.schriftStumm);

    return DecoratedBox(
      decoration: karto == null
          ? BoxDecoration(
              color: codex.parchment,
              borderRadius: BorderRadius.circular(codex.panelRadius),
              border: Border.all(color: codex.brassMuted, width: 1),
            )
          : BoxDecoration(
              color: karto.senke,
              borderRadius: BorderRadius.circular(kKartoRadius),
              border: Border.all(
                color: karto.hoehenlinie,
                width: Strich.hoehenlinie,
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(label, style: labelStyle),
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
                      TextSpan(text: '$current', style: wertStyle),
                      TextSpan(text: ' / $max', style: maxStyle),
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
                minHeight: karto == null ? 8 : 6,
                backgroundColor: karto?.raster ?? codex.parchmentStrong,
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

  // Dieselben Ressourcenfarben wie die Spielansicht; Karma bleibt bewusst
  // ohne eigene Farbe.
  Color _kartoFarbe(KartoTheme karto) => switch (kind) {
    VitalKind.lep => karto.lebensenergie,
    VitalKind.aup => karto.ausdauer,
    VitalKind.asp => karto.astralenergie,
    VitalKind.kap => karto.schriftLeise,
  };

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
  const _StepButton({super.key, required this.label, required this.onPressed});

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
