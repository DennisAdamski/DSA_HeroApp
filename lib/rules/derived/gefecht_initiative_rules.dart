import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_initiative.dart';

import 'gefecht_rules.dart'
    show Gefechtswerte, gefechtsInitiative, gefechtsIniBonus;

/// WdS 82 (MCP 7047): reguläre Aktionen vor umgewandelten gleicher Phase.
List<Gefechtszeitpunkt> sortiereGefechtszeitpunkte(
  Iterable<Gefechtszeitpunkt> werte,
) {
  final liste = werte.toList();
  liste.sort((a, b) {
    final phase = b.ini.compareTo(a.ini);
    if (phase != 0) return phase;
    if (a.umgewandelt != b.umgewandelt) return a.umgewandelt ? 1 : -1;
    if (a.reserve || b.reserve) return b.ursprungsIni.compareTo(a.ursprungsIni);
    return a.id.compareTo(b.id);
  });
  return List.unmodifiable(liste);
}

/// Gleichstände ohne belegte Priorität erfordern eine Reihenfolge am Spieltisch.
bool gefechtsZeitgleich(Gefechtszeitpunkt a, Gefechtszeitpunkt b) =>
    a.ini == b.ini &&
    a.umgewandelt == b.umgewandelt &&
    (!(a.reserve || b.reserve) || a.ursprungsIni == b.ursprungsIni);

/// INI-Änderungen werden auf offene Zeitpunkte angewendet, nie auf Buchungen.
List<Gefechtszeitpunkt> gefechtsHeldenzeitpunkte(
  String id,
  String name,
  Gefechtszustand s,
  int ini,
) => [
  if (ini >= 0 &&
      (s.angriffeVerbraucht == 0 ||
          (s.handlung?.verbleibend ?? 0) > 0 ||
          s.klingen?.parade == false &&
              s.klingen!.teile.any((t) => t.ergebnis == null)))
    Gefechtszeitpunkt(
      id: '$id:regulaer',
      teilnehmerId: id,
      name: name,
      ini: ini,
      ursprungsIni: ini,
    ),
  if (ini >= 8 &&
      s.umwandlung == Gefechtsumwandlung.zweiteAttacke &&
      s.angriffeVerbraucht < 2 &&
      s.umgewandelteAktionOffen)
    Gefechtszeitpunkt(
      id: '$id:umgewandelt',
      teilnehmerId: id,
      name: name,
      ini: ini - 8,
      ursprungsIni: ini,
      umgewandelt: true,
    ),
];

/// Prüft den eigenen aktiven Zeitpunkt; reaktive PA bleiben zeitlich unabhängig.
String? gefechtsZeitsperre(
  Gefechtszustand s,
  Gefechtswerte w,
  Gefechtsaktion aktion,
) {
  final aktiv =
      aktion == Gefechtsaktion.angriff ||
      aktion == Gefechtsaktion.handlung ||
      aktion == Gefechtsaktion.orientieren ||
      aktion == Gefechtsaktion.position;
  if (!s.gemeinsameInitiative) return null;
  if (s.initiativSperre != null &&
      (aktiv || aktion == Gefechtsaktion.zusatzaktion)) {
    return s.initiativSperre;
  }
  if (!aktiv) return null;
  if (aktion == Gefechtsaktion.angriff &&
      s.reserveIni != null &&
      s.reserveBereit) {
    return s.reserveHatVorrang
        ? null
        : 'Andere verzögerte Reserve mit höherer ursprünglicher INI zuerst.';
  }
  if (s.initiativphase == null) {
    return 'Keine offene Initiativphase; gemeinsame Runde wechseln.';
  }
  if (s.zeitpunktAbgeschlossen) {
    return 'Eigener Zeitpunkt bereits abgeschlossen.';
  }
  final zweite =
      aktion == Gefechtsaktion.angriff &&
      s.umwandlung == Gefechtsumwandlung.zweiteAttacke &&
      s.angriffeVerbraucht > 0;
  final ini = gefechtsInitiative(s, w);
  final zeit = zweite ? ini - 8 : ini;
  if (zeit != s.initiativphase) {
    return 'Eigener Zeitpunkt INI $zeit, aktuelle Phase ${s.initiativphase}.';
  }
  if (zweite && s.regulaerePhaseOffen) {
    return 'Reguläre Aktionen derselben Phase zuerst abschließen.';
  }
  return null;
}

/// WdS 82: Verzögerung erlaubt keine weiteren Angriffs-/Abwehraktionen.
String? gefechtsReservesperre(Gefechtszustand s, Gefechtsaktion aktion) {
  if (s.reserveIni == null) return null;
  if (aktion == Gefechtsaktion.angriff && s.reserveBereit) return null;
  if (aktion == Gefechtsaktion.angriff ||
      aktion == Gefechtsaktion.parade ||
      aktion == Gefechtsaktion.schildparade ||
      aktion == Gefechtsaktion.zusatzaktion ||
      aktion == Gefechtsaktion.freiesAusweichen ||
      aktion == Gefechtsaktion.gezieltesAusweichen) {
    return 'Verzögerte Aktion: erst ausführen oder für erzwungene Abwehr verwerfen.';
  }
  return null;
}

/// Reserviert eine reguläre Angriffsmarke, ohne Probe, Folge oder Gratisaktion.
Gefechtszustand reserviereGefechtsaktion(Gefechtszustand s, Gefechtswerte w) {
  if (s.patzerSperre != null ||
      s.reserveIni != null ||
      s.auftrag != null ||
      s.handlung != null ||
      s.angriffeVerbraucht != 0 ||
      s.umwandlung == Gefechtsumwandlung.zweiteParade ||
      gefechtsInitiative(s, w) < 0 ||
      gefechtsZeitsperre(s, w, Gefechtsaktion.angriff) != null) {
    throw StateError('Keine freie reguläre Aktion zum Verzögern.');
  }
  return s.copyWith(
    angriffeVerbraucht: 1,
    reserveIni: gefechtsInitiative(s, w),
    fixierterIniBonus: gefechtsIniBonus(s, w),
    reserveBereit: false,
  );
}

/// Erzwungene Abwehr oder bestätigtes Misslingen verwirft die bezahlte Reserve.
Gefechtszustand verwerfeGefechtsreserve(Gefechtszustand s) =>
    s.copyWith(ohneReserve: true);
