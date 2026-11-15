import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';

/// Die sichtbaren Schritte einer [Herleitung] mit Rechenweg, Quelle und
/// Bedingung, ohne Überschrift und Ergebniszeile.
///
/// Gemeinsam genutzt von [HerleitungsAbschnitt] und den Berechnungsschritten
/// der Kampfvorschau; rechnet nichts.
class HerleitungsSchritte extends StatelessWidget {
  /// Erzeugt die Liste der sichtbaren Schritte von [herleitung].
  const HerleitungsSchritte({
    super.key,
    required this.herleitung,
    this.bezeichnungBreite = 140,
  });

  /// Anzuzeigende Herleitung.
  final Herleitung herleitung;

  /// Breite der Beschriftungsspalte; `null` füllt den Rest der Zeile.
  final double? bezeichnungBreite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final schritt in herleitung.sichtbareSchritte)
          _SchrittZeile(schritt: schritt, breite: bezeichnungBreite),
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
    this.bezeichnungBreite = 140,
  });

  /// Linke Beschriftung.
  final String bezeichnung;

  /// Angezeigter Betrag.
  final int wert;

  /// Hebt die Zeile hervor (Ergebnis).
  final bool fett;

  /// Zeigt ein „+“ vor positiven Werten.
  final bool vorzeichen;

  /// Breite der Beschriftungsspalte; `null` füllt den Rest der Zeile.
  final double? bezeichnungBreite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = fett
        ? theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodySmall;
    final labelStyle = fett
        ? style
        : style?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (bezeichnungBreite case final breite?)
            SizedBox(
              width: breite,
              child: Text(bezeichnung, style: labelStyle),
            )
          else
            Expanded(child: Text(bezeichnung, style: labelStyle)),
          Text(
            vorzeichen ? mitVorzeichen(wert, nullText: '+0') : '$wert',
            style: style,
          ),
        ],
      ),
    );
  }
}

// Ein Schritt mit Betrag und darunter Rechenweg, Quelle oder Bedingung.
class _SchrittZeile extends StatelessWidget {
  const _SchrittZeile({required this.schritt, required this.breite});

  final HerleitungsSchritt schritt;
  final double? breite;

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
          bezeichnungBreite: breite,
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
