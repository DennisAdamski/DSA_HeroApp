import 'package:flutter/widgets.dart';

/// Dauern und Kurve der neuen Oberflaeche.
///
/// Kurze Bedienanimationen erklären Wechsel. Zusätzliche atmosphärische
/// Akzente sind endlich und über eine getrennte Einstellung abschaltbar.
abstract final class Bewegung {
  /// Hover, Fokus, Toenungen.
  static const Duration kurz = Duration(milliseconds: 150);

  /// Balken, Bereichswechsel.
  static const Duration mittel = Duration(milliseconds: 250);

  /// Schnell hinein, weich aus.
  static const Curve kurve = Curves.easeOutCubic;
}

/// Liefert [dauer] oder `Duration.zero`, wenn App oder System Bewegung abschalten.
///
/// Jede Animation der neuen Oberflaeche nimmt ihre Dauer ueber diese Funktion.
/// Unter Windows ist das "Animationen anzeigen" in den Bedienungshilfen, unter
/// iOS "Bewegung reduzieren".
Duration kartoDauer(BuildContext context, Duration dauer) {
  final aus = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  final wahl = context
      .dependOnInheritedWidgetOfExactType<KartoEffektEinstellungen>();
  return aus || !(wahl?.animationen ?? true) ? Duration.zero : dauer;
}

/// Verteilt die lokale Effektwahl auch an gepushte Routen und Dialoge.
class KartoEffektEinstellungen extends InheritedWidget {
  /// Stellt unabhängig gespeicherte Optionen für den Teilbaum bereit.
  const KartoEffektEinstellungen({
    super.key,
    required this.animationen,
    required this.dekorativeEffekte,
    required super.child,
  });

  /// Ob Bewegungen grundsätzlich erlaubt sind.
  final bool animationen;

  /// Ob zusätzlich atmosphärische Effekte erlaubt sind.
  final bool dekorativeEffekte;

  @override
  bool updateShouldNotify(KartoEffektEinstellungen oldWidget) =>
      animationen != oldWidget.animationen ||
      dekorativeEffekte != oldWidget.dekorativeEffekte;
}

/// Dekoration bewegt sich nur mit beiden Freigaben und ohne Systemreduktion.
bool kartoDekorationAktiv(BuildContext context) {
  final wahl = context
      .dependOnInheritedWidgetOfExactType<KartoEffektEinstellungen>();
  return (wahl?.dekorativeEffekte ?? true) &&
      kartoDauer(context, Bewegung.kurz) != Duration.zero;
}
