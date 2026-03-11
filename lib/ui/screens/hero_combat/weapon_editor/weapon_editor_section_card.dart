import 'package:flutter/material.dart';

/// Einheitliche Kartenhuelle fuer Waffen-Editor-Sektionen.
class WeaponEditorSectionCard extends StatelessWidget {
  /// Erstellt eine visuell konsistente Sektion mit Titel und Inhalt.
  const WeaponEditorSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  /// Ueberschrift der Sektion.
  final String title;

  /// Optionaler beschreibender Untertitel.
  final String? subtitle;

  /// Sektion-Inhalt.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
