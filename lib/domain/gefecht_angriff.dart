import 'gefecht.dart';
import 'probe_engine.dart';

/// Gebuchter erfolgreicher Angriff mit eingefrorenem Schadensprofil.
class Gefechtsangriffsergebnis {
  /// Die Auftrags-ID verhindert die Vermischung verschiedener Angriffe.
  const Gefechtsangriffsergebnis({
    required this.auftragId,
    required this.kampfmittel,
    required this.waffenname,
    required this.schaden,
    required this.abwehrmalus,
    required this.tpBonus,
    this.hinweis = 'Gegnerische Abwehr, RS und Wunden am Tisch abwickeln.',
  });
  final String auftragId, waffenname;
  final GefechtsKampfmittelwahl kampfmittel;
  final DiceSpec schaden;
  final int abwehrmalus, tpBonus;
  final String hinweis;
}

/// Bezahlte zusätzliche Zielaktionen für genau einen angesagten Schuss.
class Gefechtszielstand {
  /// Zielkontakt und Ansage machen vorhandene Zielzeit nicht übertragbar.
  const Gefechtszielstand({
    required this.kampfmittel,
    required this.zielkontakt,
    required this.ansage,
    required this.bezahlteAktionen,
    this.geschossId = '',
    this.waffenprofilKey = '',
  });
  final GefechtsKampfmittelwahl kampfmittel;
  final String zielkontakt;
  final int ansage, bezahlteAktionen;

  /// Geschosswechsel und geänderte Profile verwerfen die alte Zielzahlung.
  final String geschossId, waffenprofilKey;
}
