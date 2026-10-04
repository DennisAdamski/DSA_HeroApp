import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'combat_special_ability_state.dart';
import 'excel_rounding.dart';
import 'gefecht_kampfmittel_rules.dart';
import 'maneuver_rules.dart';

/// WdS 69: nächste Angriffs-/Abwehraktion, keine freie Ausweich-/Hilfsaktion.
bool gefechtsMeisterparadeBonusPasst(GefechtAuftrag a, Gefechtspruefung p) {
  final art = a.manuell ? a.manuelleKampfaktion : p.probenart ?? p.aktion;
  return art == Gefechtsaktion.angriff ||
      art == Gefechtsaktion.parade ||
      art == Gefechtsaktion.schildparade ||
      art == Gefechtsaktion.gezieltesAusweichen ||
      art == Gefechtsaktion.zusatzaktion;
}

/// Ergänzt eigene Ansage und alten Erfolgsbonus genau einmal im gemeinsamen Pfad.
Gefechtspruefung ergaenzeGefechtsMeisterparade(
  Gefechtspruefung p,
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  RulesCatalog k,
  GefechtAuftrag a,
) {
  final mp = a.manoever?.id == 'man_meisterparade';
  final sperren = [...p.sperrgruende];
  final fehlend = [...p.fehlendeAngaben];
  final hinweise = [...p.hinweise];
  final mods = [...p.modifikatoren];
  if (a.meisterparadeAnsage < 0) {
    sperren.add('Meisterparade-Ansage darf nicht negativ sein.');
  }
  if (!mp && a.meisterparadeAnsage != 0) {
    sperren.add('Meisterparade-Ansage benötigt das Manöver Meisterparade.');
  }
  final manuelleKampfaktion = a.manuelleKampfaktion;
  final manuelleAbwicklung = a.manuell && a.probe == null;
  final erlaubteEinordnung = [
    Gefechtsaktion.angriff,
    Gefechtsaktion.parade,
    Gefechtsaktion.handlung,
  ].contains(manuelleKampfaktion);
  final einzelabschluss =
      manuelleKampfaktion == Gefechtsaktion.handlung || a.dauer == 1;
  if (manuelleKampfaktion != null &&
      (!manuelleAbwicklung || !einzelabschluss || !erlaubteEinordnung)) {
    sperren.add(
      'Manuelle Kampfeinordnung gilt nur für einen bestätigten Einzelabschluss ohne Fachprobe.',
    );
  }
  if (mp) {
    final profil = gefechtsKampfmittelFuer(snap, p.kampfmittel);
    final talent = profil?.waffe?.talentId;
    final gelernt = learnedManeuverIds(snap.hero.combatConfig, k);
    if (!gelernt.contains('man_meisterparade') &&
        !gelernt.contains('man_meisterparade::$talent')) {
      sperren.add('Meisterparade muss erlernt sein.');
    }
    if (snap.combatPreviewStats.beKampf > 4) {
      sperren.add(
        'Meisterparade benötigt Rüstungs-BE nach Rüstungsgewöhnung höchstens 4.',
      );
    }
    final schild = p.kampfmittel?.art == GefechtsKampfmittelArt.schild;
    // Der bekannte WM-Verlust verändert die tatsächliche Schild-PA; gegnerische
    // Finte, Haltung und weitere Situationszuschläge verändern die Grenze nicht.
    final schildAbzug = p.modifikatoren
        .where((m) => m.name == 'Schild-WM entfällt')
        .fold<int>(0, (summe, m) => summe + m.wert);
    final pa = profil?.pa == null ? null : profil!.pa! - schildAbzug;
    int? grenze;
    if (schild) {
      if (!isCombatSpecialAbilityActive(
        snap.hero.combatConfig,
        'ksf_schildkampf_ii',
      )) {
        sperren.add('Meisterparade mit Schild benötigt Schildkampf II.');
      }
      grenze = a.schildAnsagegrenze;
      if (grenze != null && grenze < 0) {
        sperren.add('Zulässige Schild-Ansagegrenze darf nicht negativ sein.');
      }
      if (a.meisterparadeAnsage > 0 && grenze == null) {
        fehlend.add(
          'Zulässige Schild-Ansagegrenze am Tisch bestimmen und als Zahl '
          'eintragen; ein Schild hat keinen eigenen TaW.',
        );
      }
    } else {
      if (talent == 'tal_kettenwaffen' || talent == 'tal_zweihandflegel') {
        sperren.add(
          'Meisterparade ist mit Kettenwaffen und Zweihandflegeln verboten.',
        );
      }
      grenze = snap.hero.talents[talent]?.talentValue;
      if (grenze == null || grenze < 0 || talent == null || talent.isEmpty) {
        fehlend.add(
          'Gültigen TaW der tatsächlich verwendeten Waffe für die Meisterparade bestimmen.',
        );
      }
    }
    if (pa == null || pa < 0) {
      fehlend.add(
        'Gültige PA der tatsächlich verwendeten Waffe oder des Schilds fehlt.',
      );
    }
    if ((grenze != null && a.meisterparadeAnsage > grenze) ||
        (pa != null && a.meisterparadeAnsage > pa)) {
      final grenzname = schild ? 'Schildgrenze' : 'TaW';
      final grenztext = grenze?.toString() ?? '?';
      final patext = pa?.toString() ?? '?';
      sperren.add(
        'Meisterparade-Ansage höchstens $grenzname $grenztext und PA $patext '
        'vor Ansage, Finte und Situationszuschlägen.',
      );
    }
    if (p.aktion != Gefechtsaktion.parade &&
        p.aktion != Gefechtsaktion.schildparade) {
      sperren.add('Meisterparade benötigt eine tatsächliche Parade.');
    }
    if (a.manuell || a.probe != null || a.dauer != 1 || a.kosten != 1) {
      sperren.add(
        'Meisterparade wird als einzelne PA-Probe mit einer Abwehraktion gebucht.',
      );
    }
    mods.add(
      Gefechtsmodifikator('Meisterparade-Ansage', a.meisterparadeAnsage),
    );
    hinweise.add(
      'Meisterparade: bei Erfolg einmalig ${a.meisterparadeAnsage} Punkte '
      'Erleichterung für die nächste Angriffs- oder Abwehraktion; '
      'keine zusätzlichen TP.',
    );
  }
  final bonus = gefechtsMeisterparadeBonusPasst(a, p)
      ? s.meisterparadeBonus
      : 0;
  if (bonus > 0) mods.add(Gefechtsmodifikator('Meisterparade-Bonus', -bonus));
  final delta = (mp ? a.meisterparadeAnsage : 0) - bonus;
  return Gefechtspruefung(
    aktion: p.aktion,
    status: sperren.isNotEmpty
        ? Gefechtsfreigabe.gesperrt
        : fehlend.isNotEmpty
        ? Gefechtsfreigabe.pruefen
        : p.status,
    gruende: [...sperren, ...fehlend, ...p.entscheidungen, ...hinweise],
    sperrgruende: sperren,
    fehlendeAngaben: fehlend,
    entscheidungen: p.entscheidungen,
    hinweise: hinweise,
    zielwert: p.zielwert == null ? null : p.zielwert! - delta,
    erschwernis: p.erschwernis + delta,
    modifikatoren: mods,
    angriffe: p.angriffe,
    paraden: p.paraden,
    freie: p.freie,
    zusatz: p.zusatz,
    kampfmittel: p.kampfmittel,
    ausruestungspaar: p.ausruestungspaar,
    mitAnsage: p.mitAnsage || mp,
    probenart: p.probenart,
    meisterparadeAnsage: mp ? a.meisterparadeAnsage : 0,
    verbrauchterMeisterparadeBonus: bonus,
  );
}

