import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';

/// Zeigt die Erwerbsvoraussetzungen einer Sonderfertigkeit als Checkliste.
///
/// Jede Zeile nennt die Forderung und — soweit bekannt — den Stand des Helden,
/// damit sofort klar ist, was genau fehlt („IN 13 — Held hat 12“). Reine
/// Regeltexte erscheinen als neutrale Hinweise; sie blockieren nichts, sollen
/// aber sichtbar bleiben, weil der Meister sie prueft.
///
/// Wird an drei Stellen genutzt: im Detaildialog einer Sonderfertigkeit, in
/// der Stufen-Karte des Pickers und im Erwerbsdialog.
class RequirementChecklist extends StatelessWidget {
  /// Erzeugt die Checkliste.
  const RequirementChecklist({
    super.key,
    required this.ergebnisse,
    this.titel = 'Voraussetzungen',
    this.nurOffene = false,
    this.dicht = false,
  });

  /// Die gepruefteten Voraussetzungen.
  final List<RequirementCheckResult> ergebnisse;

  /// Ueberschrift; leer laesst sie weg.
  final String titel;

  /// Nur die offenen Punkte zeigen — fuer kompakte Karten, in denen die
  /// erfuellten Punkte nur Platz kosten.
  final bool nurOffene;

  /// Kleinere Schrift und engere Zeilen fuer den Einsatz in Karten.
  final bool dicht;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sichtbar = nurOffene
        ? ergebnisse.where((ergebnis) => ergebnis.istOffen).toList()
        : ergebnisse;
    if (sichtbar.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (titel.isNotEmpty) ...[
          Text(titel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
        ],
        for (final ergebnis in sichtbar)
          Padding(
            padding: EdgeInsets.only(bottom: dicht ? 2 : 4),
            child: _RequirementRow(ergebnis: ergebnis, dicht: dicht),
          ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.ergebnis, required this.dicht});

  final RequirementCheckResult ergebnis;
  final bool dicht;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = requirementStatusColor(theme, ergebnis.status);
    final textStil = dicht
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyMedium;
    final soll = ergebnis.sollText.trim();
    final ist = ergebnis.istText.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 6),
          child: Icon(
            requirementStatusIcon(ergebnis.status),
            size: dicht ? 14 : 16,
            color: farbe,
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: soll.isEmpty ? 'Hinweis' : soll,
                  style: textStil?.copyWith(
                    color: ergebnis.istOffen ? farbe : null,
                    fontWeight: ergebnis.istOffen ? FontWeight.w600 : null,
                  ),
                ),
                if (ist.isNotEmpty)
                  TextSpan(
                    text: '  ·  $ist',
                    style: textStil?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Symbol fuer einen Pruefstatus — auch ausserhalb der Liste verwendet, damit
/// Karten und Chips dieselbe Bildsprache nutzen.
IconData requirementStatusIcon(RequirementStatus status) {
  switch (status) {
    case RequirementStatus.erfuellt:
      return Icons.check_circle_outline;
    case RequirementStatus.nichtErfuellt:
      return Icons.cancel_outlined;
    case RequirementStatus.hinweis:
      return Icons.info_outline;
  }
}

/// Farbe fuer einen Pruefstatus.
Color requirementStatusColor(ThemeData theme, RequirementStatus status) {
  switch (status) {
    case RequirementStatus.erfuellt:
      return theme.colorScheme.primary;
    case RequirementStatus.nichtErfuellt:
      return theme.colorScheme.error;
    case RequirementStatus.hinweis:
      return theme.colorScheme.onSurfaceVariant;
  }
}
