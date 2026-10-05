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
    this.gegnerId,
    this.gewuerfelteTp,
    this.manoeverId,
    this.folgewuerfel,
    this.meisterlichesEntwaffnen = false,
    this.abwehrGeklaert = false,
    this.folgeTp,
    this.gegenprobeErfolg,
    this.iniVerlust,
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

  /// Ursprüngliches Ziel bleibt bei späterem Kontaktwechsel erhalten.
  final String? gegnerId;

  /// Ein gewürfelter Schaden wartet ohne neuen Wurf auf die Trefferbestätigung.
  final int? gewuerfelteTp;

  /// Typisierter Gegenprobenweg, getrennt von gewöhnlichem Waffenschaden.
  final String? manoeverId;
  final DiceSpec? folgewuerfel;
  final bool meisterlichesEntwaffnen;

  /// Fortschritt bleibt bei Navigation und Abbruch ohne erneute Folgewürfe erhalten.
  final bool abwehrGeklaert;
  final int? folgeTp, iniVerlust;
  final bool? gegenprobeErfolg;

  /// Erhält sämtliche Ansagen und Zielbindung beim einmaligen Schadenswurf.
  Gefechtsangriffsergebnis mitSchaden(int tp) => Gefechtsangriffsergebnis(
    auftragId: auftragId,
    kampfmittel: kampfmittel,
    waffenname: waffenname,
    schaden: schaden,
    abwehrmalus: abwehrmalus,
    tpBonus: tpBonus,
    schadensfolge: schadensfolge,
    manoevername: manoevername,
    hinweis: hinweis,
    gegnerId: gegnerId,
    gewuerfelteTp: tp,
    manoeverId: manoeverId,
    folgewuerfel: folgewuerfel,
    meisterlichesEntwaffnen: meisterlichesEntwaffnen,
    abwehrGeklaert: abwehrGeklaert,
    folgeTp: folgeTp,
    gegenprobeErfolg: gegenprobeErfolg,
    iniVerlust: iniVerlust,
  );

  /// Friert einzelne Schritte eines schadenslosen Gegenprobenablaufs ein.
  Gefechtsangriffsergebnis mitFolge({
    bool? abwehrGeklaert,
    int? folgeTp,
    bool? gegenprobeErfolg,
    int? iniVerlust,
  }) => Gefechtsangriffsergebnis(
    auftragId: auftragId,
    kampfmittel: kampfmittel,
    waffenname: waffenname,
    schaden: schaden,
    abwehrmalus: abwehrmalus,
    tpBonus: tpBonus,
    schadensfolge: schadensfolge,
    manoevername: manoevername,
    hinweis: hinweis,
    gegnerId: gegnerId,
    gewuerfelteTp: gewuerfelteTp,
    manoeverId: manoeverId,
    folgewuerfel: folgewuerfel,
    meisterlichesEntwaffnen: meisterlichesEntwaffnen,
    abwehrGeklaert: abwehrGeklaert ?? this.abwehrGeklaert,
    folgeTp: folgeTp ?? this.folgeTp,
    gegenprobeErfolg: gegenprobeErfolg ?? this.gegenprobeErfolg,
    iniVerlust: iniVerlust ?? this.iniVerlust,
  );
}

/// Bezahlte zusätzliche Zielaktionen für genau einen angesagten Schuss.
class Gefechtszielstand {
  /// Zielkontakt und Ansage machen vorhandene Zielzeit nicht übertragbar.
  const Gefechtszielstand({
    required this.kampfmittel,
    required this.zielkontakt,
    required this.ansage,
    required this.bezahlteAktionen,
    this.zielErleichterung = 0,
    this.geschossId = '',
    this.waffenprofilKey = '',
  });
  final GefechtsKampfmittelwahl kampfmittel;
  final String zielkontakt;
  final int ansage, bezahlteAktionen;

  /// Separate Wahl für optionales Zielen, keine Reduktion der TP-Ansage.
  final int zielErleichterung;

  /// Geschosswechsel und geänderte Profile verwerfen die alte Zielzahlung.
  final String geschossId, waffenprofilKey;
}
