import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

import 'gefecht_kontext.dart';
import 'gefecht_wirken.dart';

/// Verlässlichkeit einer Aktionsfreigabe; Prüfen benötigt eine Bestätigung.
enum Gefechtsfreigabe { bereit, pruefen, gesperrt }

/// Verbindliche Verteilung der regulären Aktionen dieser Runde.
enum Gefechtsumwandlung { normal, zweiteAttacke, zweiteParade }

/// Körperhaltung für die Bewertung verfügbarer Kampfaktionen.
enum Gefechtshaltung { stehend, kniend, liegend }

/// Fachliche Handrolle; verändert keine gespeicherten Ausrüstungsschemata.
enum GefechtsHand { haupthand, nebenhand }

/// Verwendetes Kampfmittel, unabhängig von Aktionsmarken und sichtbaren Titeln.
enum GefechtsKampfmittelArt { hauptwaffe, nebenwaffe, schild, parierwaffe }

/// Flüchtige Identität der bestätigten Ausrüstung für die erneute Prüfung.
class GefechtsKampfmittelwahl {
  /// IDs treffen vorhandene Einträge unabhängig von ihrer Listenposition.
  const GefechtsKampfmittelwahl(this.art, this.id);
  final GefechtsKampfmittelArt art;
  final String id;
}

/// Vom Gefecht geführte Grundaktionen; Sonderaktionen bleiben explizit manuell.
enum Gefechtsaktion {
  angriff,
  parade,
  schildparade,
  freiesAusweichen,
  gezieltesAusweichen,
  position,
  orientieren,
  handlung,
  freieAktion,
  zusatzaktion,
}

/// Fachliche Identität einer Resthandlung, unabhängig vom sichtbaren Titel.
enum Gefechtshandlungsart {
  manuell,
  ziehen,
  orientieren,
  positionOrientieren,
  zauber,
  liturgie,
  mirakel,
  fernkampf,
}

/// Mehrteilige Handlung, deren Wirkung erst nach Abschluss eintritt.
class Gefechtshandlung {
  /// Merkt Dauer und gegebenenfalls die stabile Identität einer Zielwaffe.
  const Gefechtshandlung({
    required this.titel,
    required this.verbleibend,
    this.waffenId,
    this.waffenIndex,
    this.probe,
    this.waffe,
    this.art = Gefechtshandlungsart.manuell,
    this.ergebnis,
    this.nebenhand,
    this.wirken,
    this.kostenUebernommen = false,
    this.gescheitert = false,
    this.abbruchKosten,
    this.zielHand,
  });
  final Gefechtshandlungsart art;
  final ProbeResult? ergebnis;
  final String titel;
  final int verbleibend;
  final String? waffenId;
  final int? waffenIndex;
  final ResolvedProbeRequest? probe;
  final MainWeaponSlot? waffe;
  final OffhandEquipmentEntry? nebenhand;
  final GefechtsWirkprofil? wirken;
  final bool kostenUebernommen, gescheitert;

  /// Ausdrücklich manuell geklärte Unterbrechungskosten ohne angenommene Formel.
  final int? abbruchKosten;

  /// Ziel eines verzögerten Ziehens oder bestätigten Wegsteckens.
  final GefechtsHand? zielHand;

  /// Fortschritt erhält die bestätigten Eingaben und das einmalige Ergebnis.
  Gefechtshandlung copyWith({
    int? verbleibend,
    ProbeResult? ergebnis,
    bool? kostenUebernommen,
    bool? gescheitert,
    int? abbruchKosten,
  }) => Gefechtshandlung(
    titel: titel,
    verbleibend: verbleibend ?? this.verbleibend,
    art: art,
    waffenId: waffenId,
    waffenIndex: waffenIndex,
    waffe: waffe,
    nebenhand: nebenhand,
    probe: probe,
    wirken: wirken,
    ergebnis: ergebnis ?? this.ergebnis,
    kostenUebernommen: kostenUebernommen ?? this.kostenUebernommen,
    gescheitert: gescheitert ?? this.gescheitert,
    abbruchKosten: abbruchKosten ?? this.abbruchKosten,
    zielHand: zielHand,
  );
}

