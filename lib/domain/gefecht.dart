import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

import 'gefecht_kontext.dart';

/// Verlässlichkeit einer Aktionsfreigabe; Prüfen benötigt eine Bestätigung.
enum Gefechtsfreigabe { bereit, pruefen, gesperrt }

/// Verbindliche Verteilung der regulären Aktionen dieser Runde.
enum Gefechtsumwandlung { normal, zweiteAttacke, zweiteParade }

/// Körperhaltung für die Bewertung verfügbarer Kampfaktionen.
enum Gefechtshaltung { stehend, kniend, liegend }

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
  });
  final Gefechtsaktion aktion;
  final Gefechtsfreigabe status;
  final List<String> gruende;
  final int? zielwert;
  final int angriffe, paraden, freie, zusatz, erschwernis;
  final List<Gefechtsmodifikator> modifikatoren;
}
