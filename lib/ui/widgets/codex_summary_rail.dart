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
}

/// Persistente Rail fuer verdichtete Kernwerte im Workspace.
class CodexSummaryRail extends StatelessWidget {
  /// Erstellt eine Rail aus kompakten Metrik-Karten.
  const CodexSummaryRail({super.key, required this.items});

  /// Anzuzeigende Summary-Eintraege.
  final List<CodexSummaryRailItem> items;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: codex.heroGradientSoft,
        border: Border(
          bottom: BorderSide(color: codex.rule),
          top: BorderSide(color: codex.rule.withValues(alpha: 0.6)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useHorizontalRail = constraints.maxWidth < 720;
          final tiles = items
              .map(
                (item) => SizedBox(
                  width: useHorizontalRail ? 120 : null,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: useHorizontalRail ? 120 : 132,
                      maxWidth: useHorizontalRail ? 120 : 178,
                    ),
                    child: CodexMetricTile(
                      label: item.label,
                      value: item.value,
                      combinedValueText: '${item.label}: ${item.value}',
                      icon: item.icon,
                      helper: item.helper,
                      highlight: item.highlight,
                    ),
                  ),
                ),
              )
              .toList(growable: false);

          if (useHorizontalRail) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < tiles.length; index++) ...[
                    if (index > 0) const SizedBox(width: 10),
                    tiles[index],
                  ],
                ],
              ),
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tiles,
          );
        },
      ),
    );
  }
}
