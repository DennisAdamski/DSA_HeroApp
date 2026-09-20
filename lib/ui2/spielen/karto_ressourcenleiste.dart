import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenwert.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Zeigt die Ressourcen des Helden nebeneinander.
///
/// LeP und AuP hat jeder Held. AsP und KaP erscheinen **nur** bei tatsächlich
/// aktivierter Ressource (`resourceActivation`) — nie aufgrund einer
/// Profession oder eines Beispielprofils.
class KartoRessourcenleiste extends StatelessWidget {
  /// Erstellt die Leiste aus dem bereits gelesenen Snapshot.
  const KartoRessourcenleiste({
    super.key,
    required this.werte,
    required this.onBearbeiten,
  });

  /// Gemeinsamer Snapshot; die Leiste liest keinen Provider selbst.
  final HeroComputedSnapshot werte;

  /// Meldet, welche Ressource bearbeitet werden soll.
  final ValueChanged<KartoRessource> onBearbeiten;

  // Schmalste Spalte, ab der zwei Ressourcen nebeneinander noch lesbar sind.
  static const double _mindestbreite = 168;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final state = werte.state;
    final abgeleitet = werte.derivedStats;
    final magie = werte.resourceActivation.magic.isEnabled;
    final goettlich = werte.resourceActivation.divine.isEnabled;

    final eintraege =
        <
          ({
            KartoRessource art,
            String name,
            int aktuell,
            int maximum,
            Color? farbe,
          })
        >[
          (
            art: KartoRessource.lebensenergie,
            name: 'Lebenspunkte',
            aktuell: state.currentLep,
            maximum: abgeleitet.maxLep,
            farbe: karto.lebensenergie,
          ),
          (
            art: KartoRessource.ausdauer,
            name: 'Ausdauer',
            aktuell: state.currentAu,
            maximum: abgeleitet.maxAu,
            farbe: karto.ausdauer,
          ),
          if (magie)
            (
              art: KartoRessource.astralenergie,
              name: 'Astralpunkte',
              aktuell: state.currentAsp,
              maximum: abgeleitet.maxAsp,
              farbe: karto.astralenergie,
            ),
          if (goettlich)
            (
              art: KartoRessource.karma,
              name: 'Karmapunkte',
              aktuell: state.currentKap,
              maximum: abgeleitet.maxKap,
              // Karma hat bewusst kein eigenes Ressourcentoken: nur die drei
              // Farben LeP/AsP/AuP stehen in der Spielansicht fuer sich.
              farbe: null,
            ),
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Der Umbruch folgt der tatsaechlichen Abschnittsbreite, nicht der
        // Fensterklasse: die Leiste steht mal in der Haupt-, mal in einer
        // schmalen Spalte.
        final verfuegbar = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _mindestbreite;
        final rohSpalten = (verfuegbar / _mindestbreite).floor();
        final spalten = rohSpalten.clamp(1, eintraege.length).toInt();
        final zellenbreite = spalten == 1
            ? verfuegbar
            : (verfuegbar - (spalten - 1) * Abstand.normal) / spalten;

        return Wrap(
          spacing: Abstand.normal,
          runSpacing: Abstand.normal,
          children: [
            for (final eintrag in eintraege)
              SizedBox(
                width: zellenbreite,
                child: KartoRessourcenwert(
                  key: ValueKey<String>('karto-ressource-${eintrag.art.name}'),
                  bezeichnung: eintrag.name,
                  aktuell: eintrag.aktuell,
                  maximum: eintrag.maximum,
                  farbe: eintrag.farbe,
                  onBearbeiten: () => onBearbeiten(eintrag.art),
                ),
              ),
          ],
        );
      },
    );
  }
}
