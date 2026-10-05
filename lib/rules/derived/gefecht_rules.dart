import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

import 'gefecht_kontext_rules.dart';
import 'gefecht_fernkampf_rules.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';

import 'gefecht_meisterparade_rules.dart';
import 'gefecht_ansagefolge_rules.dart';
import 'gefecht_vorgaben_rules.dart';
import 'gefecht_initiative_rules.dart';

/// Aufgelöste Kampfwerte ohne Regelberechnungen im Widget oder Provider.
class Gefechtswerte {
  /// Nimmt abgeleitete Heldenwerte und bekannte Ausrüstungsvoraussetzungen auf.
  const Gefechtswerte({
    required this.iniBasis,
    required this.at,
    required this.pa,
    required this.ausweichen,
    this.be = 0,
    this.schildPa,
    this.schildWm = 0,
    this.schildkampf2 = false,
    this.turmschild = false,
    this.ausweichen1 = false,
    this.aufmerksamkeit = false,
    this.kampfgespuer = false,
    this.stabUmwandlung = false,
    this.waffeVorhanden = true,
    this.fernkampf = false,
    this.waffenDk = '',
    this.zusatzaktionen = 0,
    this.zusatzAttacke = true,
    this.zusatzParade = true,
    this.waffe,
    this.scharfschuetze = false,
    this.meisterschuetze = false,
    this.waffenmeister = false,
    this.defensiverKampfstil = false,
    this.halbschwert = false,
    this.umwandlungVerboten = false,
    this.konkreteKampfmittel = false,
    this.klingentaenzerAktiv = false,
  });
  final int iniBasis, at, pa, ausweichen, be, zusatzaktionen;
  final int? schildPa;

  /// Reiner Schild-WM; SF und Heldenmali werden bei Kettenwaffen nicht entfernt.
  final int schildWm;
  final bool schildkampf2,
      turmschild,
      ausweichen1,
      aufmerksamkeit,
      kampfgespuer;
  final bool stabUmwandlung, waffeVorhanden, fernkampf;
  final bool zusatzAttacke, zusatzParade;
  final String waffenDk;
  final MainWeaponSlot? waffe;
  final bool scharfschuetze, meisterschuetze, waffenmeister;
  final bool defensiverKampfstil, halbschwert, umwandlungVerboten;
  final bool konkreteKampfmittel;

  /// Eigene Klingentänzer-Fähigkeiten gelten nur aktiv und bei BE höchstens 2.
  /// Spontanes Umwandeln stammt unabhängig davon aus aktivem Kampfgespür.
  final bool klingentaenzerAktiv;
}

/// Startet eine Sitzung mit dem bereits regelgerecht ermittelten INI-Wurf.
///
/// [dk] ist die Start-Distanzklasse (`gefechtsStartDk`); der Kontext beginnt
/// mit den sichtbaren Vorgaben aus `gefechtsKontextMitVorgaben`.
Gefechtszustand beginneGefecht(int wurf, {String? dk}) => Gefechtszustand(
  iniWurf: wurf,
  dk: dk,
  kontext: gefechtsKontextMitVorgaben(const Gefechtskontext()),
);

/// Aktuelle Initiative ersetzt den im Helden gespeicherten Vorschauwurf.
int gefechtsInitiative(Gefechtszustand s, Gefechtswerte w) =>
    w.iniBasis +
    s.iniWurf -
    s.iniVerlust -
    s.geschuetzterIniVerlust -
    s.ungeklaerterIniVerlust;

/// Hohe INI gilt ab der ersten tatsächlich verbrauchten Aktion bis Rundenende.
int gefechtsIniBonus(Gefechtszustand s, Gefechtswerte w) {
  if (s.fixierterIniBonus != null) return s.fixierterIniBonus!;
  final ini = gefechtsInitiative(s, w);
  return ini > 40
      ? 3
      : ini > 30
      ? 2
      : ini > 20
      ? 1
      : 0;
}