/// Ausschließlich flüchtiger, unveränderlicher Zustand eines Gefechts.
class Gefechtszustand {
  /// Beginnt ohne verbrauchte Aktionsmarken oder angenommene Gegnerdaten.
  const Gefechtszustand({
    required this.iniWurf,
    this.runde = 1,
    this.iniVerlust = 0,
    this.geschuetzterIniVerlust = 0,
    this.ungeklaerterIniVerlust = 0,
    this.angriffeVerbraucht = 0,
    this.paradenVerbraucht = 0,
    this.schildparadenVerbraucht = 0,
    this.freieVerbraucht = 0,
    this.zusatzVerbraucht = 0,
    this.regulaereAttacke = false,
    this.regulaereParade = false,
    this.umwandlung = Gefechtsumwandlung.normal,
    this.ansageGebunden = false,
    this.haltung = Gefechtshaltung.stehend,
    this.gegner = 1,
    this.dk,
    this.fixierterIniBonus,
    this.desorientiert = false,
    this.handlung,
    this.auftrag,
    this.revision = 0,
    this.kontext = const Gefechtskontext(),
    this.karmaleFehlversuche = const {},
    this.mirakelbonus,
    this.defensiverStil = false,
    this.regulaeresAngriffspaar,
    this.regulaeresParadepaar,
    this.regulaeresParademittel,
    this.paradeMitAnsage = false,
  });
  final int runde, iniWurf, iniVerlust;
  final int geschuetzterIniVerlust, ungeklaerterIniVerlust;
  final int schildparadenVerbraucht;
  final int angriffeVerbraucht,
      paradenVerbraucht,
      freieVerbraucht,
      zusatzVerbraucht;
  final Gefechtsumwandlung umwandlung;
  final bool ansageGebunden;
  final bool regulaereAttacke, regulaereParade;
  final Gefechtshaltung haltung;
  final int gegner;
  final String? dk;
  final int? fixierterIniBonus;
  final bool desorientiert;
  final Gefechtshandlung? handlung;
  final String? auftrag;
  final int revision;
  final Gefechtskontext kontext;
  final Map<String, int> karmaleFehlversuche;
  final GefechtsProbenbonus? mirakelbonus;
  final bool defensiverStil;
  final String? regulaeresAngriffspaar, regulaeresParadepaar;
  final GefechtsKampfmittelwahl? regulaeresParademittel;
  final bool paradeMitAnsage;

