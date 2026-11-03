/// Magisches Meisterhandwerk (WdH S. 256, WdZ S. 37).
///
/// Der Zauberer setzt bei Proben auf bis zu fünf gewählte Talente AsP ein:
/// vorab zwei Punkte TaW je AsP (höchstens bis zum doppelten TaW, der Rest
/// bleibt als TaP*), nachträglich ein AsP je fehlendem TaP, um eine
/// misslungene Probe zu retten, oder ein AsP je TaP*, um eine gelungene zu
/// verbessern (bis zu ihren TaP*; darüber hinaus bis zum TaW je TaP* zwei
/// AsP und ein Punkt Erschöpfung). Die Talente kommen ausschließlich über die
/// Wirkung `meisterhandwerk` aus [werteMerkmaleAus].
library;

import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_herleitung_rules.dart';

/// Höchstzahl der Meisterhandwerk-Talente eines Helden (WdH S. 256).
const int kMeisterhandwerkMaxTalente = 5;

/// Quellenangabe für Herleitung und Hinweise.
const String kMeisterhandwerkQuelle = 'WdH S. 256, WdZ S. 37';

/// Meisterhandwerk-Wirkungen von [hero] in Eintragsreihenfolge.
List<MeisterhandwerkWirkung> meisterhandwerkWirkungen(
  HeroSheet hero, {
  required RulesCatalog? catalog,
}) {
  return werteMerkmaleAus(hero, catalog: catalog).wirkungen.meisterhandwerk;
}

/// Ob die Vorteilsliste [vorteile] mehr Meisterhandwerk-Talente trägt, als
/// erlaubt sind (über alle drei Varianten gezählt).
///
/// Ohne Katalog wirkt kein Meisterhandwerk; dann ist nichts überschritten.
bool meisterhandwerkGrenzeUeberschritten(
  List<HeroMerkmal> vorteile, {
  required RulesCatalog? catalog,
}) {
  if (catalog == null) {
    return false;
  }
  final ergebnis = berechneMerkmalWirkungen(
    vorteile: vorteile,
    nachteile: const <HeroMerkmal>[],
    katalog: MerkmalKatalog.von(catalog),
  );
  return ergebnis.wirkungen.meisterhandwerk.length > kMeisterhandwerkMaxTalente;
}

/// Was Meisterhandwerk bei einer konkreten Talentprobe erlaubt.
class MeisterhandwerkAngebot {
  /// Erstellt ein Angebot.
  const MeisterhandwerkAngebot({
    required this.talent,
    required this.taw,
    required this.verfuegbareAsp,
    required this.quelle,
  });

  /// Name des Talents der Probe.
  final String talent;

  /// Talentwert (ohne Modifikatoren) aus der Pool-Herleitung.
  final int taw;

  /// AsP, die beim Öffnen der Probe gespeichert waren.
  final int verfuegbareAsp;

  /// Kurztext des Vorteils, z. B. `Meisterhandwerk Schmieden`.
  final String quelle;

  /// Kopie mit anderem AsP-Vorrat (nach einer Buchung im Dialog).
  MeisterhandwerkAngebot mitAsp(int asp) => MeisterhandwerkAngebot(
    talent: talent,
    taw: taw,
    verfuegbareAsp: asp,
    quelle: quelle,
  );
}

/// Das Meisterhandwerk-Angebot für die Probe [request].
///
/// `null` für andere Probenarten, Ersatzproben, Talente ohne Meisterhandwerk,
/// ohne Pool-Herleitung, bei TaW ≤ 0 oder ohne AsP.
MeisterhandwerkAngebot? meisterhandwerkAngebotFuer({
  required ResolvedProbeRequest request,
  required List<MeisterhandwerkWirkung> wirkungen,
  required int verfuegbareAsp,
}) {
  if (wirkungen.isEmpty || verfuegbareAsp <= 0) {
    return null;
  }
  final talent = talentNameAusProbe(request);
  final herleitung = request.poolHerleitung;
  if (talent == null || herleitung == null) {
    return null;
  }
  final schluessel = normalizeSpecialAbilityName(talent);
  MeisterhandwerkWirkung? treffer;
  for (final wirkung in wirkungen) {
    if (normalizeSpecialAbilityName(wirkung.auswahl) == schluessel) {
      treffer = wirkung;
      break;
    }
  }
  if (treffer == null) {
    return null;
  }
  final taw = herleitung.schritte
      .where(
        (s) =>
            s.art == HerleitungsArt.zukauf &&
            s.bezeichnung == kTalentTawSchritt,
      )
      .fold<int>(0, (summe, s) => summe + s.betrag);
  if (taw <= 0) {
    return null;
  }
  return MeisterhandwerkAngebot(
    talent: talent,
    taw: taw,
    verfuegbareAsp: verfuegbareAsp,
    quelle: treffer.quelle,
  );
}

