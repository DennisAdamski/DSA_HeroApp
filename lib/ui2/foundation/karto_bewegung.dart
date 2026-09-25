import 'package:flutter/widgets.dart';

/// Dauern und Kurve der neuen Oberflaeche.
///
/// Bewegung erklaert hier nur einen Wechsel — einen Wert, der sich aendert,
/// einen Bereich, der kommt. Sie schmueckt nicht. Deshalb gibt es zwei kurze
/// Dauern und eine einzige Kurve.
abstract final class Bewegung {
  /// Hover, Fokus, Toenungen.
  static const Duration kurz = Duration(milliseconds: 150);

  /// Balken, Bereichswechsel.
  static const Duration mittel = Duration(milliseconds: 250);

  /// Schnell hinein, weich aus.
  static const Curve kurve = Curves.easeOutCubic;
}

/// Liefert [dauer] oder `Duration.zero`, wenn das System Bewegung abschaltet.
///
/// Jede Animation der neuen Oberflaeche nimmt ihre Dauer ueber diese Funktion.
/// Unter Windows ist das "Animationen anzeigen" in den Bedienungshilfen, unter
/// iOS "Bewegung reduzieren".
Duration kartoDauer(BuildContext context, Duration dauer) {
  final aus = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return aus ? Duration.zero : dauer;
}
