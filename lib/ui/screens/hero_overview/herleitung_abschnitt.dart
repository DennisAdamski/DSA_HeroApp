import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui_shared/herleitung_anzeige.dart';

export 'package:dsa_heldenverwaltung/ui_shared/herleitung_anzeige.dart';

/// Zeigt eine [Herleitung] des Regelmoduls (ARCH-04) als Abschnitt eines
/// Modifikatordialogs: sichtbare Schritte mit Rechenweg, Quelle und
/// Bedingung, darunter das Ergebnis.
///
/// Der Abschnitt rechnet nichts; das Ergebnis ist [Herleitung.wert].
class HerleitungsAbschnitt extends StatelessWidget {
  /// Erzeugt den Abschnitt; [ergebnisBezeichnung] beschriftet die
  /// Ergebniszeile (etwa „LeP“ oder „MU“).
  const HerleitungsAbschnitt({
    super.key,
    required this.herleitung,
    required this.ergebnisBezeichnung,
    this.ergebnisKey,
  });

  /// Anzuzeigende Herleitung.
  final Herleitung herleitung;

  /// Beschriftung der Ergebniszeile.
  final String ergebnisBezeichnung;

  /// Schlüssel der Ergebniszeile für Tests.
  final Key? ergebnisKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Herleitung (gespeicherter Stand)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        HerleitungsSchritte(herleitung: herleitung),
        const Divider(height: kDialogSectionSpacing * 2),
        HerleitungsZeile(
          key: ergebnisKey,
          bezeichnung: ergebnisBezeichnung,
          wert: herleitung.wert,
          fett: true,
          vorzeichen: false,
        ),
      ],
    );
  }
}
