import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_ablauf_rules.dart';
import 'gefecht_held_rules.dart';
import 'gefecht_rules.dart';
import 'gefecht_kampfmittel_rules.dart';
import 'gefecht_zusatz_rules.dart';
import 'gefecht_freigabe_rules.dart';
import 'gefecht_ansage_rules.dart';

/// Identische Prüfung vor Anzeige und Ausführung, mit bekannten Gegnersperren.
Gefechtspruefung pruefeGefechtAuftrag(
  Gefechtszustand s,
  HeroComputedSnapshot snapshot,
  RulesCatalog katalog,
  GefechtAuftrag auftrag, {
  bool eigenerAuftrag = false,
}) {
  final basis = _pruefeGefechtAuftrag(
    s,
    snapshot,
    katalog,
    auftrag,
    eigenerAuftrag: eigenerAuftrag,
  );
  final ansagen = ergaenzeGefechtsansagen(basis, s, snapshot, katalog, auftrag);
  return ergaenzeGefechtsfreigabe(ansagen, auftrag);
}

// Fachprüfung bleibt von Formularpflichten getrennt und wird identisch wiederverwendet.
Gefechtspruefung _pruefeGefechtAuftrag(
  Gefechtszustand s,
  HeroComputedSnapshot snapshot,
  RulesCatalog katalog,
  GefechtAuftrag auftrag, {
  bool eigenerAuftrag = false,
}) {
  final zustand = s.copyWith(
    dk: auftrag.dk,
    ohneDk: auftrag.dk == null,
    kontext: auftrag.kontext,
  );
  final wahl =
      auftrag.kampfmittel ??
      gefechtsStandardKampfmittel(snapshot, auftrag.aktion);
  final profil = gefechtsKampfmittelFuer(snapshot, wahl);
  final relevanteAktion = gefechtsAktionMitKampfmittel(auftrag.aktion, wahl);
  final sperren = <String>[
    if (auftrag.kampfmittel != null && profil == null)
      'Gewähltes Kampfmittel inzwischen nicht mehr geführt.',
    if (profil != null) ...profil.sperren,
    if (profil != null &&
        (relevanteAktion == Gefechtsaktion.parade ||
            relevanteAktion == Gefechtsaktion.schildparade) &&
        profil.pa == null)
      'Keine Parade mit diesem Kampfmittel.',
  ];
  final w = gefechtswerteFuer(snapshot, katalog: katalog, kampfmittel: wahl);
  if (auftrag.aktion == Gefechtsaktion.zusatzaktion) {
    return pruefeGefechtsZusatzauftrag(
      zustand,
      snapshot,
      katalog,
      auftrag,
      wahl,
      eigenerAuftrag: eigenerAuftrag,
    );
  }
  final m = auftrag.manoever;
  Gefechtspruefung p;
  if (m != null) {
    p = pruefeGefechtsmanoever(
      zustand,
      snapshot,
      katalog,
      m,
      zuschlag: auftrag.zuschlag,
      zielwert: auftrag.zielwert,
      eigenerAuftrag: eigenerAuftrag,
      distanzSchritte: auftrag.distanzSchritte,
      kampfmittel: wahl,
    );
  } else if (auftrag.manuell || auftrag.probe != null) {
    p = pruefeManuelleGefechtsaktion(
      zustand,
      w,
      kosten: auftrag.kosten,
      zielwert: auftrag.zielwert,
      eigenerAuftrag: eigenerAuftrag,
      gruende: ['Zielwert, Dauer, Kosten und Wirkungen manuell bestätigt.'],
      zuschlag: auftrag.zuschlag,
    );
  } else {
    p = pruefeGefechtsaktion(
      zustand,
      w,
      relevanteAktion,
      zuschlag: auftrag.zuschlag,
      manuellerZielwert: auftrag.zielwert,
      zusatzParade: auftrag.zusatzParade,
      eigenerAuftrag: eigenerAuftrag,
      distanzSchritte: auftrag.distanzSchritte,
    );
  }
  if (snapshot.wundEffekte.kampfunfaehig) {
    sperren.add('Durch Wunden kampfunfähig.');
  }
  if (m?.name.toLowerCase().contains('hammerschlag') ?? false) {
    if (s.angriffeVerbraucht > 0 ||
        s.paradenVerbraucht > 0 ||
        s.zusatzVerbraucht > 0) {
      sperren.add(
        'Hammerschlag benötigt alle ungenutzten nicht freien Aktionen.',
      );
    }
    if (auftrag.grosserGegner || auftrag.grosserSchild) {
      sperren.add('Gegner oder Schild schließt Hammerschlag aus.');
    }
    const talente = [
      'tal_anderthalbhaender',
      'tal_hiebwaffen',
      'tal_infanteriewaffen',
      'tal_kettenwaffen',
      'tal_zweihandflegel',
      'tal_zweihand_hiebwaffen',
      'tal_zweihandschwerter_saebel',
    ];
    final waffe = snapshot.hero.combatConfig.selectedWeapon;
    if (!talente.contains(waffe.talentId) ||
        waffe.name.toLowerCase().contains('nachtwind')) {
      sperren.add('Waffe für Hammerschlag ungeeignet.');
    }
    return Gefechtspruefung(
      aktion: p.aktion,
      status: sperren.isNotEmpty || p.status == Gefechtsfreigabe.gesperrt
          ? Gefechtsfreigabe.gesperrt
          : Gefechtsfreigabe.pruefen,
      gruende: [...sperren, ...p.gruende],
      sperrgruende: [...sperren, ...p.sperrgruende],
      fehlendeAngaben: p.fehlendeAngaben,
      entscheidungen: p.entscheidungen,
      hinweise: p.hinweise,
      modifikatoren: p.modifikatoren,
      kampfmittel: wahl,
      ausruestungspaar: gefechtsAusruestungspaar(snapshot),
      mitAnsage: true,
      zielwert: p.zielwert,
      angriffe: gefechtsAngriffe(s),
      paraden: s.umwandlung == Gefechtsumwandlung.zweiteAttacke
          ? 0
          : s.umwandlung == Gefechtsumwandlung.zweiteParade
          ? 2
          : 1,
      zusatz: w.zusatzaktionen,
      erschwernis: p.erschwernis,
    );
  }
  if (m != null &&
      auftrag.kosten != 1 &&
      sperren.isEmpty &&
      p.status != Gefechtsfreigabe.gesperrt) {
    final kosten = pruefeManuelleGefechtsaktion(
      zustand,
      w,
      kosten: auftrag.kosten,
      eigenerAuftrag: eigenerAuftrag,
    );
    return Gefechtspruefung(
      aktion: p.aktion,
      status: kosten.status,
      gruende: [...p.gruende, ...kosten.gruende],
      sperrgruende: [...p.sperrgruende, ...kosten.sperrgruende],
      fehlendeAngaben: p.fehlendeAngaben,
      entscheidungen: p.entscheidungen,
      hinweise: p.hinweise,
      modifikatoren: p.modifikatoren,
      kampfmittel: wahl,
      ausruestungspaar: gefechtsAusruestungspaar(snapshot),
      mitAnsage: true,
      zielwert: p.zielwert,
      angriffe: kosten.angriffe,
      paraden: kosten.paraden,
      erschwernis: p.erschwernis,
    );
  }
  if (sperren.isEmpty) {
    return gefechtsPruefungMitKampfmittel(p, snapshot, auftrag, wahl);
  }
  return Gefechtspruefung(
    aktion: p.aktion,
    status: Gefechtsfreigabe.gesperrt,
    gruende: [...sperren, ...p.gruende],
    sperrgruende: [...sperren, ...p.sperrgruende],
    fehlendeAngaben: p.fehlendeAngaben,
    entscheidungen: p.entscheidungen,
    hinweise: p.hinweise,
    modifikatoren: p.modifikatoren,
    kampfmittel: wahl,
    ausruestungspaar: gefechtsAusruestungspaar(snapshot),
    mitAnsage: auftrag.manoever != null || auftrag.zuschlag != 0,
    zielwert: p.zielwert,
    angriffe: p.angriffe,
    paraden: p.paraden,
    freie: p.freie,
    zusatz: p.zusatz,
    erschwernis: p.erschwernis,
  );
}
