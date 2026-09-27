import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Visueller Header fuer Unterseiten, Subtabs und Ledger-Bereiche.
///
/// Unter Kartograph ([kartoVariante]) ohne Kasten: Ueberschrift und Zweitzeile
/// durch Weissraum getrennt. Der Verwaltungskopf darueber traegt bereits die
/// Seitenueberschrift; ein zweiter Kasten saehe wie eine zweite Seite aus.
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
    final karto = kartoVariante(context);
    if (karto != null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          Abstand.weit,
          useCompactLayout ? Abstand.normal : Abstand.block,
          Abstand.weit,
          0,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.abschnitt),
                  if (!useCompactLayout) ...[
                    const SizedBox(height: Abstand.eng),
                    Text(
                      subtitle,
                      style: theme.textTheme.etikett.copyWith(
                        color: karto.schriftLeise,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Abstand.weit),
              trailing!,
            ],
          ],
        ),
      );
    }

    final showAsset =
        codex.showDecoration && assetPath != null && !useCompactLayout;

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