/// Noch nutzbare reguläre Angriffsmarken nach verbindlicher Umwandlung.
int gefechtsAngriffe(Gefechtszustand s, {bool inklusiveReserve = false}) {
  final anzahl = s.umwandlung == Gefechtsumwandlung.zweiteParade
      ? 0
      : s.umwandlung == Gefechtsumwandlung.zweiteAttacke
      ? 2
      : 1;
  final rest = anzahl - s.angriffeVerbraucht;
  final bezahlt = inklusiveReserve && s.reserveIni != null && s.reserveBereit
      ? 1
      : 0;
  return (rest < 0 ? 0 : rest) + bezahlt;
}

/// Verbleibende reguläre Reaktionen schließen das waffengebundene SK-II-Budget aus.
int gefechtsRegulaereParaden(Gefechtszustand s) {
  final anzahl = s.umwandlung == Gefechtsumwandlung.zweiteAttacke
      ? 0
      : s.umwandlung == Gefechtsumwandlung.zweiteParade
      ? 2
      : 1;
  final rest = anzahl - s.paradenVerbraucht;
  return rest < 0 ? 0 : rest;
}

/// Noch nutzbare Verteidigungsmarken einschließlich gebundener SK-II-Parade.
int gefechtsParaden(Gefechtszustand s, Gefechtswerte w) {
  final schildDoppelt =
      !w.konkreteKampfmittel &&
      w.schildkampf2 &&
      w.schildPa != null &&
      w.be <= 4 &&
      !w.turmschild;
  final anzahl = s.umwandlung == Gefechtsumwandlung.zweiteAttacke
      ? 0
      : s.umwandlung == Gefechtsumwandlung.zweiteParade || schildDoppelt
      ? 2
      : 1;
  return anzahl - s.paradenVerbraucht;
}

/// Ansagen sind verbindlich; Phasenprüfung erfolgt im Bedienablauf ausdrücklich.
Gefechtszustand wandleGefechtUm(
  Gefechtszustand s,
  Gefechtsumwandlung u, {
  Gefechtswerte? werte,
  bool rundenbeginn = true,
}) {
  if (!gefechtUmwandlungMoeglich(s, u, werte: werte)) {
    throw StateError(
      'Ansage ist bereits gebunden. Manuelle Korrektur verwenden.',
    );
  }
  return s.copyWith(
    umwandlung: u,
    ansageGebunden: true,
    angriffeVerbraucht: u == Gefechtsumwandlung.zweiteAttacke
        ? s.angriffeVerbraucht + s.paradenVerbraucht
        : u == Gefechtsumwandlung.zweiteParade
        ? 0
        : s.angriffeVerbraucht,
    paradenVerbraucht: u == Gefechtsumwandlung.zweiteParade
        ? s.angriffeVerbraucht + s.paradenVerbraucht
        : u == Gefechtsumwandlung.zweiteAttacke
        ? 0
        : s.paradenVerbraucht,
    umgewandelteAktionOffen: u == Gefechtsumwandlung.zweiteAttacke
        ? s.paradenVerbraucht == 0
        : u == Gefechtsumwandlung.zweiteParade && s.angriffeVerbraucht == 0,
    defensiverStil:
        rundenbeginn &&
        u == Gefechtsumwandlung.zweiteParade &&
        werte?.defensiverKampfstil == true &&
        s.angriffeVerbraucht == 0 &&
        s.paradenVerbraucht == 0 &&
        s.freieVerbraucht == 0 &&
        s.zusatzVerbraucht == 0,
  );
}

