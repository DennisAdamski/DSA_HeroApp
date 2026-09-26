part of 'package:dsa_heldenverwaltung/ui/screens/hero_reisebericht_tab.dart';

/// Signalfarben des Reiseberichts.
///
/// Klassisch die Material-Farben, mit denen der Reisebericht gebaut wurde.
/// Unter Kartograph ([kartoVariante]) dieselben Bedeutungen aus den Token der
/// Oberflaeche — sonst stuende ein knallgruener Haken neben Moos und Meer.
class _ReiseberichtFarben {
  const _ReiseberichtFarben({
    required this.erledigt,
    required this.belohnung,
    required this.belohnungText,
    required this.hinweis,
    required this.warnung,
    required this.besonders,
    required this.offen,
    required this.fehler,
  });

  /// Abgeschlossen, erfuellt, abgehakt.
  final Color erledigt;

  /// Belohnung und vollstaendiger Meilenstein (Stern, AP).
  final Color belohnung;

  /// Belohnung als Schrift; muss auf dem Grund lesbar sein.
  final Color belohnungText;

  /// Neutraler Hinweis, etwa eine Sondererfahrung.
  final Color hinweis;

  /// Offene Schwelle, Achtung.
  final Color warnung;

  /// Besondere Auszeichnung.
  final Color besonders;

  /// Noch nicht erreicht.
  final Color offen;

  /// Zerstoerendes, etwa Loeschen.
  final Color fehler;

  static final _ReiseberichtFarben _klassisch = _ReiseberichtFarben(
    erledigt: Colors.green,
    belohnung: Colors.amber,
    belohnungText: Colors.amber.shade800,
    hinweis: Colors.blue,
    warnung: Colors.orange,
    besonders: Colors.purple,
    offen: Colors.grey,
    fehler: Colors.red,
  );

  static _ReiseberichtFarben von(BuildContext context) {
    final karto = kartoVariante(context);
    if (karto == null) return _klassisch;
    return _ReiseberichtFarben(
      erledigt: karto.moos,
      belohnung: karto.messing,
      belohnungText: karto.wachs,
      hinweis: karto.meer,
      warnung: karto.siegel,
      besonders: karto.astralenergie,
      offen: karto.schriftStumm,
      fehler: karto.siegel,
    );
  }
}