/// Höchster AsP-Einsatz vor dem Wurf: zwei TaW je AsP, höchstens bis zum
/// doppelten TaW, und nicht mehr als vorhanden.
int meisterhandwerkMaxVorabAsp(MeisterhandwerkAngebot angebot) {
  return math.max(0, math.min(angebot.taw ~/ 2, angebot.verfuegbareAsp));
}

/// Die Probe [request] mit [asp] vorab eingesetzten AsP (+2 TaW je AsP).
///
/// Der Beitrag erhöht `basePool` und erscheint als eigener Schritt in der
/// `poolHerleitung`. Bei [asp] ≤ 0 kommt dieselbe Instanz zurück.
ResolvedProbeRequest wendeMeisterhandwerkVorabAn(
  ResolvedProbeRequest request,
  int asp,
) {
  if (asp <= 0) {
    return request;
  }
  final betrag = 2 * asp;
  final herleitung = request.poolHerleitung;
  return request.copyWith(
    basePool: request.basePool + betrag,
    poolHerleitung: herleitung == null
        ? null
        : Herleitung(
            bezeichnung: herleitung.bezeichnung,
            schritte: <HerleitungsSchritt>[
              ...herleitung.schritte,
              HerleitungsSchritt(
                bezeichnung: 'Meisterhandwerk ($asp AsP)',
                betrag: betrag,
                art: HerleitungsArt.modifikator,
                formel: '2 TaW je AsP',
                quelle: kMeisterhandwerkQuelle,
              ),
            ],
          ),
  );
}

/// Art des nachträglichen Meisterhandwerk-Einsatzes.
enum MeisterhandwerkNachtragArt {
  /// Misslungene Probe wird zum knappen Erfolg (TaP* 0).
  rettung,

  /// Gelungene Probe erhält zusätzliche TaP*.
  verbesserung,
}

/// Nachträglich möglicher Einsatz für ein Probenergebnis.
class MeisterhandwerkNachtrag {
  /// Erstellt die Möglichkeiten eines Nachtrags.
  const MeisterhandwerkNachtrag({
    required this.art,
    required this.rettungsKosten,
    required this.guenstigePunkte,
    required this.teurePunkte,
  });

  /// Rettung oder Verbesserung.
  final MeisterhandwerkNachtragArt art;

  /// AsP für die Rettung (fehlende TaP); 0 bei einer Verbesserung.
  final int rettungsKosten;

  /// TaP*, die je 1 AsP kosten (höchstens so viele, wie die Probe TaP* hat).
  final int guenstigePunkte;

  /// Weitere TaP* bis zum TaW, je 2 AsP und 1 Erschöpfung.
  final int teurePunkte;

  /// Höchstzahl zusätzlicher TaP* einer Verbesserung.
  int get maxPunkte => guenstigePunkte + teurePunkte;
}

/// Kosten eines nachträglichen Einsatzes.
typedef MeisterhandwerkKosten = ({int asp, int erschoepfung});

/// Was [result] nachträglich mit höchstens [verfuegbareAsp] AsP erlaubt.
///
/// `null` bei einem Patzer, ohne Kompensationspool, wenn mehr TaP fehlen als
/// der TaW beträgt oder die AsP nicht reichen, und wenn nichts mehr zu
/// verbessern ist.
MeisterhandwerkNachtrag? meisterhandwerkNachtragFuer({
  required ProbeResult result,
  required MeisterhandwerkAngebot angebot,
  required int verfuegbareAsp,
}) {
  if (!result.request.usesCompensationPool ||
      result.automaticOutcome == AutomaticOutcome.failure ||
      verfuegbareAsp <= 0) {
    return null;
  }
  if (!result.success) {
    final fehlend = -result.remainingPool;
    if (fehlend <= 0 || fehlend > angebot.taw || fehlend > verfuegbareAsp) {
      return null;
    }
    return MeisterhandwerkNachtrag(
      art: MeisterhandwerkNachtragArt.rettung,
      rettungsKosten: fehlend,
      guenstigePunkte: 0,
      teurePunkte: 0,
    );
  }
  final tapStern = math.max(0, result.remainingPool);
  final guenstig = math.min(tapStern, verfuegbareAsp);
  final restAsp = verfuegbareAsp - guenstig;
  final bisTaw = math.max(0, angebot.taw - tapStern - guenstig);
  // Teure Punkte gibt es erst, wenn die günstigen ausgeschöpft sind; reichen
  // die AsP dafür nicht, bleibt [restAsp] 0.
  final teuer = math.min(bisTaw, restAsp ~/ 2);
  if (guenstig + teuer <= 0) {
    return null;
  }
  return MeisterhandwerkNachtrag(
    art: MeisterhandwerkNachtragArt.verbesserung,
    rettungsKosten: 0,
    guenstigePunkte: guenstig,
    teurePunkte: teuer,
  );
}

