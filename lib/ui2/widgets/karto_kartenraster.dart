import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';

/// Raster gleich breiter Karten, deren Zeilen gleich hoch sind.
///
/// Die Spaltenzahl folgt aus der verfuegbaren Breite und [mindestbreite]; so
/// stehen Personen auf dem Telefon untereinander und im breiten Blatt zu
/// dritt. Jede Zeile streckt ihre Karten auf die hoechste, damit kurze und
/// lange Beschreibungen keine ausgefranste Kante ergeben.
class KartoKartenraster extends StatelessWidget {
  /// Erstellt ein Raster aus [kinder].
  const KartoKartenraster({
    super.key,
    required this.mindestbreite,
    required this.kinder,
  });

  /// Schmalste Breite, die eine Karte bekommen darf.
  final double mindestbreite;

  /// Karten in Lesereihenfolge.
  final List<Widget> kinder;

  @override
  Widget build(BuildContext context) {
    const luecke = Abstand.weit;
    return LayoutBuilder(
      builder: (context, constraints) {
        final spalten = math.max(
          1,
          ((constraints.maxWidth + luecke) / (mindestbreite + luecke)).floor(),
        );
        final zeilen = <Widget>[];
        for (var start = 0; start < kinder.length; start += spalten) {
          final zellen = <Widget>[];
          for (var spalte = 0; spalte < spalten; spalte++) {
            if (spalte > 0) zellen.add(const SizedBox(width: luecke));
            final index = start + spalte;
            // Leere Zellen halten die Spaltenbreite der letzten Zeile gleich.
            zellen.add(
              Expanded(
                child: index < kinder.length
                    ? kinder[index]
                    : const SizedBox.shrink(),
              ),
            );
          }
          if (zeilen.isNotEmpty) zeilen.add(const SizedBox(height: luecke));
          zeilen.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: zellen,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: zeilen,
        );
      },
    );
  }
}