/// Vorhandene SF erlauben spätere Ansagen; der tatsächliche Zeitpunkt bleibt geprüft.
bool gefechtUmwandlungMoeglich(
  Gefechtszustand s,
  Gefechtsumwandlung u, {
  Gefechtswerte? werte,
}) {
  final zielBereit =
      s.handlung?.art == Gefechtshandlungsart.zielen &&
      s.handlung?.vorbereitung != null &&
      s.handlung?.verbleibend == 0 &&
      s.handlung?.ergebnis == null;
  if (s.ansageGebunden ||
      s.auftrag != null ||
      s.handlung != null && !zielBereit) {
    return false;
  }
  if (werte?.umwandlungVerboten == true) return false;
  const verboteneTalente = {
    'tal_kettenwaffen',
    'tal_peitschen',
    'tal_zweihandflegel',
    'tal_zweihand_hiebwaffen',
  };
  if (verboteneTalente.contains(werte?.waffe?.talentId)) return false;
  if (u == Gefechtsumwandlung.zweiteAttacke && werte?.schildPa != null) {
    return false;
  }
  if (u == Gefechtsumwandlung.zweiteAttacke &&
      werte != null &&
      gefechtsInitiative(s, werte) < 8) {
    return false;
  }
  final benutzt =
      s.angriffeVerbraucht > 0 ||
      s.paradenVerbraucht > 0 ||
      s.freieVerbraucht > 0 ||
      s.zusatzVerbraucht > 0;
  if (benutzt && werte?.kampfgespuer != true) {
    if (werte?.aufmerksamkeit != true ||
        s.angriffeVerbraucht > 0 ||
        s.regulaereAttacke) {
      return false;
    }
  }
  return true;
}

/// Setzt ausschließlich Rundenmarken zurück und erhält laufende Handlungen.
Gefechtszustand naechsteGefechtsrunde(Gefechtszustand s) {
  if (s.auftrag != null) throw StateError('Aktionsauftrag zuerst abschließen.');
  return s.copyWith(
    runde: s.runde + 1,
    resetKampfmittel: true,
    angriffeVerbraucht: 0,
    paradenVerbraucht: 0,
    schildparadenVerbraucht: 0,
    freieVerbraucht: 0,
    zusatzVerbraucht: 0,
    regulaereAttacke: false,
    regulaereParade: false,
    umwandlung: Gefechtsumwandlung.normal,
    ansageGebunden: false,
    defensiverStil: false,
    umgewandelteAktionOffen: true,
    resetBonus: true,
    ohneKlingen: s.klingen?.parade == true,
    reserveBereit: false,
    bewegt: false,
    gesprintet: false,
  );
}

