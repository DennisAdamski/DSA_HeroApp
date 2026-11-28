import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/grossmeister_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Meisterschaft der geführten Waffe im Gefecht: freier Säbel-Pool dieser KR,
/// Schalter „GE statt KK“ und alle Wirkungen. Rechnet nichts; Pool und Werte
/// kommen aus `gefecht_grossmeister_rules.dart` bzw. der Kampfvorschau.
class GefechtGrossmeisterkarte extends StatelessWidget {
  const GefechtGrossmeisterkarte({
    super.key,
    required this.meisterschaft,
    required this.poolFrei,
    required this.gesperrt,
    required this.onGeStattKk,
  });

  final MeisterschaftUebersicht meisterschaft;

  /// Noch freie Pool-Punkte dieser KR.
  final int poolFrei;
  final bool gesperrt;

  /// Schreibt den Schalter frisch in den Heldenbogen.
  final ValueChanged<bool> onGeStattKk;

  @override
  Widget build(BuildContext context) {
    final m = meisterschaft;
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final pool = m.poolPunkte;
    final gross = m.grossmeisterName.isNotEmpty;
    final zeilen = <String>[
      ...m.grossmeisterWirkungen,
      ...m.waffenmeisterWirkungen,
      ...m.hinweise,
    ];
    final trenner = Divider(
      height: Abstand.bahn,
      thickness: Strich.hoehenlinie,
      color: karto.hoehenlinie,
    );
    return KartoAbschnitt(
      key: const ValueKey('gefecht-grossmeister'),
      titel: gross ? 'Großmeister' : 'Waffenmeister',
      hinweis: [
        if (gross) _gattung(m.grossmeisterName),
        if (m.waffenmeisterName.isNotEmpty) m.waffenmeisterName,
      ].join(' · '),
      symbol: Icons.military_tech_outlined,
      // Eigene Material-Schicht für die ListTiles auf der Kartenfläche.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pool != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Säbel-Pool',
                          style: texte.etikett.copyWith(
                            color: karto.schriftLeise,
                          ),
                        ),
                        const SizedBox(height: Abstand.eng),
                        _Punkte(frei: poolFrei, gesamt: pool),
                      ],
                    ),
                  ),
                  Text.rich(
                    key: const ValueKey('gefecht-grossmeister-pool'),
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$poolFrei',
                          style: texte.wertGross.copyWith(color: karto.schrift),
                        ),
                        TextSpan(
                          text: ' / $pool',
                          style: texte.wert.copyWith(color: karto.schriftLeise),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Abstand.knapp),
              Text(
                'je KR für ${saebelPoolManoever.join(' · ')}',
                style: texte.etikett.copyWith(color: karto.schriftStumm),
              ),
            ],
            if (m.geStattKkMoeglich) ...[
              if (pool != null) trenner,
              SwitchListTile(
                key: const ValueKey('gefecht-grossmeister-ge-statt-kk'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  'Schaden aus GE statt KK',
                  style: texte.fliess.copyWith(color: karto.schrift),
                ),
                subtitle: Text(
                  m.geStattKkAktiv
                      ? 'TP/KK +${m.tpKkMitGe} (KK wäre +${m.tpKkMitKk}) · '
                            'nicht mit Wuchtschlag'
                      : 'TP/KK +${m.tpKkMitKk} · mit GE +${m.tpKkMitGe}',
                  style: texte.etikett.copyWith(color: karto.schriftLeise),
                ),
                value: m.geStattKkAktiv,
                onChanged: gesperrt ? null : onGeStattKk,
              ),
            ],
            if (zeilen.isNotEmpty) ...[
              if (pool != null || m.geStattKkMoeglich) trenner,
              Theme(
                // Ohne die Standardlinien der ExpansionTile.
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('gefecht-grossmeister-details'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(
                    bottom: Abstand.normal,
                  ),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    'Wirkungen & Tischregeln (${zeilen.length})',
                    style: texte.etikett.copyWith(color: karto.schriftLeise),
                  ),
                  children: [
                    for (final zeile in zeilen)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Abstand.eng),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: Abstand.knapp,
                                right: Abstand.normal,
                              ),
                              child: Icon(
                                Icons.circle,
                                size: 5,
                                color: karto.messing,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                zeile,
                                style: texte.fliess.copyWith(
                                  color: karto.schrift,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // „Waffen-Großmeister (Säbel)“ → „Säbel“.
  static String _gattung(String name) {
    final auf = name.indexOf('(');
    final zu = name.lastIndexOf(')');
    return auf >= 0 && zu > auf ? name.substring(auf + 1, zu) : name;
  }
}

// Freie Punkte gefüllt, verbrauchte als leere Ringe.
class _Punkte extends StatelessWidget {
  const _Punkte({required this.frei, required this.gesamt});

  final int frei, gesamt;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    return Wrap(
      spacing: Abstand.eng,
      runSpacing: Abstand.eng,
      children: [
        for (var i = 0; i < gesamt; i++)
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < frei ? karto.messing : Colors.transparent,
              border: Border.all(color: karto.messing, width: Strich.kueste),
            ),
          ),
      ],
    );
  }
}
