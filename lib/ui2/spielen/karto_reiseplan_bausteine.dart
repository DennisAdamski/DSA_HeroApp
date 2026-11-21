import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/reisezeit_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Wahl von Reisemittel, Eile und Wetter für einen Reiseplan.
///
/// Rechnet nichts; die Herleitung zeigt [KartoReiseplanHerleitung].
class KartoReiseplanWahl extends StatelessWidget {
  /// Erstellt die Wahl.
  const KartoReiseplanWahl({
    super.key,
    required this.mittel,
    required this.eil,
    required this.wetter,
    required this.onMittel,
    required this.onEil,
    required this.onWetter,
    this.kennung = 'karto-reiseplan',
    this.gesperrt = false,
  });

  /// Gewähltes Reisemittel.
  final String mittel;

  /// Ob Eile gewählt ist.
  final bool eil;

  /// Schlüssel des Wetters.
  final String wetter;

  /// Neues Reisemittel.
  final ValueChanged<String> onMittel;

  /// Eile an oder aus.
  final ValueChanged<bool> onEil;

  /// Neues Wetter.
  final ValueChanged<String> onWetter;

  /// Präfix der Schlüssel.
  final String kennung;

  /// Ob die Wahl gerade gesperrt ist (etwa während eines Abrufs).
  final bool gesperrt;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final leise = texte.legende.copyWith(color: context.karto.schriftLeise);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Reisemittel', style: leise),
        const SizedBox(height: Abstand.knapp),
        Wrap(
          spacing: Abstand.knapp,
          runSpacing: Abstand.knapp,
          children: [
            for (final m in kReiseMittel)
              ChoiceChip(
                key: ValueKey<String>('$kennung-mittel-$m'),
                label: Text(reiseMittelName(m)),
                selected: reiseMittelOderFuss(mittel) == m,
                onSelected: gesperrt ? null : (_) => onMittel(m),
              ),
          ],
        ),
        const SizedBox(height: Abstand.normal),
        SwitchListTile(
          key: ValueKey<String>('$kennung-eil'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            mittel == kReiseMittelBeritten ? 'Eilritt' : 'Eilmarsch',
            style: texte.fliess,
          ),
          value: eil,
          onChanged: gesperrt ? null : onEil,
        ),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('$kennung-wetter'),
          initialValue: reiseWetter(wetter).schluessel,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Wetter'),
          items: [
            for (final w in kReiseWetter)
              DropdownMenuItem(
                value: w.schluessel,
                child: Text(
                  w.faktor == 1
                      ? w.name
                      : '${w.name} (×${formatiereReiseZahl(w.faktor)})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: gesperrt ? null : (w) => onWetter(w ?? ''),
        ),
      ],
    );
  }
}

/// Die Herleitung eines Reiseplans: je Wegart eine Zeile, Summe und
/// Hinweise.
class KartoReiseplanHerleitung extends StatelessWidget {
  /// Erstellt die Anzeige.
  const KartoReiseplanHerleitung({
    super.key,
    required this.plan,
    this.avesmapsTage,
  });

  /// Der gerechnete Plan.
  final ReisezeitPlan plan;

  /// Reisetage laut Avesmaps zum Vergleich, oder `null`.
  final double? avesmapsTage;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    final leise = texte.legende.copyWith(color: karto.schriftLeise);
    return Column(
      key: const ValueKey<String>('karto-reiseplan-herleitung'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${plan.meilen.round()} Meilen · '
          '${formatiereReiseZahl(plan.tage, stellen: 1)} Tage · '
          'Plan ${reiseTageText(plan.ganzeTage)}',
          key: const ValueKey<String>('karto-reiseplan-summe'),
          style: texte.abschnitt,
        ),
        const SizedBox(height: Abstand.knapp),
        for (final zeile in plan.zeilen) Text(zeile.text, style: texte.legende),
        for (final hinweis in plan.hinweise) ...[
          const SizedBox(height: Abstand.haar),
          Text(hinweis, style: leise),
        ],
        if (avesmapsTage != null) ...[
          const SizedBox(height: Abstand.haar),
          Text(
            'Avesmaps (zu Fuß, ohne Gelände): '
            '${formatiereReiseZahl(avesmapsTage!, stellen: 1)} Tage',
            style: leise,
          ),
        ],
      ],
    );
  }
}
