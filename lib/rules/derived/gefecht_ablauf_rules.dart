import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';

import 'gefecht_rules.dart';

/// Prüft explizit festgelegte Kosten manueller Sonder- und Dauerhandlungen.
Gefechtspruefung pruefeManuelleGefechtsaktion(
  Gefechtszustand s,
  Gefechtswerte w, {
  required int kosten,
  int? zielwert,
  int zuschlag = 0,
  bool eigenerAuftrag = false,
  bool handlungFortsetzen = false,
  List<String> gruende = const [],
}) {
  final basis = pruefeGefechtsaktion(
    // Das explizite Budget wird unten geprüft; Grundsperren bleiben erhalten.
    s.copyWith(angriffeVerbraucht: 0, paradenVerbraucht: 0),
    w,
    Gefechtsaktion.handlung,
    manuellerZielwert: zielwert,
    eigenerAuftrag: eigenerAuftrag,
    handlungFortsetzen: handlungFortsetzen,
    pruefGruende: gruende,
  );
  var a = 0, p = 0;
  final sperren = <String>[];
  if (kosten < 0 || kosten > 2) {
    sperren.add('Kosten müssen zwischen 0 und 2 liegen.');
  }
  for (var i = 0; i < kosten; i++) {
    if (a < gefechtsAngriffe(s)) {
      a++;
    } else {
      p++;
    }
  }
  // Die zusätzliche Schildparade darf keine längere Handlung bezahlen.
  final maxP = s.umwandlung == Gefechtsumwandlung.zweiteAttacke
      ? 0
      : s.umwandlung == Gefechtsumwandlung.zweiteParade
      ? 2
      : 1;
  if (p > maxP - s.paradenVerbraucht) {
    sperren.add('Nicht genügend reguläre Aktionen.');
  }
  final grundSperren = basis.status == Gefechtsfreigabe.gesperrt;
  return Gefechtspruefung(
    aktion: Gefechtsaktion.handlung,
    status: sperren.isNotEmpty || grundSperren
        ? Gefechtsfreigabe.gesperrt
        : Gefechtsfreigabe.pruefen,
    gruende: [...sperren, ...basis.gruende],
    zielwert: zielwert == null ? null : zielwert - zuschlag,
    erschwernis: zuschlag,
    angriffe: a,
    paraden: p,
  );
}

/// Bereitet eine Probe ausschließlich aus der endgültigen Freigabe vor.
ResolvedProbeRequest gefechtsProbenauftrag(
  String titel,
  Gefechtspruefung p, {
  bool abwehrAufAttacke = false,
}) {
  final type = switch (p.aktion) {
    Gefechtsaktion.angriff => ProbeType.combatAttack,
    Gefechtsaktion.parade ||
    Gefechtsaktion.schildparade => ProbeType.combatParry,
    Gefechtsaktion.freiesAusweichen ||
    Gefechtsaktion.gezieltesAusweichen => ProbeType.dodge,
    _ => ProbeType.attribute,
  };
  return ResolvedProbeRequest(
    type: abwehrAufAttacke ? ProbeType.combatAttack : type,
    title: titel,
    subtitle: 'Gefechtsauftrag',
    ruleHint: 'Zielwert enthält bestätigte Zuschläge. ${p.gruende.join(' ')}',
    diceSpec: const DiceSpec(count: 1, sides: 20),
    targets: [ProbeTargetValue(label: titel, value: p.zielwert!)],
  );
}

/// Merkt die Restdauer nach der ersten tatsächlich verbrauchten Aktion.
Gefechtshandlung? beginneGefechtsHandlung({
  required String titel,
  required int dauer,
  String? waffenId,
  int? waffenIndex,
  ResolvedProbeRequest? probe,
  MainWeaponSlot? waffe,
  int verbraucht = 1,
}) {
  if (dauer <= verbraucht) return null;
  return Gefechtshandlung(
    titel: titel,
    verbleibend: dauer - verbraucht,
    waffenId: waffenId,
    waffenIndex: waffenIndex,
    probe: probe,
    waffe: waffe,
  );
}

