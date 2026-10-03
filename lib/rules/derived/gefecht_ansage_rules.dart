import 'dart:convert';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_held_rules.dart';
import 'gefecht_kampfmittel_rules.dart';
import 'maneuver_rules.dart';
import 'excel_rounding.dart';
import 'gefecht_rules.dart';

/// Belegte Kombination, bekanntes Verbot oder einzelne Entscheidung am Tisch.
enum GefechtsAnsagekombination { erlaubt, verboten, klaeren }

/// Bindet Zielzeit an das komplette bestätigte Waffen- und Geschossprofil.
/// Paket 3 übernimmt diesen Schlüssel beim tatsächlichen Bezahlen der Zielzeit.
String gefechtsZielprofilKey(MainWeaponSlot waffe) =>
    jsonEncode(waffe.toJson());

/// Kleine explizite Tabelle statt Freigaben aus Beschreibungsschlagwörtern.
/// WdS 62/64/66; Sturmangriff zusätzlich gemäß genehmigtem Gefechtsumfang.
GefechtsAnsagekombination gefechtsAnsagekombination(
  String? manoeverId, {
  required bool finte,
  required bool wuchtschlag,
  bool fernkampfansage = false,
}) {
  if (!finte && !wuchtschlag && !fernkampfansage) {
    return GefechtsAnsagekombination.erlaubt;
  }
  if (manoeverId == null) return GefechtsAnsagekombination.erlaubt;
  if (fernkampfansage && manoeverId == 'man_gezielter_schuss') {
    return GefechtsAnsagekombination.verboten;
  }
  if (fernkampfansage) return GefechtsAnsagekombination.klaeren;
  const erlaubt = {'man_finte', 'man_wuchtschlag', 'man_sturmangriff'};
  const verboten = {'man_doppelangriff', 'man_klingensturm', 'man_eisenhagel'};
  if (erlaubt.contains(manoeverId)) return GefechtsAnsagekombination.erlaubt;
  if (verboten.contains(manoeverId)) return GefechtsAnsagekombination.verboten;
  return GefechtsAnsagekombination.klaeren;
}

/// Konkrete WdS-98-Anforderung, unabhängig vom allgemeinen optionalen Zielen.
class GefechtsFernkampfansage {
  /// Enthält Obergrenze, Erfolgsbonus und zusätzlich zu bezahlende Zielzeit.
  const GefechtsFernkampfansage(this.grenze, this.tpBonus, this.zielaktionen);
  final int grenze, tpBonus, zielaktionen;
}

/// Rundet halbe Ansagen echt auf; Scharfschützen sparen zwei Zielaktionen.
GefechtsFernkampfansage gefechtsFernkampfansage(
  int ansage, {
  required int taw,
  required int fk,
  bool scharfschuetze = false,
  bool meisterschuetze = false,
}) {
  final halb = excelRound(ansage / 2);
  final reduziert = halb - 2;
  return GefechtsFernkampfansage(
    meisterschuetze ? fk : taw,
    scharfschuetze || meisterschuetze ? ansage : halb,
    ansage == 0
        ? 0
        : meisterschuetze
        ? 1
        : scharfschuetze
        ? (reduziert < 1 ? 1 : reduziert)
        : halb,
  );
}

/// Wirksame Folgen werden getrennt von der tatsächlich angesagten Erschwernis.
({int abwehrmalus, int tpBonus}) gefechtsAnsagewirkung(
  HeroComputedSnapshot snap,
  RulesCatalog k,
  GefechtAuftrag a,
) {
  final wahl = a.kampfmittel ?? gefechtsStandardKampfmittel(snap, a.aktion);
  final w = gefechtswerteFuer(snap, katalog: k, kampfmittel: wahl);
  final gelernt = learnedManeuverIds(snap.hero.combatConfig, k);
  bool kennt(String id) =>
      gelernt.contains(id) || gelernt.contains('$id::${w.waffe?.talentId}');
  final finte = kennt('man_finte') ? a.finte : excelRound(a.finte / 2);
  var tp = kennt('man_wuchtschlag')
      ? a.wuchtschlag
      : excelRound(a.wuchtschlag / 2);
  if (a.fernkampfansage > 0) {
    tp += gefechtsFernkampfansage(
      a.fernkampfansage,
      taw: snap.hero.talents[w.waffe?.talentId]?.talentValue ?? 0,
      fk: w.at,
      scharfschuetze: w.scharfschuetze,
      meisterschuetze: w.meisterschuetze,
    ).tpBonus;
  }
  if (a.manoever?.id == 'man_sturmangriff') {
    tp += 4 + excelRound(snap.derivedStats.gs / 2);
  }
  return (abwehrmalus: finte, tpBonus: tp);
}

