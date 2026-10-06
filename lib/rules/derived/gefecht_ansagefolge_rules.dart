import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_held_rules.dart';
import 'gefecht_kampfmittel_rules.dart';
import 'excel_rounding.dart';

/// WdS 60: freiwillige und eindeutig geforderte Nahkampfansage, ohne Umfeldmali.
int gefechtsAnsageFehlmalus(HeroComputedSnapshot snap, GefechtAuftrag a) {
  final w = gefechtswerteFuer(snap, kampfmittel: a.kampfmittel);
  if (w.fernkampf || a.manuell || a.probe != null) return 0;
  final m = a.manoever;
  var gesamt = a.finte + a.wuchtschlag + a.meisterparadeAnsage;
  final reduktionen = a.kampfmittel?.art == GefechtsKampfmittelArt.nebenwaffe
      ? snap.combatPreviewStats.offhandPreview?.waffenmeisterManeuverReductions
      : snap.combatPreviewStats.waffenmeisterManeuverReductions;
  if (m != null) {
    final schild = gefechtsSchildmanoever(snap, m.name);
    gesamt +=
        gefechtsManoeverZuschlag(m) +
        schild.zuschlag -
        (reduktionen?[m.id] ?? 0);
  }
  for (final e in [
    ('Finte', 'man_finte', a.finte),
    ('Wuchtschlag', 'man_wuchtschlag', a.wuchtschlag),
  ]) {
    if (e.$3 > 0 && m?.id != e.$2) {
      final schild = gefechtsSchildmanoever(snap, e.$1);
      gesamt +=
          (m?.id == 'man_ausfall' ? 0 : schild.zuschlag) -
          (reduktionen?[e.$2] ?? 0);
    }
  }
  if (gesamt <= 0) return 0;
  return w.klingentaenzerAktiv ? excelRound(gesamt / 2) : gesamt;
}

/// Ergänzt Zielwert und Buchungsmetadaten nach allen eigenen Ansagen genau einmal.
Gefechtspruefung ergaenzeGefechtsAnsagefolge(
  Gefechtspruefung p,
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  GefechtAuftrag a,
) {
  final art = a.manuell ? a.manuelleKampfaktion : p.probenart ?? p.aktion;
  final freigestellt =
      a.probe?.type == ProbeType.damage ||
      a.probe?.type == ProbeType.initiative;
  final kampf =
      !freigestellt &&
      (art == Gefechtsaktion.angriff ||
          art == Gefechtsaktion.parade ||
          art == Gefechtsaktion.schildparade ||
          art == Gefechtsaktion.gezieltesAusweichen ||
          art == Gefechtsaktion.zusatzaktion);
  final probeJetzt =
      a.probe == null || a.dauer <= p.angriffe + p.paraden + p.zusatz;
  final ende = kampf && probeJetzt;
  final malus = freigestellt ? 0 : s.ansageFolgemalus;
  final zusatz = malus > 0
      ? [
          'Ansagefolgemalus +$malus bis einschließlich nächster AT/PA; Orientieren beendet ihn.',
        ]
      : <String>[];
  return Gefechtspruefung(
    aktion: p.aktion,
    status: p.status,
    gruende: [...p.gruende, ...zusatz],
    sperrgruende: p.sperrgruende,
    fehlendeAngaben: p.fehlendeAngaben,
    entscheidungen: p.entscheidungen,
    hinweise: [...p.hinweise, ...zusatz],
    zielwert: p.zielwert == null ? null : p.zielwert! - malus,
    erschwernis: p.erschwernis + malus,
    modifikatoren: [
      ...p.modifikatoren,
      if (malus > 0) Gefechtsmodifikator('Ansagefolgemalus', malus),
    ],
    angriffe: p.angriffe,
    paraden: p.paraden,
    freie: p.freie,
    zusatz: p.zusatz,
    kampfmittel: p.kampfmittel,
    ausruestungspaar: p.ausruestungspaar,
    mitAnsage: p.mitAnsage,
    probenart: p.probenart,
    meisterparadeAnsage: p.meisterparadeAnsage,
    verbrauchterMeisterparadeBonus: p.verbrauchterMeisterparadeBonus,
    ansageFehlmalus: kampf ? gefechtsAnsageFehlmalus(snap, a) : 0,
    beendetAnsageFolgemalus: ende,
  );
}

/// Ein echter Abschluss tilgt den alten, dann setzt er gegebenenfalls einen neuen Malus.
int gefechtsAnsageFolgemalusNachBuchung(
  Gefechtszustand s,
  Gefechtspruefung p,
  bool? erfolg,
) {
  final rest = p.beendetAnsageFolgemalus ? 0 : s.ansageFolgemalus;
  return erfolg == false && p.ansageFehlmalus > 0 ? p.ansageFehlmalus : rest;
}

/// Fach- und freie Proben erhalten denselben Malus über den bestehenden Probenzuschlag.
ResolvedProbeRequest gefechtsProbeMitAnsagefolgemalus(
  ResolvedProbeRequest p,
  int malus,
) {
  if (malus == 0 ||
      p.type == ProbeType.damage ||
      p.type == ProbeType.initiative) {
    return p;
  }
  return ResolvedProbeRequest(
    type: p.type,
    title: p.title,
    subtitle: p.subtitle,
    ruleHint: '${p.ruleHint} Ansagefolgemalus +$malus.',
    diceSpec: p.diceSpec,
    targets: p.targets,
    basePool: p.basePool,
    specializationBonus: p.specializationBonus,
    initialSpecializationApplied: p.initialSpecializationApplied,
    initialSituationalModifier: p.initialSituationalModifier - malus,
    fixedRollTotal: p.fixedRollTotal,
  );
}