/// Reduziert nur die Dauer; die aufrufende Brücke bestätigt die Abschlusswirkung.
Gefechtshandlung? setzeGefechtsHandlungFort(Gefechtshandlung h) {
  if (h.verbleibend <= 1) return null;
  return Gefechtshandlung(
    titel: h.titel,
    verbleibend: h.verbleibend - 1,
    waffenId: h.waffenId,
    waffenIndex: h.waffenIndex,
    probe: h.probe,
    waffe: h.waffe,
  );
}

/// Explizite Korrektur ist kein erneutes Umwandeln und bleibt sichtbar getrennt.
Gefechtszustand korrigiereGefecht(
  Gefechtszustand s, {
  required int iniVerlust,
  required Gefechtsumwandlung umwandlung,
  int? iniWurf,
}) => s.copyWith(
  iniVerlust: iniVerlust,
  umwandlung: umwandlung,
  iniWurf: iniWurf,
);

/// Ressourcenbereich öffnet bei Wunden oder LE unter der Hälfte automatisch.
bool gefechtDurchhaltenOeffnen({
  required bool wundAbzuege,
  required int lep,
  required int maxLep,
}) => wundAbzuege || lep * 2 <= maxLep;

/// Verbleibende freie Marken einschließlich des fixierten hohen INI-Bonus.
int gefechtFreieMarken(Gefechtszustand s, Gefechtswerte w) =>
    2 + gefechtsIniBonus(s, w) - s.freieVerbraucht;

/// Verbleibende Zusatzmarken aus den tatsächlich verfügbaren Waffenoptionen.
int gefechtZusatzMarken(Gefechtszustand s, Gefechtswerte w) =>
    w.zusatzaktionen - s.zusatzVerbraucht;

/// Berücksichtigt mehrere gleichzeitig verbrauchte reguläre Marken einer Handlung.
Gefechtshandlung? gefechtHandlungNachAuftrag({
  required String titel,
  required int dauer,
  required Gefechtspruefung pruefung,
  ResolvedProbeRequest? probe,
}) {
  final kosten = pruefung.angriffe + pruefung.paraden;
  return beginneGefechtsHandlung(
    titel: titel,
    dauer: dauer,
    verbraucht: kosten > 0 ? kosten : 1,
    probe: probe,
  );
}

/// Übernimmt bestätigte Zuschläge auch in echte Talent- und Zauberproben.
ResolvedProbeRequest? gefechtRequestFuerAuftrag(
  GefechtAuftrag auftrag,
  Gefechtspruefung p,
) {
  final original = auftrag.probe;
  if (original == null) {
    return p.zielwert == null
        ? null
        : gefechtsProbenauftrag(
            auftrag.titel,
            p,
            abwehrAufAttacke:
                auftrag.manoever?.name.toLowerCase() == 'gegenhalten',
          );
  }
  return ResolvedProbeRequest(
    type: original.type,
    title: original.title,
    subtitle: original.subtitle,
    ruleHint: original.ruleHint,
    diceSpec: original.diceSpec,
    targets: original.targets,
    basePool: original.basePool,
    specializationBonus: original.specializationBonus,
    initialSpecializationApplied: original.initialSpecializationApplied,
    initialSituationalModifier:
        original.initialSituationalModifier - auftrag.zuschlag,
    fixedRollTotal: original.fixedRollTotal,
  );
}

/// DK ist nur für Aktionen verpflichtend, die ihre automatische Rechnung benötigen.
bool gefechtAuftragBrauchtDk(GefechtAuftrag auftrag, Gefechtswerte w) =>
    auftrag.aktion == Gefechtsaktion.gezieltesAusweichen ||
    auftrag.aktion == Gefechtsaktion.angriff && !w.fernkampf;
