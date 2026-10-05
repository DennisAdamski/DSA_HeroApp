import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

import 'gefecht_kontext.dart';
import 'gefecht_wirken.dart';
import 'gefecht_angriff.dart';
import 'gefecht_laden.dart';
import 'gefecht_klingen.dart';
import 'gefecht_fremdwirkung.dart';

/// Verlässlichkeit einer Aktionsfreigabe; Hinweise allein sperren keine Aktion.
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
  laden,
  zielen,
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
    this.vorbereitung,
    this.wirkungId,
    this.fremdwirkungswurf,
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

  /// Stabile Buchungskennung und eingefrorener fremder Schadenswurf für Retry.
  final String? wirkungId;
  final GefechtsFremdwirkungswurf? fremdwirkungswurf;
  final bool kostenUebernommen, gescheitert;

  /// Ausdrücklich manuell geklärte Unterbrechungskosten ohne angenommene Formel.
  final int? abbruchKosten;

  /// Ziel eines verzögerten Ziehens oder bestätigten Wegsteckens.
  final GefechtsHand? zielHand;

  /// Waffen-/Geschossbindung und bezahlte Zeit einer Lade- oder Zielhandlung.
  final Gefechtsvorbereitung? vorbereitung;

  /// Fortschritt erhält die bestätigten Eingaben und das einmalige Ergebnis.
  Gefechtshandlung copyWith({
    int? verbleibend,
    ProbeResult? ergebnis,
    bool? kostenUebernommen,
    bool? gescheitert,
    int? abbruchKosten,
    Gefechtsvorbereitung? vorbereitung,
    GefechtsFremdwirkungswurf? fremdwirkungswurf,
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
    wirkungId: wirkungId,
    fremdwirkungswurf: fremdwirkungswurf ?? this.fremdwirkungswurf,
    ergebnis: ergebnis ?? this.ergebnis,
    kostenUebernommen: kostenUebernommen ?? this.kostenUebernommen,
    gescheitert: gescheitert ?? this.gescheitert,
    abbruchKosten: abbruchKosten ?? this.abbruchKosten,
    zielHand: zielHand,
    vorbereitung: vorbereitung ?? this.vorbereitung,
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
    this.angriffsergebnisse = const [],
    this.zielstand,
    this.umgewandelteAktionOffen = true,
    this.ladestaende = const {},
    this.meisterparadeBonus = 0,
    this.ansageFolgemalus = 0,
    this.aufrechterhalteneZauber = 0,
    this.bewegt = false,
    this.gesprintet = false,
    this.gemeinsameInitiative = false,
    this.initiativphase,
    this.zeitpunktAbgeschlossen = false,
    this.regulaerePhaseOffen = false,
    this.reserveIni,
    this.reserveBereit = false,
    this.reserveHatVorrang = true,
    this.klingen,
    this.patzerSperre,
    this.initiativSperre,
    this.gesperrteKampfmittel = const {},
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

  /// Erfolgsfolgen gehören zu einem Angriff, nie zur allgemeinen Schadensprobe.
  final List<Gefechtsangriffsergebnis> angriffsergebnisse;

  /// Letzter offener Treffer für bestehende gezielte Ergebnisanzeigen.
  Gefechtsangriffsergebnis? get angriffsergebnis =>
      angriffsergebnisse.lastOrNull;

  /// Über Runden erhaltener Nachweis tatsächlich bezahlter FK-Ansagezeit.
  final Gefechtszielstand? zielstand;

  /// Bereits bezahlte Quellmarken werden beim Umverteilen nie erneut nutzbar.
  final bool umgewandelteAktionOffen;

  /// Ladung gehört der physischen Waffen-ID, unabhängig von der aktuellen Hand.
  final Map<String, Gefechtsladestand> ladestaende;

  /// Einmalige Erleichterung der nächsten eigenen Angriffs-/Abwehraktion.
  final int meisterparadeBonus;

  /// WdS 60: misslungene Ansage erschwert Proben bis einschließlich nächster AT/PA.
  final int ansageFolgemalus;

  /// Zuletzt angegebene Zahl aufrechterhaltener Zauber; belegt das Wirken vor.
  final int aufrechterhalteneZauber;

  /// WdS S. 55: nach „Bewegen“ sind Kampfaktionen dieser Runde um 4 erschwert.
  final bool bewegt;

  /// WdS S. 55: nach „Sprinten“ keine Angriffs- oder Abwehraktion dieser Runde.
  final bool gesprintet;

  /// Nur abgeleitete Phasenprüfung, keine zusätzliche Gefechtspersistenz.
  final bool gemeinsameInitiative, zeitpunktAbgeschlossen, regulaerePhaseOffen;
  final int? initiativphase;

  /// Eine bereits bezahlte reguläre Aktion, getrennt von neuen Rundenmarken.
  final int? reserveIni;
  final bool reserveBereit;

  /// Frisch abgeleitete Priorität konkurrierender verzögerter Aktionen.
  final bool reserveHatVorrang;

  /// Geteilte Proben reservieren genau eine eigene reguläre Quellaktion.
  final GefechtsKlingenstand? klingen;

  /// Frisch abgeleitete Sperre ungeklärter Folgen oder verlorener Rundenaktionen.
  final String? patzerSperre;

  /// Fehlende Teilnehmerspielwerte unterbrechen aktive Gruppenaktionen.
  final String? initiativSperre;

  /// Defekte oder verlorene Gegenstände bleiben an ihrer physischen ID gebunden.
  final Map<String, String> gesperrteKampfmittel;

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
    List<Gefechtsangriffsergebnis>? angriffsergebnisse,
    Gefechtszielstand? zielstand,
    bool ohneZielstand = false,
    bool? umgewandelteAktionOffen,
    Map<String, Gefechtsladestand>? ladestaende,
    int? meisterparadeBonus,
    int? ansageFolgemalus,
    int? aufrechterhalteneZauber,
    bool? bewegt,
    bool? gesprintet,
    bool? gemeinsameInitiative,
    int? initiativphase,
    bool ohneInitiativphase = false,
    bool? zeitpunktAbgeschlossen,
    bool? regulaerePhaseOffen,
    int? reserveIni,
    bool? reserveBereit,
    bool ohneReserve = false,
    bool? reserveHatVorrang,
    GefechtsKlingenstand? klingen,
    bool ohneKlingen = false,
    String? patzerSperre,
    bool ohnePatzerSperre = false,
    String? initiativSperre,
    bool ohneInitiativSperre = false,
    Map<String, String>? gesperrteKampfmittel,
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
    angriffsergebnisse: angriffsergebnisse ?? this.angriffsergebnisse,
    zielstand: ohneZielstand ? null : zielstand ?? this.zielstand,
    umgewandelteAktionOffen:
        umgewandelteAktionOffen ?? this.umgewandelteAktionOffen,
    ladestaende: ladestaende ?? this.ladestaende,
    meisterparadeBonus: meisterparadeBonus ?? this.meisterparadeBonus,
    ansageFolgemalus: ansageFolgemalus ?? this.ansageFolgemalus,
    aufrechterhalteneZauber:
        aufrechterhalteneZauber ?? this.aufrechterhalteneZauber,
    bewegt: bewegt ?? this.bewegt,
    gesprintet: gesprintet ?? this.gesprintet,
    gemeinsameInitiative: gemeinsameInitiative ?? this.gemeinsameInitiative,
    initiativphase: ohneInitiativphase
        ? null
        : initiativphase ?? this.initiativphase,
    zeitpunktAbgeschlossen:
        zeitpunktAbgeschlossen ?? this.zeitpunktAbgeschlossen,
    regulaerePhaseOffen: regulaerePhaseOffen ?? this.regulaerePhaseOffen,
    reserveIni: ohneReserve ? null : reserveIni ?? this.reserveIni,
    reserveBereit: ohneReserve ? false : reserveBereit ?? this.reserveBereit,
    reserveHatVorrang: reserveHatVorrang ?? this.reserveHatVorrang,
    klingen: ohneKlingen ? null : klingen ?? this.klingen,
    patzerSperre: ohnePatzerSperre ? null : patzerSperre ?? this.patzerSperre,
    initiativSperre: ohneInitiativSperre
        ? null
        : initiativSperre ?? this.initiativSperre,
    gesperrteKampfmittel: gesperrteKampfmittel ?? this.gesperrteKampfmittel,
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
    this.sperrgruende = const [],
    this.fehlendeAngaben = const [],
    this.entscheidungen = const [],
    this.hinweise = const [],
    this.meisterparadeAnsage = 0,
    this.verbrauchterMeisterparadeBonus = 0,
    this.ansageFehlmalus = 0,
    this.beendetAnsageFolgemalus = false,
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
  final List<String> sperrgruende, fehlendeAngaben, entscheidungen, hinweise;

  /// Erst die bestätigte Buchung verbraucht den geprüften alten Bonus.
  final int verbrauchterMeisterparadeBonus;

  /// Erfolgreiche Buchung erzeugt die neue Ansage nach Verbrauch des alten Bonus.
  final int meisterparadeAnsage;

  /// Eigene Folge entsteht erst beim tatsächlich misslungenen Abschluss.
  final int ansageFehlmalus;

  /// Dieser Abschluss hat die letzte Probe der nächsten AT/PA tatsächlich geführt.
  final bool beendetAnsageFolgemalus;

  /// Ergänzt Status und Gründe, ohne Budget- oder Zielwertmetadaten zu verlieren.
  Gefechtspruefung copyWith({
    Gefechtsfreigabe? status,
    List<String>? gruende,
    List<String>? entscheidungen,
    List<String>? hinweise,
  }) => Gefechtspruefung(
    aktion: aktion,
    status: status ?? this.status,
    gruende: gruende ?? this.gruende,
    zielwert: zielwert,
    angriffe: angriffe,
    paraden: paraden,
    freie: freie,
    zusatz: zusatz,
    erschwernis: erschwernis,
    modifikatoren: modifikatoren,
    kampfmittel: kampfmittel,
    ausruestungspaar: ausruestungspaar,
    mitAnsage: mitAnsage,
    probenart: probenart,
    sperrgruende: sperrgruende,
    fehlendeAngaben: fehlendeAngaben,
    entscheidungen: entscheidungen ?? this.entscheidungen,
    hinweise: hinweise ?? this.hinweise,
    meisterparadeAnsage: meisterparadeAnsage,
    verbrauchterMeisterparadeBonus: verbrauchterMeisterparadeBonus,
    ansageFehlmalus: ansageFehlmalus,
    beendetAnsageFolgemalus: beendetAnsageFolgemalus,
  );

  /// Nur konkrete Sperren, fehlende Angaben oder offene Entscheidungen blockieren.
  bool get ausfuehrbar =>
      status != Gefechtsfreigabe.gesperrt &&
      sperrgruende.isEmpty &&
      fehlendeAngaben.isEmpty &&
      entscheidungen.isEmpty;
}