  /// Ändert nur benannte Sitzungsteile; kein JSON oder Heldenformat betroffen.
  Gefechtszustand copyWith({
    int? runde,
    int? iniWurf,
    int? iniVerlust,
    int? geschuetzterIniVerlust,
    int? ungeklaerterIniVerlust,
    int? angriffeVerbraucht,
    int? paradenVerbraucht,
    int? schildparadenVerbraucht,
    int? freieVerbraucht,
    int? zusatzVerbraucht,
    Gefechtsumwandlung? umwandlung,
    bool? ansageGebunden,
    bool? regulaereAttacke,
    bool? regulaereParade,
    Gefechtshaltung? haltung,
    int? gegner,
    String? dk,
    int? fixierterIniBonus,
    bool resetBonus = false,
    bool? desorientiert,
    Gefechtshandlung? handlung,
    bool ohneHandlung = false,
    String? auftrag,
    bool ohneAuftrag = false,
    int? revision,
    bool ohneDk = false,
    Gefechtskontext? kontext,
    Map<String, int>? karmaleFehlversuche,
    GefechtsProbenbonus? mirakelbonus,
    bool ohneMirakelbonus = false,
    bool? defensiverStil,
    String? regulaeresAngriffspaar,
    String? regulaeresParadepaar,
    GefechtsKampfmittelwahl? regulaeresParademittel,
    bool? paradeMitAnsage,
    bool resetKampfmittel = false,
  }) => Gefechtszustand(
    runde: runde ?? this.runde,
    iniWurf: iniWurf ?? this.iniWurf,
    iniVerlust: iniVerlust ?? this.iniVerlust,
    geschuetzterIniVerlust:
        geschuetzterIniVerlust ?? this.geschuetzterIniVerlust,
    ungeklaerterIniVerlust:
        ungeklaerterIniVerlust ?? this.ungeklaerterIniVerlust,
    angriffeVerbraucht: angriffeVerbraucht ?? this.angriffeVerbraucht,
    paradenVerbraucht: paradenVerbraucht ?? this.paradenVerbraucht,
    schildparadenVerbraucht:
        schildparadenVerbraucht ?? this.schildparadenVerbraucht,
    freieVerbraucht: freieVerbraucht ?? this.freieVerbraucht,
    zusatzVerbraucht: zusatzVerbraucht ?? this.zusatzVerbraucht,
    umwandlung: umwandlung ?? this.umwandlung,
    ansageGebunden: ansageGebunden ?? this.ansageGebunden,
    regulaereAttacke: regulaereAttacke ?? this.regulaereAttacke,
    regulaereParade: regulaereParade ?? this.regulaereParade,
    haltung: haltung ?? this.haltung,
    gegner: gegner ?? this.gegner,
    dk: ohneDk ? null : dk ?? this.dk,
    kontext: kontext ?? this.kontext,
    karmaleFehlversuche: karmaleFehlversuche ?? this.karmaleFehlversuche,
    mirakelbonus: ohneMirakelbonus ? null : mirakelbonus ?? this.mirakelbonus,
    defensiverStil: defensiverStil ?? this.defensiverStil,
    regulaeresAngriffspaar: resetKampfmittel
        ? null
        : regulaeresAngriffspaar ?? this.regulaeresAngriffspaar,
    regulaeresParadepaar: resetKampfmittel
        ? null
        : regulaeresParadepaar ?? this.regulaeresParadepaar,
    regulaeresParademittel: resetKampfmittel
        ? null
        : regulaeresParademittel ?? this.regulaeresParademittel,
    paradeMitAnsage: resetKampfmittel
        ? false
        : paradeMitAnsage ?? this.paradeMitAnsage,
    fixierterIniBonus: resetBonus
        ? null
        : fixierterIniBonus ?? this.fixierterIniBonus,
    desorientiert: desorientiert ?? this.desorientiert,
    handlung: ohneHandlung ? null : handlung ?? this.handlung,
    auftrag: ohneAuftrag ? null : auftrag ?? this.auftrag,
    revision: revision ?? this.revision,
  );
}

/// Gemeinsames Ergebnis für Darstellung und Ausführung eines Aktionsauftrags.
class Gefechtspruefung {
  /// Enthält endgültigen Zielwert, Kosten und sämtliche Prüfgründe.
  const Gefechtspruefung({
    required this.aktion,
    required this.status,
    required this.gruende,
    required this.zielwert,
    this.angriffe = 0,
    this.paraden = 0,
    this.freie = 0,
    this.zusatz = 0,
    this.erschwernis = 0,
    this.modifikatoren = const [],
    this.kampfmittel,
    this.ausruestungspaar,
    this.mitAnsage = false,
    this.probenart,
  });
  final Gefechtsaktion aktion;
  final Gefechtsfreigabe status;
  final List<String> gruende;
  final int? zielwert;
  final int angriffe, paraden, freie, zusatz, erschwernis;
  final List<Gefechtsmodifikator> modifikatoren;
  final GefechtsKampfmittelwahl? kampfmittel;
  final String? ausruestungspaar;
  final bool mitAnsage;
  final Gefechtsaktion? probenart;
}
