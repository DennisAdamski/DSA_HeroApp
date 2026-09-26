import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Wiederverwendbare Sektion im Codex-Stil mit Titel und Inhaltsbereich.
///
/// Unter Kartograph ([kartoVariante]) eine `KartoFlaeche` mit
/// Abschnittsueberschrift statt einer Karte mit Pergament; Titel, Badges,
/// Aktionen und Inhalt bleiben dieselben.
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
    final karto = kartoVariante(context);
    if (karto != null) return _kartograph(context, karto);
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

  // Flaeche und Linie statt Karte; die transparente Materialschicht haelt
  // Tinte und Kachelhintergruende darin sichtbar.
  Widget _kartograph(BuildContext context, KartoTheme karto) {
    final texte = Theme.of(context).textTheme;
    final zweitzeile = subtitle?.trim() ?? '';
    return KartoFlaeche(
      innen: padded ? Abstand.blockInnen : null,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Abstand.haar,
                      right: Abstand.weit,
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(color: karto.messing),
                      child: leading!,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: texte.abschnitt),
                      if (zweitzeile.isNotEmpty) ...[
                        const SizedBox(height: Abstand.eng),
                        Text(
                          zweitzeile,
                          style: texte.etikett.copyWith(
                            color: karto.schriftLeise,
                          ),
                        ),
                      ],
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: Abstand.normal),
                        Wrap(
                          spacing: Abstand.knapp,
                          runSpacing: Abstand.knapp,
                          children: badges,
                        ),
                      ],
                    ],
                  ),
                ),
                ...?trailing == null ? null : <Widget>[trailing!],
              ],
            ),
            const SizedBox(height: Abstand.weit),
            child,
          ],
        ),
      ),
    );
  }
}
