import 'package:flutter/material.dart';

/// Dokumentartiger Seitenkopf fuer Hauptbereiche der Heldenansicht.
class HeroPageHeader extends StatelessWidget {
  /// Erstellt einen Seitenkopf mit Titel, Untertitel und Kennzahlen.
  const HeroPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.metrics = const <Widget>[],
    this.trailing,
  });

  /// Haupttitel des Bereichs.
  final String title;

  /// Kurzbeschreibung des Bereichs.
  final String subtitle;

  /// Kennzahlen oder Kontext-Badges unterhalb des Titels.
  final List<Widget> metrics;

  /// Optionales Aktions-Widget auf der rechten Seite.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 16), trailing!],
            ],
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: metrics),
          ],
        ],
      ),
    );
  }
}

/// Dokumentartige Abschnittsbox mit klarer Rubrikentrennung.
class HeroDocumentSection extends StatelessWidget {
  /// Erstellt einen Abschnitt mit Titel, optionalem Untertitel und Inhalt.
  const HeroDocumentSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  /// Rubriktitel des Abschnitts.
  final String title;

  /// Optionaler Hilfstext unter dem Titel.
  final String? subtitle;

  /// Abschnittsinhalt.
  final Widget child;

  /// Optionales Aktions-Widget in der Titelleiste.
  final Widget? trailing;

  /// Innenabstand des Bereichs.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kompakte Kennzahl fuer Dokumentkopf und Statusleisten.
class HeroMetricChip extends StatelessWidget {
  /// Erstellt eine Kennzahl mit Label, Wert und optionaler Tonflaeche.
  const HeroMetricChip({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Bezeichnung der Kennzahl.
  final String label;

  /// Hauptwert der Kennzahl.
  final String value;

  /// Optionaler Zusatztext.
  final String? caption;

  /// Hintergrundfarbe der Kennzahl.
  final Color? backgroundColor;

  /// Textfarbe der Kennzahl.
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedBackground =
        backgroundColor ??
        colorScheme.secondaryContainer.withValues(alpha: 0.6);
    final resolvedForeground =
        foregroundColor ?? colorScheme.onSecondaryContainer;
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: resolvedForeground.withValues(alpha: 0.85),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: resolvedForeground,
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: resolvedForeground.withValues(alpha: 0.78),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
