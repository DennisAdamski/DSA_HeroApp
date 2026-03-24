import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Dekorativer Leerzustand fuer leere Listen und nicht aktivierte Bereiche.
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
