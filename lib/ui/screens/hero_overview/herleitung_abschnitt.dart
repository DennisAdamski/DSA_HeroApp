import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

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

/// Die sichtbaren Schritte einer [Herleitung] mit Rechenweg, Quelle und
/// Bedingung, ohne Überschrift und Ergebniszeile.
///
/// Gemeinsam genutzt von [HerleitungsAbschnitt] und den Berechnungsschritten
/// der Kampfvorschau; rechnet nichts.
class HerleitungsSchritte extends StatelessWidget {
  /// Erzeugt die Liste der sichtbaren Schritte von [herleitung].
  const HerleitungsSchritte({super.key, required this.herleitung});

  /// Anzuzeigende Herleitung.
  final Herleitung herleitung;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final schritt in herleitung.sichtbareSchritte)
          _SchrittZeile(schritt: schritt),
      ],
    );
  }
}

/// Eine Zeile „Bezeichnung  Wert“ im Stil der Modifikatordialoge.
class HerleitungsZeile extends StatelessWidget {
  /// Erzeugt die Zeile; mit [vorzeichen] erscheint ein „+“ vor positiven
  /// Werten.
  const HerleitungsZeile({
    super.key,
    required this.bezeichnung,
    required this.wert,
    this.fett = false,
    this.vorzeichen = true,
  });

  /// Linke Beschriftung.
  final String bezeichnung;

  /// Angezeigter Betrag.
  final int wert;

  /// Hebt die Zeile hervor (Ergebnis).
  final bool fett;

  /// Zeigt ein „+“ vor positiven Werten.
  final bool vorzeichen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = fett
        ? theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodySmall;
    final labelStyle = fett
        ? style
        : style?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final sign = vorzeichen && wert >= 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(bezeichnung, style: labelStyle)),
          Text('$sign$wert', style: style),
        ],
      ),
    );
  }
}

// Ein Schritt mit Betrag und darunter Rechenweg, Quelle oder Bedingung.
class _SchrittZeile extends StatelessWidget {
  const _SchrittZeile({required this.schritt});

  final HerleitungsSchritt schritt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      ?schritt.formel,
      ?schritt.quelle,
      ?schritt.bedingung,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HerleitungsZeile(
          bezeichnung: schritt.bezeichnung,
          wert: schritt.betrag,
          vorzeichen: schritt.art != HerleitungsArt.grundwert,
        ),
        if (details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              details,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