/// Kosten von [punkte] zusätzlichen TaP* (Verbesserung) bzw. der Rettung.
MeisterhandwerkKosten meisterhandwerkNachtragKosten(
  MeisterhandwerkNachtrag nachtrag,
  int punkte,
) {
  if (nachtrag.art == MeisterhandwerkNachtragArt.rettung) {
    return (asp: nachtrag.rettungsKosten, erschoepfung: 0);
  }
  final gewaehlt = punkte.clamp(0, nachtrag.maxPunkte);
  final guenstig = math.min(gewaehlt, nachtrag.guenstigePunkte);
  final teuer = gewaehlt - guenstig;
  return (asp: guenstig + 2 * teuer, erschoepfung: teuer);
}

/// Das Ergebnis [result] nach dem nachträglichen Einsatz.
///
/// Eine Rettung macht die Probe zum knappen Erfolg (TaP* 0); eine
/// Verbesserung erhöht die TaP* um [punkte] (gekappt auf das Erlaubte).
ProbeResult wendeMeisterhandwerkNachtragAn(
  ProbeResult result,
  MeisterhandwerkNachtrag nachtrag,
  int punkte,
) {
  final rettung = nachtrag.art == MeisterhandwerkNachtragArt.rettung;
  final rest = rettung
      ? 0
      : math.max(0, result.remainingPool) + punkte.clamp(0, nachtrag.maxPunkte);
  return ProbeResult(
    request: result.request,
    input: result.input,
    diceValues: result.diceValues,
    effectiveTargetValues: result.effectiveTargetValues,
    targetOverflows: result.targetOverflows,
    compensationPoolStart: result.compensationPoolStart,
    remainingPool: rest,
    appliedAttributePenalty: result.appliedAttributePenalty,
    total: result.total,
    success: true,
    automaticOutcome: result.automaticOutcome,
    specialExperience: result.specialExperience,
    usedFixedRollTotal: result.usedFixedRollTotal,
  );
}

/// Eine zu buchende Meisterhandwerk-Verwendung (AsP und Erschöpfung).
class MeisterhandwerkBuchung {
  /// Erstellt eine Buchung.
  const MeisterhandwerkBuchung({
    required this.talent,
    required this.asp,
    required this.beschreibung,
    this.erschoepfung = 0,
  });

  /// Talent der Probe.
  final String talent;

  /// Abzuziehende AsP.
  final int asp;

  /// Hinzukommende Erschöpfung.
  final int erschoepfung;

  /// Kurzbeschreibung für das Protokoll, z. B. `3 AsP vorab (+6 TaW)`.
  final String beschreibung;
}

/// Buchung eines Vorab-Einsatzes von [asp] AsP.
MeisterhandwerkBuchung meisterhandwerkVorabBuchung(
  MeisterhandwerkAngebot angebot,
  int asp,
) {
  return MeisterhandwerkBuchung(
    talent: angebot.talent,
    asp: asp,
    beschreibung: '$asp AsP vorab (+${2 * asp} TaW)',
  );
}

/// Buchung eines nachträglichen Einsatzes.
MeisterhandwerkBuchung meisterhandwerkNachtragBuchung(
  MeisterhandwerkAngebot angebot,
  MeisterhandwerkNachtrag nachtrag,
  int punkte,
) {
  final kosten = meisterhandwerkNachtragKosten(nachtrag, punkte);
  final beschreibung = switch (nachtrag.art) {
    MeisterhandwerkNachtragArt.rettung => '${kosten.asp} AsP: Probe gerettet',
    MeisterhandwerkNachtragArt.verbesserung =>
      'TaP* +${punkte.clamp(0, nachtrag.maxPunkte)}: ${kosten.asp} AsP'
          '${kosten.erschoepfung > 0 ? ', ${kosten.erschoepfung} Erschöpfung' : ''}',
  };
  return MeisterhandwerkBuchung(
    talent: angebot.talent,
    asp: kosten.asp,
    erschoepfung: kosten.erschoepfung,
    beschreibung: beschreibung,
  );
}
