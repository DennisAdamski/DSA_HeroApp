import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_metric_tile.dart';

/// Datenmodell fuer einen Eintrag in der Summary-Rail.
class CodexSummaryRailItem {
  /// Erstellt einen Summary-Rail-Eintrag.
  const CodexSummaryRailItem({
    required this.label,
    required this.value,
    this.icon,
    this.helper,
    this.highlight = false,
    this.onTap,
  });

  /// Anzeige-Label.
  final String label;

  /// Anzeige-Wert.
  final String value;

  /// Optionales Icon.
  final IconData? icon;

  /// Optionaler Hilfstext.
  final String? helper;

  /// Hebt den Eintrag hervor.
  final bool highlight;

  /// Tap-Handler fuer interaktive Eintraege.
  final VoidCallback? onTap;
}

/// Persistente Rail fuer verdichtete Kernwerte im Workspace.
///
/// Die Rail bleibt dauerhaft im kompakten einzeiligen Layout, weil die
/// verdichtete Darstellung fuer den Workspace ausreicht.
class CodexSummaryRail extends StatelessWidget {
  /// Erstellt eine Rail aus kompakten Metrik-Karten.
  const CodexSummaryRail({
    super.key,
    required this.items,
  });

  /// Anzuzeigende Summary-Eintraege.
  final List<CodexSummaryRailItem> items;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: codex.heroGradientSoft,
        border: Border(
          bottom: BorderSide(color: codex.rule),
          top: BorderSide(color: codex.rule.withValues(alpha: 0.6)),
        ),
      ),
      child: _buildCompactRail(),
    );
  }

  /// Baut die dauerhafte Kompaktansicht der Kernwerte.
  Widget _buildCompactRail() {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  CodexMetricTile(
                    label: items[i].label,
                    value: items[i].value,
                    icon: items[i].icon,
                    highlight: items[i].highlight,
                    compact: true,
                    onTap: items[i].onTap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