/// Ergänzt Ansagen genau einmal und bewahrt sämtliche Budget-/Freigabemetadaten.
Gefechtspruefung ergaenzeGefechtsansagen(
  Gefechtspruefung p,
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  RulesCatalog k,
  GefechtAuftrag a,
) {
  final w = gefechtswerteFuer(snap, katalog: k, kampfmittel: p.kampfmittel);
  final sperren = [...p.sperrgruende];
  final fehlend = [...p.fehlendeAngaben];
  final entscheidungen = [...p.entscheidungen];
  final hinweise = [...p.hinweise];
  final mods = <Gefechtsmodifikator>[];
  final nah = a.finte > 0 || a.wuchtschlag > 0;
  final fk = a.fernkampfansage > 0;
  final angreifen =
      p.aktion == Gefechtsaktion.angriff ||
      p.aktion == Gefechtsaktion.zusatzaktion && !a.zusatzParade;
  if ([a.finte, a.wuchtschlag, a.fernkampfansage].any((v) => v < 0)) {
    sperren.add('Ansagen dürfen nicht negativ sein.');
  }
  if ((nah || fk) && !angreifen) {
    sperren.add('Ansagen benötigen einen Angriff.');
  }
  if (nah && w.fernkampf || fk && !w.fernkampf) {
    sperren.add('Ansage passt nicht zur verwendeten Waffe.');
  }
  final taw = snap.hero.talents[w.waffe?.talentId]?.talentValue ?? 0;
  if (nah &&
      (a.finte + a.wuchtschlag > taw || a.finte + a.wuchtschlag > w.at)) {
    sperren.add('Gemeinsame Ansagegrenze: höchstens TaW $taw und AT ${w.at}.');
  }
  const finteVerbot = {
    'tal_kettenwaffen',
    'tal_peitschen',
    'tal_zweihandflegel',
    'tal_zweihand_hiebwaffen',
    'tal_raufen',
    'tal_ringen',
  };
  const wuchtTalente = {
    'tal_anderthalbhaender',
    'tal_hiebwaffen',
    'tal_infanteriewaffen',
    'tal_kettenstaebe',
    'tal_kettenwaffen',
    'tal_raufen',
    'tal_ringen',
    'tal_saebel',
    'tal_schwerter',
    'tal_staebe',
    'tal_zweihandflegel',
    'tal_zweihand_hiebwaffen',
    'tal_zweihandschwerter_saebel',
  };
  if (a.finte > 0 && (finteVerbot.contains(w.waffe?.talentId) || w.be > 4)) {
    sperren.add('Finte: ungeeignetes Waffentalent oder BE über 4.');
  }
  final gelernt = learnedManeuverIds(snap.hero.combatConfig, k);
  final wuchtGelernt =
      gelernt.contains('man_wuchtschlag') ||
      gelernt.contains('man_wuchtschlag::${w.waffe?.talentId}');
  final todesstosAusnahme = a.manoever?.id == 'man_todesstos' && wuchtGelernt;
  if (a.wuchtschlag > 0 &&
      !todesstosAusnahme &&
      !wuchtTalente.contains(w.waffe?.talentId)) {
    sperren.add('Wuchtschlag: ungeeignetes Waffentalent.');
  }
  if (a.manoever?.id == 'man_todesstos' && a.wuchtschlag > 0 && !wuchtGelernt) {
    sperren.add('Todesstoß mit TP-Ansage benötigt die SF Wuchtschlag.');
  }
  for (final eintrag in [
    ('Finte', 'man_finte', a.finte),
    ('Wuchtschlag', 'man_wuchtschlag', a.wuchtschlag),
  ]) {
    if (eintrag.$3 <= 0) continue;
    mods.add(Gefechtsmodifikator(eintrag.$1, eintrag.$3));
    if (!gelernt.contains(eintrag.$2) &&
        !gelernt.contains('${eintrag.$2}::${w.waffe?.talentId}')) {
      hinweise.add(
        '${eintrag.$1} ohne SF: aufgerundete halbe Wirkung (WdS 62/66).',
      );
    }
    // Das primäre Manöver hat Schild und Waffenmeister bereits angewandt.
    if (a.manoever?.id != eintrag.$2) {
      final schild = gefechtsSchildmanoever(snap, eintrag.$1);
      if (schild.zuschlag != 0 && a.manoever?.id != 'man_ausfall') {
        mods.add(
          Gefechtsmodifikator('Schild bei ${eintrag.$1}', schild.zuschlag),
        );
      }
      final reduktionen =
          p.kampfmittel?.art == GefechtsKampfmittelArt.nebenwaffe
          ? snap
                .combatPreviewStats
                .offhandPreview
                ?.waffenmeisterManeuverReductions
          : snap.combatPreviewStats.waffenmeisterManeuverReductions;
      final wm = reduktionen?[eintrag.$2] ?? 0;
      if (wm != 0) {
        mods.add(Gefechtsmodifikator('Waffenmeister ${eintrag.$1}', -wm));
      }
    }
  }
  final kombination = gefechtsAnsagekombination(
    a.manoever?.id,
    finte: a.finte > 0,
    wuchtschlag: a.wuchtschlag > 0,
    fernkampfansage: fk,
  );
  if (kombination == GefechtsAnsagekombination.verboten) {
    sperren.add('Diese Manöver-/Ansagekombination ist nicht zugelassen.');
  }
  if (kombination == GefechtsAnsagekombination.klaeren) {
    entscheidungen.add(
      'Kombination ${a.manoever!.name} mit den gewählten Ansagen regelgerecht geklärt.',
    );
  }
  if (a.manoever?.id == 'man_hammerschlag') {
    entscheidungen.add(
      'Hammerschlag: gesamte TP einschließlich TP-Ansage am Tisch verdreifachen; Bruchtest und Passierschlag geklärt.',
    );
  }
  if (a.manoever?.id == 'man_todesstos') {
    entscheidungen.add(
      'Todesstoß: halber gegnerischer RS, Schild-PA-WM, Wunden und natürlicher RS am Tisch geklärt.',
    );
  }
  if (fk) {
    final anforderung = gefechtsFernkampfansage(
      a.fernkampfansage,
      taw: taw,
      fk: w.at,
      scharfschuetze: w.scharfschuetze,
      meisterschuetze: w.meisterschuetze,
    );
    mods.add(Gefechtsmodifikator('Fernkampfansage', a.fernkampfansage));
    if (a.fernkampfansage > anforderung.grenze) {
      sperren.add('Fernkampfansage über Ansagegrenze ${anforderung.grenze}.');
    }
    final z = s.zielstand;
    final passend =
        z != null &&
        z.kampfmittel.id == p.kampfmittel?.id &&
        z.kampfmittel.art == p.kampfmittel?.art &&
        z.ansage == a.fernkampfansage &&
        z.zielkontakt == (a.kontext ?? s.kontext).kontakt &&
        z.zielkontakt.trim().isNotEmpty &&
        z.geschossId.isNotEmpty &&
        z.geschossId == w.waffe?.rangedProfile.selectedProjectileOrNull?.id &&
        w.waffe != null &&
        z.waffenprofilKey == gefechtsZielprofilKey(w.waffe!) &&
        z.bezahlteAktionen >= anforderung.zielaktionen;
    if (!passend) {
      fehlend.add(
        'FK-Ansage benötigt ${anforderung.zielaktionen} bezahlte zusätzliche Zielaktionen für diese Waffe und dieses Ziel.',
      );
    }
    hinweise.add(
      'Fernkampfansage: +${anforderung.tpBonus} TP bei Erfolg; allgemeines Zielen senkt diese Ansage nicht.',
    );
  }
  var paraden = p.paraden;
  if (a.manoever?.id == 'man_sturmangriff') {
    paraden = 1;
    if (gefechtsRegulaereParaden(s) < 1) {
      sperren.add('Sturmangriff benötigt die Abwehraktion.');
    }
    if (snap.derivedStats.gs < 4) {
      sperren.add('Sturmangriff benötigt GS mindestens 4.');
    }
    entscheidungen.add(
      'Sturmangriff: mindestens 4 Schritt freier Anlauf vorhanden.',
    );
  }
  final delta = mods.fold<int>(0, (sum, m) => sum + m.wert);
  return Gefechtspruefung(
    aktion: p.aktion,
    status: sperren.isNotEmpty ? Gefechtsfreigabe.gesperrt : p.status,
    gruende: [...sperren, ...fehlend, ...entscheidungen, ...hinweise],
    sperrgruende: sperren,
    fehlendeAngaben: fehlend,
    entscheidungen: entscheidungen,
    hinweise: hinweise,
    zielwert: p.zielwert == null ? null : p.zielwert! - delta,
    erschwernis: p.erschwernis + delta,
    modifikatoren: [...p.modifikatoren, ...mods],
    angriffe: p.angriffe,
    paraden: paraden,
    freie: p.freie,
    zusatz: p.zusatz,
    kampfmittel: p.kampfmittel,
    ausruestungspaar: p.ausruestungspaar,
    mitAnsage: p.mitAnsage || nah || fk,
    probenart: p.probenart,
  );
}
