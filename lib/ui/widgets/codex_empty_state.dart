import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';

/// Dekorativer Leerzustand fuer leere Listen und nicht aktivierte Bereiche.
///
/// Unter Kartograph ([kartoVariante]) ohne Kasten, mit Kompassrose statt der
/// Illustration aus dem Codex-Bestand.
class CodexEmptyState extends StatelessWidget {
  /// Erstellt einen dekorativen Leerzustand mit lokaler Illustration.
  const CodexEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.assetPath,
    this.action,
  });

  /// Kurzer Zustandstitel.
  final String title;

  /// Erklaerender Text.
  final String message;

  /// Pfad zur Illustration im Asset-Bundle.
  final String assetPath;

  /// Optionale Aktion unter dem Text.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    if (kartoVariante(context) != null) {
      return Padding(
        padding: const EdgeInsets.all(Abstand.bahn),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KartoKompassrose(groesse: 88),
            const SizedBox(height: Abstand.block),
            Text(
              title,
              style: theme.textTheme.abschnitt,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Abstand.normal),
            Text(
              message,
              style: theme.textTheme.fliess,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: Abstand.block),
              action!,
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: codex.showDecoration ? codex.heroGradientSoft : null,
        color: codex.showDecoration ? null : codex.panelRaised,
        borderRadius: BorderRadius.circular(codex.sectionRadius),
        border: Border.all(color: codex.rule),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (codex.showDecoration) ...[
            Image.asset(assetPath, height: 88, fit: BoxFit.contain),
            const SizedBox(height: 18),
          ],
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
