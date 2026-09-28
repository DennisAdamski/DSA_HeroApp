import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Vor- oder Nachteil als Karte: Art, Name, Stufe/Auswahl, Wirkung, Herkunft.
///
/// Entspricht den Merkmalskarten des Mockups („Was dich ausmacht“). Der Name
/// ist der aktuelle Katalogname; die Wirkungszeile kommt aus
/// `beschreibeMerkmal` und damit aus denselben Betraegen wie die Rechnung.
class KartoMerkmalkarte extends StatelessWidget {
  /// Erstellt die Karte zu [anzeige].
  const KartoMerkmalkarte({super.key, required this.anzeige, this.onTap});

  /// Aufbereitete Angaben des Eintrags.
  final MerkmalAnzeige anzeige;

  /// Oeffnet die Bearbeitung; `null` zeigt die Karte nur an.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final pruefen = anzeige.herkunft == MerkmalHerkunft.pruefen;
    return KartoTippbareKarte(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            anzeige.art,
            style: texte.marke.copyWith(color: karto.schriftLeise),
          ),
          const SizedBox(height: Abstand.eng),
          Text(
            anzeige.name,
            style: texte.abschnitt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (anzeige.detail.isNotEmpty) ...[
            const SizedBox(height: Abstand.eng),
            Text(anzeige.detail, style: texte.fliess),
          ],
          if (anzeige.wirkungen.isNotEmpty) ...[
            const SizedBox(height: Abstand.eng),
            Text(
              anzeige.wirkungen.join(' · '),
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            ),
          ],
          const SizedBox(height: Abstand.normal),
          _Pille(
            text: anzeige.herkunftText,
            symbol: pruefen ? Icons.help_outline : null,
            farbe: pruefen ? karto.siegel : karto.schriftLeise,
          ),
        ],
      ),
    );
  }
}

/// Leise Marke mit optionalem Symbol, etwa die Herkunft eines Merkmals.
class _Pille extends StatelessWidget {
  const _Pille({required this.text, required this.farbe, this.symbol});

  final String text;
  final Color farbe;
  final IconData? symbol;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: karto.senke,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Abstand.normal,
          vertical: Abstand.eng,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (symbol != null) ...[
              Icon(symbol, size: 14, color: farbe),
              const SizedBox(width: Abstand.eng),
            ],
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.marke.copyWith(color: farbe),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kompakte Uebersicht der Vor- und Nachteile fuer die Spielansicht.
///
/// Zeigt je Art eine Zeile mit den Kurzformen (`Jähzorn 6`); bearbeitet wird
/// im Merkmalsblatt. Mehrdeutige Eintraege tragen ein Fragezeichen, damit die
/// offene Zuordnung am Tisch auffaellt.
class KartoMerkmalsuebersicht extends StatelessWidget {
  /// Erstellt die Uebersicht aus aufbereiteten Vor- und Nachteilen.
  const KartoMerkmalsuebersicht({
    super.key,
    required this.vorteile,
    required this.nachteile,
  });

  /// Aufbereitete Vorteile in gespeicherter Reihenfolge.
  final List<MerkmalAnzeige> vorteile;

  /// Aufbereitete Nachteile in gespeicherter Reihenfolge.
  final List<MerkmalAnzeige> nachteile;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    if (vorteile.isEmpty && nachteile.isEmpty) {
      return Text(
        'Keine Einträge.',
        style: texte.fliess.copyWith(color: karto.schriftLeise),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (titel, liste) in [
          ('Vorteile', vorteile),
          ('Nachteile', nachteile),
        ])
          if (liste.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Abstand.normal),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$titel  ',
                      style: texte.etikett.copyWith(color: karto.schriftLeise),
                    ),
                    TextSpan(
                      text: liste
                          .map(
                            (a) => a.herkunft == MerkmalHerkunft.pruefen
                                ? '${a.kurz} (?)'
                                : a.kurz,
                          )
                          .join(' · '),
                      style: texte.fliess,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
