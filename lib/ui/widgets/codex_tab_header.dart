import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Visueller Header fuer Unterseiten, Subtabs und Ledger-Bereiche.
class CodexTabHeader extends StatelessWidget {
  /// Erstellt einen dekorativen Tab-Header.
  const CodexTabHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.assetPath,
  });

  /// Titel des aktuellen Bereichs.
  final String title;

  /// Kurzbeschreibung des Bereichs.
  final String subtitle;

  /// Optionales Trailing-Widget.
  final Widget? trailing;

  /// Optionales lokales Asset fuer das Header-Motiv.
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final useCompactLayout = width < 480;

    final showAsset = codex.showDecoration &&
        assetPath != null &&
        !useCompactLayout;

    return Container(
      margin: EdgeInsets.fromLTRB(12, useCompactLayout ? 8 : 12, 12, 0),
      padding: EdgeInsets.all(useCompactLayout ? 12 : 18),
      decoration: BoxDecoration(
        gradient: codex.showDecoration ? codex.heroGradientSoft : null,
        color: codex.showDecoration ? null : codex.panelRaised,
        borderRadius: BorderRadius.circular(codex.sectionRadius),
        border: Border.all(color: codex.rule),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (!useCompactLayout) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (showAsset) ...[
            const SizedBox(width: 16),
            Opacity(
              opacity: 0.9,
              child: Image.asset(assetPath!, width: 56, height: 56),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