/// Prüft Budget, Haltung und bekannte Ausrüstung vor jeder Probe erneut.
Gefechtspruefung pruefeGefechtsaktion(
  Gefechtszustand s,
  Gefechtswerte w,
  Gefechtsaktion aktion, {
  int zuschlag = 0,
  int? manuellerZielwert,
  List<String> pruefGruende = const [],
  List<String> sperrGruende = const [],
  bool eigenerAuftrag = false,
  bool handlungFortsetzen = false,
  bool zusatzParade = false,
  bool abwehrAufAttacke = false,
  int distanzSchritte = 0,
}) {
  final pruefen = <String>[...pruefGruende];
  final sperren = <String>[
    ...sperrGruende,
    if (s.patzerSperre != null) s.patzerSperre!,
  ];
  if (w.umwandlungVerboten && s.umwandlung != Gefechtsumwandlung.normal) {
    sperren.add('Geführte Waffe verbietet die angesagte Umwandlung.');
  }
  if (s.kontext.halbschwert && !w.halbschwert) {
    sperren.add('Halbschwertführung ohne aktive Sonderfertigkeit.');
  }
  var a = 0, p = 0, f = 0, z = 0, erschwernis = zuschlag;
  int? ziel = manuellerZielwert;
  final bonus = gefechtsIniBonus(s, w);
  final schildAbzug =
      aktion == Gefechtsaktion.schildparade &&
          s.kontext.schildWmWirksam == false
      ? w.schildWm
      : 0;
  final kontext = pruefeGefechtskontext(
    s,
    aktion,
    w.waffenDk,
    fernkampf: w.fernkampf,
    distanzAenderung: distanzSchritte != 0,
  );
  pruefen.addAll(kontext.fehlend);
  sperren.addAll(kontext.sperren);
  erschwernis += kontext.zuschlag;
  erschwernis += schildAbzug;
  if (aktion == Gefechtsaktion.schildparade &&
      w.konkreteKampfmittel &&
      s.kontext.schildWmWirksam == null) {
    pruefen.add(
      'Schild-WM gegen Kettenstab, Kettenwaffe oder Peitsche klären.',
    );
  }
  final fk = w.fernkampf && aktion == Gefechtsaktion.angriff
      ? pruefeGefechtsFernkampf(
          s,
          w.waffe,
          scharfschuetze: w.scharfschuetze,
          meisterschuetze: w.meisterschuetze,
          waffenmeister: w.waffenmeister,
        )
      : const Gefechtskontextpruefung([], [], []);
  erschwernis += fk.zuschlag;
  pruefen.addAll(fk.fehlend);
  sperren.addAll(fk.sperren);
  if (distanzSchritte != 0) {
    f = 1;
    if (w.fernkampf ||
        s.dk == null ||
        distanzSchritte.abs() > 2 ||
        naechsteGefechtsDk(s.dk, distanzSchritte) == null) {
      sperren.add('Diese Distanzänderung ist nicht möglich.');
    }
    erschwernis += distanzSchritte > 0
        ? distanzSchritte * 4
        : distanzSchritte == -2
        ? 8
        : 0;
  }
  if (s.auftrag != null && !eigenerAuftrag) {
    sperren.add('Ein Aktionsauftrag läuft.');
  }
  final zeitSperre = gefechtsZeitsperre(s, w, aktion);
  if (zeitSperre != null) sperren.add(zeitSperre);
  final reserveSperre = gefechtsReservesperre(s, aktion);
  if (reserveSperre != null) sperren.add(reserveSperre);
  if (s.klingen != null &&
      !eigenerAuftrag &&
      (s.klingen!.parade
          ? aktion == Gefechtsaktion.parade ||
                aktion == Gefechtsaktion.schildparade
          : aktion == Gefechtsaktion.angriff)) {
    sperren.add('Geteilte Teilproben zuerst ausführen oder verwerfen.');
  }
  final verteidigung =
      aktion == Gefechtsaktion.parade ||
      aktion == Gefechtsaktion.schildparade ||
      aktion == Gefechtsaktion.gezieltesAusweichen;
  final ausweichen =
      aktion == Gefechtsaktion.freiesAusweichen ||
      aktion == Gefechtsaktion.gezieltesAusweichen;
  final kampfaktion =
      aktion == Gefechtsaktion.angriff ||
      aktion == Gefechtsaktion.parade ||
      aktion == Gefechtsaktion.schildparade ||
      aktion == Gefechtsaktion.gezieltesAusweichen;
  // WdS S. 55: Bewegen erschwert Kampfaktionen derselben Runde um 4.
  final bewegenZuschlag = s.bewegt && kampfaktion ? 4 : 0;
  erschwernis += bewegenZuschlag;
  if (s.gesprintet && (kampfaktion || ausweichen)) {
    sperren.add(
      'Nach Sprinten keine Angriffs- oder Abwehraktion in dieser Runde.',
    );
  }
  if (s.desorientiert && !ausweichen && aktion != Gefechtsaktion.position) {
    sperren.add('Nach freiem Ausweichen zunächst Position ausführen.');
  }
  switch (aktion) {
    case Gefechtsaktion.angriff:
      a = 1;
      ziel ??= w.at;
      if (!w.waffeVorhanden) sperren.add('Keine geführte Waffe.');
      // Entfernung, Zielsituation, Munition und Ladung prüft
      // `pruefeGefechtsFernkampf` einzeln; ein Sammelhinweis entfällt.
      if (!w.fernkampf && s.dk == null) {
        pruefen.add('Aktuelle Distanzklasse festlegen.');
      }
      if (s.umwandlung == Gefechtsumwandlung.zweiteAttacke &&
          s.umgewandelteAktionOffen &&
          s.angriffeVerbraucht > 0) {
        erschwernis += w.stabUmwandlung ? 0 : 4;
        if (gefechtsInitiative(s, w) - 8 < 0) {
          sperren.add('Zweite AT läge unter INI 0.');
        }
        pruefen.add('Zweite Attacke bei INI −8; Zeitpunkt prüfen.');
      }
    case Gefechtsaktion.parade:
    case Gefechtsaktion.schildparade:
      p = 1;
      ziel ??= abwehrAufAttacke
          ? w.at
          : aktion == Gefechtsaktion.schildparade
          ? w.schildPa
          : w.pa;
      if (aktion == Gefechtsaktion.schildparade && w.schildPa == null) {
        sperren.add('Kein Schild geführt.');
      }
      if (aktion == Gefechtsaktion.parade && !w.waffeVorhanden) {
        sperren.add('Keine geführte Waffe.');
      }
      if (aktion == Gefechtsaktion.parade && w.fernkampf) {
        sperren.add('Geführte Fernkampfwaffe erlaubt keine Waffenparade.');
      }
      if (s.umwandlung == Gefechtsumwandlung.normal &&
          s.paradenVerbraucht > 0 &&
          (aktion != Gefechtsaktion.schildparade ||
              s.schildparadenVerbraucht != 1)) {
        sperren.add('Zweite SK-II-Parade nur mit Schild.');
      }
      if (s.umwandlung == Gefechtsumwandlung.zweiteParade &&
          s.umgewandelteAktionOffen &&
          s.paradenVerbraucht > 0) {
        erschwernis +=
            aktion == Gefechtsaktion.schildparade ||
                w.stabUmwandlung ||
                s.defensiverStil
            ? 0
            : 4;
      }
      if (!abwehrAufAttacke) ziel = ziel == null ? null : ziel + bonus;
    case Gefechtsaktion.freiesAusweichen:
      f = 1;
      ziel ??= w.ausweichen + bonus;
    case Gefechtsaktion.gezieltesAusweichen:
      p = 1;
      ziel ??= w.ausweichen + bonus;
      if (!w.ausweichen1) sperren.add('Ausweichen I fehlt.');
      if (s.dk == null) pruefen.add('DK für gezieltes Ausweichen festlegen.');
      erschwernis += switch (s.dk) {
        'H' => 8,
        'N' => 4,
        'S' => 2,
        _ => 0,
      };
      pruefen.add(
        'Rückweichen um eine DK, optional zwei (+4), manuell prüfen.',
      );
    case Gefechtsaktion.position:
    case Gefechtsaktion.orientieren:
    case Gefechtsaktion.handlung:
      if (gefechtsAngriffe(s) > 0 && gefechtsInitiative(s, w) >= 0) {
        a = 1;
      } else {
        p = 1;
      }
      pruefen.add('Zeitpunkt, Dauer und Wirkung ausdrücklich bestätigen.');
    case Gefechtsaktion.freieAktion:
      f = 1;
    case Gefechtsaktion.zusatzaktion:
      z = 1;
      if (zusatzParade ? !w.zusatzParade : !w.zusatzAttacke) {
        sperren.add(
          'Diese Zusatzaktionsart ist mit der geführten Ausrüstung nicht verfügbar.',
        );
      }
      if (zusatzParade ? !s.regulaereParade : !s.regulaereAttacke) {
        sperren.add('Zusatzaktion erst nach entsprechender regulärer Aktion.');
      }
      pruefen.add(
        'Waffenbindung, Sonderfertigkeit und Art der Zusatzaktion prüfen.',
      );
  }
  if (ausweichen) {
    if (s.haltung == Gefechtshaltung.liegend) {
      sperren.add('Liegend kein Ausweichen.');
    }
    final gegner = gefechtsGegnerzahl(s);
    if (gegner >= 4) {
      sperren.add('Bei vier oder mehr Gegnern kein Ausweichen.');
    }
    erschwernis += w.be + (gegner - 1) * 2;
  } else if (s.haltung != Gefechtshaltung.stehend) {
    pruefen.add('Haltungsmodifikatoren manuell festlegen.');
  }
  if (s.handlung != null &&
      !(aktion == Gefechtsaktion.handlung && handlungFortsetzen) &&
      !ausweichen) {
    sperren.add('Laufende Handlung zunächst abschließen oder abbrechen.');
  }
  if (s.handlung?.wirken != null && !handlungFortsetzen) {
    sperren.add(
      'Laufendes Wirken ausdrücklich auf Störung oder Abbruch prüfen.',
    );
  }
  if (a >
      gefechtsAngriffe(s, inklusiveReserve: aktion == Gefechtsaktion.angriff)) {
    sperren.add('Keine Angriffsaktion verfügbar.');
  }
  final paradenBudget = aktion == Gefechtsaktion.schildparade
      ? gefechtsParaden(s, w)
      : gefechtsRegulaereParaden(s);
  if (p > paradenBudget) {
    sperren.add('Keine Verteidigungsaktion verfügbar.');
  }
  if (f > 2 + bonus - s.freieVerbraucht) {
    sperren.add('Keine freie Aktion verfügbar.');
  }
  if (z > w.zusatzaktionen - s.zusatzVerbraucht) {
    sperren.add('Keine Zusatzaktion verfügbar.');
  }
  if (verteidigung &&
      s.umwandlung != Gefechtsumwandlung.normal &&
      w.schildkampf2 &&
      s.paradenVerbraucht > 0) {
    pruefen.add('Umwandlung schließt die zusätzliche SK-II-Parade aus.');
  }
  if (gefechtsInitiative(s, w) < 0 && a > 0) {
    sperren.add(
      'Negative INI: nur eine reguläre Reaktion/Daueraktion verfügbar.',
    );
  }
  if (ziel != null) ziel -= erschwernis;
  final status = sperren.isNotEmpty
      ? Gefechtsfreigabe.gesperrt
      : pruefen.isNotEmpty
      ? Gefechtsfreigabe.pruefen
      : Gefechtsfreigabe.bereit;
  return Gefechtspruefung(
    aktion: aktion,
    status: status,
    gruende: List.unmodifiable([...sperren, ...pruefen]),
    sperrgruende: sperren,
    entscheidungen: kontext.fehlend
        .where((g) => g.startsWith('Fernkampf-/Sonderangriff:'))
        .toList(),
    fehlendeAngaben: [
      ...kontext.fehlend.where(
        (g) => !g.startsWith('Fernkampf-/Sonderangriff:'),
      ),
      ...fk.fehlend,
      if (aktion == Gefechtsaktion.schildparade &&
          w.konkreteKampfmittel &&
          s.kontext.schildWmWirksam == null)
        'Schild-WM gegen Kettenstab, Kettenwaffe oder Peitsche klären.',
    ],
    hinweise: pruefen
        .where((g) => !kontext.fehlend.contains(g) && !fk.fehlend.contains(g))
        .toList(),
    zielwert: ziel,
    angriffe: a,
    paraden: p,
    freie: f,
    zusatz: z,
    erschwernis: erschwernis,
    modifikatoren: [
      ...kontext.modifikatoren,
      ...fk.modifikatoren,
      if (schildAbzug != 0)
        Gefechtsmodifikator('Schild-WM entfällt', schildAbzug),
      if (bewegenZuschlag != 0)
        Gefechtsmodifikator('Nach Bewegen', bewegenZuschlag),
      Gefechtsmodifikator(
        'Weitere Zuschläge/Budget/BE',
        erschwernis -
            kontext.zuschlag -
            fk.zuschlag -
            schildAbzug -
            bewegenZuschlag,
      ),
    ],
  );
}

