import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Wiederverwendbare Sektion im Codex-Stil mit Titel und Inhaltsbereich.
class CodexSectionCard extends StatelessWidget {
  /// Erstellt eine Abschnittskarte mit optionalen Badges und Kopfaktion.
  const CodexSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.trailing,
    this.badges = const <Widget>[],
    this.padded = true,
  });

  /// Abschnittstitel.
  final String title;

  /// Optionaler Untertitel.
  final String? subtitle;

  /// Optionales Icon oder Leading-Widget im Kopf.
  final Widget? leading;

  /// Optionale Kopfaktion.
  final Widget? trailing;

  /// Kleine Headline-Badges unter dem Titel.
  final List<Widget> badges;

  /// Inhalt der Karte.
  final Widget child;

  /// Steuert das Innenpadding der Inhaltsfläche.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);

    final decoration = codex.showDecoration
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(codex.sectionRadius),
            image: const DecorationImage(
              image: AssetImage('assets/ui/codex/parchment_texture.png'),
              fit: BoxFit.cover,
              opacity: 0.08,
            ),
            gradient: LinearGradient(
              colors: <Color>[
                codex.panel.withValues(alpha: 0.98),
                codex.panelRaised.withValues(alpha: 0.96),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          )
        : null;

    return Card(
      child: Container(
        decoration: decoration,
        child: Padding(
          padding: EdgeInsets.all(padded ? 18 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 10),
                      child: leading!,
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!, style: theme.textTheme.bodySmall),
                        ],
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: badges),
                        ],
                      ],
                    ),
                  ),
                  ...?trailing == null ? null : <Widget>[trailing!],
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
