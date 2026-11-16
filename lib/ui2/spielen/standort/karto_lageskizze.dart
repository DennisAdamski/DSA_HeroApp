import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/data/karte/karten_kachel_manifest.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_lage_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karte.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_stil.dart';

/// Höchstbreite der Lageskizze; eine weite Kachel bekommt keine bildschirm-
/// hohe Skizze.
const double kLageskizzeMaxBreite = 560;

/// Lageskizze des Standorts: ein fester Ausschnitt der Aventurien-Karte im
/// Stil von Avesmaps.
///
/// Mittig der Standort mit dem Reisenden, ringsum die Orte nach den
/// Zoomtafeln von Avesmaps, dazu die Route des Helden. Den Halbmesser wählt
/// [lageskizze]; mit Kartenbild ([manifest]) liegt die Karte darunter, sonst
/// Papier mit Landschimmer. Ein Tipp öffnet über [onTap] die große Karte.
class KartoLageskizze extends StatelessWidget {
  /// Zeichnet die Umgebung aus [skizze].
  const KartoLageskizze({
    super.key,
    required this.skizze,
    this.orte = const <AvesmapsOrt>[],
    this.routenPunkte = const <KartenRoutenPunkt>[],
    this.manifest,
    this.onTap,
  });

  /// Mitte und Halbmesser.
  final Lageskizze skizze;

  /// Ortsverzeichnis von Avesmaps.
  final List<AvesmapsOrt> orte;

  /// Stationen mit Position.
  final List<KartenRoutenPunkt> routenPunkte;

  /// Kartenkacheln, oder `null` (ohne Kartenbild).
  final KartenKachelManifest? manifest;

  /// Öffnet die große Karte; `null` zeigt nur.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mitte = skizze.mitte;
    final halb = skizze.radiusMeilen / kMeilenProKarteneinheit;
    final ausschnitt = KartenRechteck(
      mitte.x - halb * kSkizzeSeitenverhaeltnis,
      mitte.y - halb,
      mitte.x + halb * kSkizzeSeitenverhaeltnis,
      mitte.y + halb,
    );
    final radius = formatiereMeilen(skizze.radiusMeilen);
    return Semantics(
      label:
          'Lageskizze um ${mitte.name}, $radius in jede Richtung, '
          '${skizze.punkte.length} Siedlungen',
      image: true,
      button: onTap != null,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kLageskizzeMaxBreite),
          child: AspectRatio(
            aspectRatio: kSkizzeSeitenverhaeltnis,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KartenFarben.rahmen),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: KartoKarte(
                        key: const ValueKey<String>('karto-standort-skizze'),
                        orte: orte,
                        routenPunkte: routenPunkte,
                        standort: mitte,
                        manifest: manifest,
                        start: ausschnitt,
                        interaktiv: false,
                        hoechsterStartZoom: kKartenZoomMax,
                        onTap: onTap,
                      ),
                    ),
                    if (manifest != null)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        left: 110,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: KartoKartenNennung(
                            manifest: manifest,
                            knapp: true,
                          ),
                        ),
                      ),
                    if (onTap != null)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: KartenFarben.knopf,
                              borderRadius: BorderRadius.all(
                                Radius.circular(6),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.open_in_full,
                                size: 16,
                                color: KartenFarben.knopfText,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
