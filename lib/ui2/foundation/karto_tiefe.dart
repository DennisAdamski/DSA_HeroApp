import 'package:flutter/widgets.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Die zwei Schattenstufen der neuen Oberflaeche.
///
/// Liegendes wirft keinen Schatten: Abschnitte und Karten tragen ihre Ebene
/// ueber Flaeche und Linie (`KartoFlaeche`). Schatten zeigen nur, dass etwas
/// **ueber** dem Papier liegt — ein Dialog, ein Menue, eine Karte unter dem
/// Mauszeiger. Deshalb gibt es genau zwei Stufen und keine dritte fuer
/// "ein bisschen hervorgehoben".
///
/// Die Werte gehoeren nicht ins Theme, weil sie nicht mit der Helligkeit
/// wechseln; nur ihre Farbe tut das und kommt aus [KartoTheme.schatten].
enum KartoTiefe {
  /// Eine antippbare Karte unter Mauszeiger oder Fokus.
  angehoben,

  /// Dialoge, Blaetter, Menues, Snackbar, Tooltip.
  schwebend;

  /// Material-Elevation fuer Komponenten, die ihren Schatten selbst zeichnen.
  double get elevation => switch (this) {
    KartoTiefe.angehoben => 3,
    KartoTiefe.schwebend => 12,
  };

  /// Schatten fuer selbst dekorierte Flaechen.
  List<BoxShadow> schatten(KartoTheme token) => switch (this) {
    KartoTiefe.angehoben => <BoxShadow>[
      BoxShadow(
        color: token.schatten,
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
    KartoTiefe.schwebend => <BoxShadow>[
      BoxShadow(
        color: token.schatten,
        blurRadius: 32,
        offset: const Offset(0, 12),
      ),
      // Kurzer Kernschatten, damit die Kante nicht im weichen Hof verschwimmt.
      BoxShadow(
        color: token.schatten.withValues(alpha: token.schatten.a * 0.6),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
  };
}
