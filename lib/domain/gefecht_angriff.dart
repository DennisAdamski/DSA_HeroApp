import 'gefecht.dart';
import 'probe_engine.dart';

/// Umfang der bekannten Schadensfolge eines erfolgreichen Angriffs.
enum GefechtsSchadensfolge { waffenschaden, keinSchaden, manuell }

/// Gebuchter Angriff mit bekannter Schadensfolge und gebundenen Ansagemetadaten.
class Gefechtsangriffsergebnis {
  /// Die Auftrags-ID verhindert die Vermischung verschiedener Angriffe.
  const Gefechtsangriffsergebnis({
    required this.auftragId,
    required this.kampfmittel,
    required this.waffenname,
    required this.schaden,
    required this.abwehrmalus,
    required this.tpBonus,
    this.schadensfolge = GefechtsSchadensfolge.waffenschaden,
    this.manoevername = '',
    this.hinweis = 'Gegnerische Abwehr, RS und Wunden am Tisch abwickeln.',
  });
  final String auftragId, waffenname;
  final GefechtsKampfmittelwahl kampfmittel;

  /// Nur unterstützte Schadensangriffe halten ein ausführbares Würfelprofil.
  final DiceSpec? schaden;
  final int abwehrmalus, tpBonus;
  final String hinweis;
  final GefechtsSchadensfolge schadensfolge;
  final String manoevername;
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
