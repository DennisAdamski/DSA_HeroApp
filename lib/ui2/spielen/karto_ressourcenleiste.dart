import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenwert.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Zeigt die Ressourcen des Helden nebeneinander.
///
/// LeP und AuP hat jeder Held. AsP und KaP erscheinen **nur** bei tatsächlich
/// aktivierter Ressource (`resourceActivation`) — nie aufgrund einer
/// Profession oder eines Beispielprofils.
///
/// Die Werte stehen in **einer** Fläche und sind nur durch Linien getrennt,
/// nicht als einzeln gerahmte Kacheln. Sie gehören zusammen: es sind die
/// Vorräte desselben Helden, und vier eigene Kästen lassen sie wie vier
/// unabhängige Bereiche aussehen.
class KartoRessourcenleiste extends StatelessWidget {
  /// Erstellt die Leiste aus dem bereits gelesenen Snapshot.
  const KartoRessourcenleiste({
    super.key,
    required this.werte,
    required this.onBearbeiten,
    this.onSchritt,
  });

  /// Gemeinsamer Snapshot; die Leiste liest keinen Provider selbst.
  final HeroComputedSnapshot werte;

  /// Meldet, welche Ressource bearbeitet werden soll.
  final ValueChanged<KartoRessource> onBearbeiten;

  /// Meldet einen Schritt (`-5`, `-1`, `1`, `5`) einer Ressource.
  ///
  /// Die Knoepfe erscheinen nur in einer **weiten** Kachel
  /// ([KartoKachelGroesse.weit]); ohne Rueckruf oder ausserhalb einer Kachel
  /// bleibt die Leiste wie bisher.
  final void Function(KartoRessource ressource, int schritt)? onSchritt;

  // Schmalste Spalte, ab der zwei Ressourcen nebeneinander noch lesbar sind.
  static const double _mindestbreite = 132;

  // Schmalste Zelle mit Knopfreihe: vier Knoepfe zu je 48 dp samt Rand.
  static const double _mindestbreiteMitSchritt = 240;

  /// Spaltenzahl mit Knopfreihe, siehe [kartoAusgewogeneSpalten].
  static int ausgewogeneSpalten(int platz, int anzahl) =>
      kartoAusgewogeneSpalten(platz, anzahl);

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final state = werte.state;
    final abgeleitet = werte.derivedStats;
    final magie = werte.resourceActivation.magic.isEnabled;
    final goettlich = werte.resourceActivation.divine.isEnabled;
    final mitSchritt =
        onSchritt != null && KartoKachelSteuerung.istWeit(context);

    final eintraege =
        <
          ({
            KartoRessource art,
            String name,
            String kuerzel,
            IconData icon,
            int aktuell,
            int maximum,
            Color? farbe,
          })
        >[
          (
            art: KartoRessource.lebensenergie,
            name: 'Lebenspunkte',
            kuerzel: 'LeP',
            icon: Icons.favorite_outline,
            aktuell: state.currentLep,
            maximum: abgeleitet.maxLep,
            farbe: karto.lebensenergie,
          ),
          (
            art: KartoRessource.ausdauer,
            name: 'Ausdauer',
            kuerzel: 'AuP',
            icon: Icons.bolt_outlined,
            aktuell: state.currentAu,
            maximum: abgeleitet.maxAu,
            farbe: karto.ausdauer,
          ),
          if (magie)
            (
              art: KartoRessource.astralenergie,
              name: 'Astralpunkte',
              kuerzel: 'AsP',
              icon: Icons.auto_awesome_outlined,
              aktuell: state.currentAsp,
              maximum: abgeleitet.maxAsp,
              farbe: karto.astralenergie,
            ),
          if (goettlich)
            (
              art: KartoRessource.karma,
              name: 'Karmapunkte',
              kuerzel: 'KaP',
              icon: Icons.brightness_low_outlined,
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
        final mindest = mitSchritt ? _mindestbreiteMitSchritt : _mindestbreite;
        final platz = (verfuegbar / mindest)
            .floor()
            .clamp(1, eintraege.length)
            .toInt();
        final spalten = mitSchritt
            ? ausgewogeneSpalten(platz, eintraege.length)
            : platz;

        final reihen = <List<int>>[];
        for (var start = 0; start < eintraege.length; start += spalten) {
          final ende = start + spalten > eintraege.length
              ? eintraege.length
              : start + spalten;
          reihen.add(<int>[for (var i = start; i < ende; i++) i]);
        }

        Widget senkrechterTrenner() => VerticalDivider(
          width: Strich.hoehenlinie,
          thickness: Strich.hoehenlinie,
          color: karto.hoehenlinie,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < reihen.length; r++) ...[
              if (r > 0)
                Divider(
                  height: Abstand.normal,
                  thickness: Strich.hoehenlinie,
                  color: karto.hoehenlinie,
                ),
              // IntrinsicHeight, damit die senkrechten Trenner die Hoehe der
              // hoechsten Zelle der Reihe bekommen statt null.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < reihen[r].length; c++) ...[
                      if (c > 0) senkrechterTrenner(),
                      Expanded(
                        child: KartoRessourcenwert(
                          key: ValueKey<String>(
                            'karto-ressource-'
                            '${eintraege[reihen[r][c]].art.name}',
                          ),
                          bezeichnung: eintraege[reihen[r][c]].name,
                          icon: eintraege[reihen[r][c]].icon,
                          aktuell: eintraege[reihen[r][c]].aktuell,
                          maximum: eintraege[reihen[r][c]].maximum,
                          farbe: eintraege[reihen[r][c]].farbe,
                          kuerzel: eintraege[reihen[r][c]].kuerzel,
                          onBearbeiten: () =>
                              onBearbeiten(eintraege[reihen[r][c]].art),
                          schluessel: eintraege[reihen[r][c]].art.name,
                          onSchritt: mitSchritt
                              ? (schritt) => onSchritt!(
                                  eintraege[reihen[r][c]].art,
                                  schritt,
                                )
                              : null,
                        ),
                      ),
                    ],
                    // Fuellt eine unvollstaendige letzte Reihe auf, damit ihre
                    // Zellen dieselbe Breite behalten wie darueber.
                    for (var c = reihen[r].length; c < spalten; c++) ...[
                      senkrechterTrenner(),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
