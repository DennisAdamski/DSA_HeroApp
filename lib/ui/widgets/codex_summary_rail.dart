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
/// Unterstuetzt einen zusammengeklappten Modus mit kompakten einzeiligen
/// Chips und einen ausgeklappten Modus mit groesseren Kacheln.
class CodexSummaryRail extends StatelessWidget {
  /// Erstellt eine Rail aus kompakten Metrik-Karten.
  const CodexSummaryRail({
    super.key,
    required this.items,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  /// Anzuzeigende Summary-Eintraege.
  final List<CodexSummaryRailItem> items;

  /// Zeigt die Rail im kompakten einzeiligen Modus.
  final bool collapsed;

  /// Callback zum Umschalten zwischen collapsed und expanded.
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;

    final padding = collapsed
        ? const EdgeInsets.fromLTRB(12, 6, 4, 6)
        : const EdgeInsets.fromLTRB(12, 10, 12, 10);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: codex.heroGradientSoft,
        border: Border(
          bottom: BorderSide(color: codex.rule),
          top: BorderSide(color: codex.rule.withValues(alpha: 0.6)),
        ),
      ),
      child: collapsed ? _buildCollapsed(codex) : _buildExpanded(codex),
    );
  }

  Widget _buildCollapsed(CodexTheme codex) {
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
        if (onToggleCollapsed != null)
          IconButton(
            icon: const Icon(Icons.expand_more, size: 20),
            onPressed: onToggleCollapsed,
            tooltip: 'Kernwerte aufklappen',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }

  Widget _buildExpanded(CodexTheme codex) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useHorizontalRail = constraints.maxWidth < 720;
        final tiles = items
            .map(
              (item) => SizedBox(
                width: useHorizontalRail ? 100 : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: useHorizontalRail ? 100 : 100,
                    maxWidth: useHorizontalRail ? 100 : 140,
                  ),
                  child: CodexMetricTile(
                    label: item.label,
                    value: item.value,
                    icon: item.icon,
                    helper: item.helper,
                    highlight: item.highlight,
                    onTap: item.onTap,
                  ),
                ),
              ),
            )
            .toList(growable: false);

        final toggle = onToggleCollapsed != null
            ? IconButton(
                icon: const Icon(Icons.expand_less, size: 20),
                onPressed: onToggleCollapsed,
                tooltip: 'Kernwerte zuklappen',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              )
            : null;

        if (useHorizontalRail) {
          return Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        tiles[i],
                      ],
                    ],
                  ),
                ),
              ),
              ?toggle,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tiles,
            ),
            if (toggle case final toggle?)
              Align(alignment: Alignment.centerRight, child: toggle),
          ],
        );
      },
    );
  }
}
