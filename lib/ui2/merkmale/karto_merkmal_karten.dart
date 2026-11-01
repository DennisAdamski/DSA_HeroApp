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
          Wrap(
            spacing: Abstand.eng,
            runSpacing: Abstand.eng,
            children: [
              _Pille(
                text: anzeige.herkunftText,
                symbol: pruefen ? Icons.help_outline : null,
                farbe: pruefen ? karto.siegel : karto.schriftLeise,
              ),
              if (anzeige.ursprungText != null)
                _Pille(
                  key: const ValueKey<String>('karto-merkmal-ursprung'),
                  text: anzeige.ursprungText!,
                  farbe: karto.schriftLeise,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Leise Marke mit optionalem Symbol, etwa die Herkunft eines Merkmals.
class _Pille extends StatelessWidget {
  const _Pille({
    super.key,
    required this.text,
    required this.farbe,
    this.symbol,
  });

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
/// Eingeklappt steht je Art eine Zeile mit den Kurzformen (`Jähzorn 6`), die
/// bei Platzmangel mit Auslassung endet; das sind hoechstens zwei Zeilen.
/// Aufgeklappt steht jeder Eintrag einzeln, mit seinen Wirkungstexten. Der
/// Zustand gehoert dem Aufrufer ([aufgeklappt], [onUmschalten]); die Uebersicht
/// speichert nichts. Bearbeitet wird im Merkmalsblatt. Mehrdeutige Eintraege
/// tragen ein Fragezeichen, damit die offene Zuordnung am Tisch auffaellt.
class KartoMerkmalsuebersicht extends StatelessWidget {
  /// Erstellt die Uebersicht aus aufbereiteten Vor- und Nachteilen.
  const KartoMerkmalsuebersicht({
    super.key,
    required this.vorteile,
    required this.nachteile,
    this.aufgeklappt = false,
    this.onUmschalten,
  });

  /// Aufbereitete Vorteile in gespeicherter Reihenfolge.
  final List<MerkmalAnzeige> vorteile;

  /// Aufbereitete Nachteile in gespeicherter Reihenfolge.
  final List<MerkmalAnzeige> nachteile;

  /// Ob jeder Eintrag einzeln samt Wirkung gezeigt wird.
  final bool aufgeklappt;

  /// Klappt auf oder zu; `null` blendet den Umschalter aus.
  final ValueChanged<bool>? onUmschalten;

  static String _kurz(MerkmalAnzeige a) =>
      a.herkunft == MerkmalHerkunft.pruefen ? '${a.kurz} (?)' : a.kurz;

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
    final gruppen = [('Vorteile', vorteile), ('Nachteile', nachteile)];
    final anzahl = vorteile.length + nachteile.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (titel, liste) in gruppen)
          if (liste.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Abstand.normal),
              child: aufgeklappt
                  ? _Aufgeklappt(titel: titel, liste: liste)
                  : _Zeile(titel: titel, liste: liste),
            ),
        if (onUmschalten != null)
          TextButton.icon(
            key: const ValueKey<String>('karto-spiel-merkmale-umschalten'),
            onPressed: () => onUmschalten!(!aufgeklappt),
            icon: Icon(
              aufgeklappt ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(aufgeklappt ? 'Einklappen' : 'Alle zeigen ($anzahl)'),
          ),
      ],
    );
  }
}

/// Eine Zeile je Art, bei Platzmangel mit Auslassung.
class _Zeile extends StatelessWidget {
  const _Zeile({required this.titel, required this.liste});

  final String titel;
  final List<MerkmalAnzeige> liste;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$titel  ',
            style: texte.etikett.copyWith(color: karto.schriftLeise),
          ),
          TextSpan(
            text: liste.map(KartoMerkmalsuebersicht._kurz).join(' · '),
            style: texte.fliess,
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Alle Eintraege einer Art untereinander, mit Wirkungstexten.
class _Aufgeklappt extends StatelessWidget {
  const _Aufgeklappt({required this.titel, required this.liste});

  final String titel;
  final List<MerkmalAnzeige> liste;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titel, style: texte.etikett.copyWith(color: karto.schriftLeise)),
        for (final eintrag in liste)
          Padding(
            padding: const EdgeInsets.only(top: Abstand.eng),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  KartoMerkmalsuebersicht._kurz(eintrag),
                  style: texte.fliess,
                ),
                if (eintrag.wirkungen.isNotEmpty)
                  Text(
                    eintrag.wirkungen.join(' · '),
                    style: texte.fliess.copyWith(color: karto.schriftLeise),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