/// Bucht einen abgeschlossenen Auftrag einmal und wendet bestätigte Folgen an.
Gefechtszustand verbraucheGefechtsaktion(
  Gefechtszustand s,
  Gefechtswerte w,
  Gefechtspruefung pruefung, {
  bool? erfolg,
}) {
  if (pruefung.status == Gefechtsfreigabe.gesperrt) {
    throw StateError('Aktion gesperrt.');
  }
  var iniVerlust = s.iniVerlust;
  var desorientiert = s.desorientiert;
  if (pruefung.aktion == Gefechtsaktion.freiesAusweichen) {
    iniVerlust += 4;
    if (erfolg == true) desorientiert = true;
  }
  if (pruefung.aktion == Gefechtsaktion.gezieltesAusweichen &&
      erfolg == false) {
    iniVerlust += 2;
  }
  if (pruefung.aktion == Gefechtsaktion.position) desorientiert = false;
  final regulaerePa =
      pruefung.paraden > 0 &&
      (pruefung.aktion == Gefechtsaktion.parade ||
          pruefung.aktion == Gefechtsaktion.schildparade);
  final regulaereAt =
      pruefung.angriffe > 0 && pruefung.aktion == Gefechtsaktion.angriff;
  final reserveGebucht = regulaereAt && s.reserveIni != null && s.reserveBereit;
  return s.copyWith(
    regulaeresAngriffspaar: regulaereAt ? pruefung.ausruestungspaar : null,
    ansageFolgemalus: gefechtsAnsageFolgemalusNachBuchung(s, pruefung, erfolg),
    meisterparadeBonus: gefechtsMeisterparadeBonusNachBuchung(
      s,
      pruefung,
      erfolg,
    ),
    regulaeresParadepaar: regulaerePa ? pruefung.ausruestungspaar : null,
    regulaeresParademittel: regulaerePa ? pruefung.kampfmittel : null,
    paradeMitAnsage: regulaerePa ? pruefung.mitAnsage : null,
    angriffeVerbraucht:
        s.angriffeVerbraucht + (reserveGebucht ? 0 : pruefung.angriffe),
    ohneReserve: reserveGebucht,
    paradenVerbraucht: s.paradenVerbraucht + pruefung.paraden,
    schildparadenVerbraucht:
        s.schildparadenVerbraucht +
        (pruefung.aktion == Gefechtsaktion.schildparade ? 1 : 0),
    freieVerbraucht: s.freieVerbraucht + pruefung.freie,
    zusatzVerbraucht: s.zusatzVerbraucht + pruefung.zusatz,
    fixierterIniBonus:
        pruefung.angriffe +
                pruefung.paraden +
                pruefung.freie +
                pruefung.zusatz >
            0
        ? gefechtsIniBonus(s, w)
        : s.fixierterIniBonus,
    regulaereAttacke:
        s.regulaereAttacke || pruefung.aktion == Gefechtsaktion.angriff,
    regulaereParade:
        s.regulaereParade ||
        pruefung.aktion == Gefechtsaktion.parade ||
        pruefung.aktion == Gefechtsaktion.schildparade,
    iniVerlust: iniVerlust,
    desorientiert: desorientiert,
    ohneAuftrag: true,
    revision: s.revision + 1,
    kontext:
        pruefung.paraden > 0 ||
            pruefung.freie > 0 ||
            pruefung.probenart == Gefechtsaktion.parade ||
            pruefung.probenart == Gefechtsaktion.schildparade
        ? gefechtsKontextMitVorgaben(s.kontext.ohneAngriff())
        : s.kontext,
  );
}