/// Verbrauch und neuer Bonus entstehen ausschließlich beim gebuchten Abschluss.
int gefechtsMeisterparadeBonusNachBuchung(
  Gefechtszustand s,
  Gefechtspruefung p,
  bool? erfolg,
) {
  final rest = p.verbrauchterMeisterparadeBonus > 0 ? 0 : s.meisterparadeBonus;
  return erfolg == true && p.meisterparadeAnsage > 0
      ? p.meisterparadeAnsage
      : rest;
}

/// WdS 59/69: konkrete manuelle Fehlmanöverfolge ohne globale Malusautomation.
String gefechtsMeisterparadeFehlschlag(
  GefechtAuftrag a,
  HeroComputedSnapshot snap,
) {
  final gesamt = a.meisterparadeAnsage;
  final halbiert = isCombatSpecialAbilityActive(
    snap.hero.combatConfig,
    'ksf_klingentaenzer',
  );
  final malus = halbiert ? excelRound(gesamt / 2) : gesamt;
  final halbierung = halbiert
      ? ' (Klingentänzer: halbe Ansage, aufgerundet)'
      : '';
  return 'Meisterparade mit Ansage +$gesamt misslungen: Der Angriff trifft. '
      'Kein Erfolgsbonus. Folgemalus +$malus$halbierung '
      'manuell auf alle Proben, einschließlich freier Aktionen, bis einschließlich '
      'der nächsten eigenen AT oder PA anwenden. Orientieren beendet den Malus. '
      'Weitere Folgen des gegnerischen Treffers am Tisch abwickeln (WdS 59/69).';
}
