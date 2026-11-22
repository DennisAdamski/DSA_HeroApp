/// Proben, die am Spieltisch für ein Reittier anfallen (Reittiere P2).
///
/// Die Reiten-Probe des Helden trägt den Ausbildungsmodifikator seines
/// Reittiers (ZBA S. 35), die LO-Probe würfelt auf die wirksame Loyalität.
/// Beide sind Würfelhilfen: Auslöser und Folgen entscheidet der Meister, die
/// App bucht nichts.
library;

import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_wirkwert_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_request_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_ausbilderprobe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_ausbildung_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

/// Welche Probe die Karte eines Reittiers anbietet.
enum ReittierProbeArt {
  /// Reiten-Probe mit dem Stufenmodifikator außerhalb des Kampfes.
  reiten,

  /// Reiten-Probe mit der Kampfzeile des Stufenmodifikators.
  reitenImKampf,

  /// LO-Probe auf die wirksame Loyalität.
  loyalitaet,
}

/// Talent-ID von Reiten im Katalog.
const String kReitenTalentId = 'tal_reiten';

/// Baut die Reiten-Probe des Helden auf das Reittier [reittier].
///
/// Der Ausbildungsmodifikator (`reitenProbenModifikator`) belegt die
/// situative Erschwernis vor; der Dialog erlaubt weitere Zu- und Abschläge.
/// Ohne erfasste Ausbildung gibt es keinen Modifikator, die Probe läuft dann
/// ohne Zuschlag und der Hinweis sagt es. Führt der Held Reiten nicht oder
/// fehlt es im Katalog, steht der Grund im Hinweis. [imKampf] wählt die
/// Kampfzeile der Tabelle, [reiterIstZauberer] den Magierpferd-Nachlass.
AusbilderprobeAufbau reittierReitenProbe({
  required HeroComputedSnapshot snapshot,
  required List<TalentDef> talente,
  required HeroCompanion reittier,
  required bool imKampf,
  required bool reiterIstZauberer,
  required bool epicAdvantagesActive,
}) {
  final modifikator = reitenProbenModifikator(
    reittier,
    imKampf: imKampf,
    reiterIstZauberer: reiterIstZauberer,
  );
  final aufbau = ausbilderprobeFuer(
    snapshot: snapshot,
    talente: talente,
    talentId: kReitenTalentId,
    talentName: 'Reiten',
    erschwernis: modifikator.erschwernis,
    epicAdvantagesActive: epicAdvantagesActive,
  );
  final basis = aufbau.request;
  if (basis == null) return aufbau;

  final name = reittier.name.trim().isEmpty ? 'Reittier' : reittier.name.trim();
  final hat = reittier.reittierAusbildung != null;
  final teile = <String>[
    if (hat)
      'Ausbildung des Reittiers (ZBA S. 35): Reiten '
          '${mitVorzeichen(modifikator.erschwernis)} '
          '${imKampf ? 'im Kampf' : 'außerhalb des Kampfes'} '
          '(positiv = erschwert).'
    else
      'Für das Reittier ist keine Ausbildung erfasst: kein Stufenmodifikator.',
    ...modifikator.hinweise,
    if (modifikator.reiterKampfErschwernis != 0)
      'AT, PA und Ausweichen des Reiters '
          '${mitVorzeichen(modifikator.reiterKampfErschwernis)} '
          '(nicht in dieser Probe).',
    'Weitere Zuschläge (Gelände, Reiterkampf, ohne Sattel) nach Tischregel im '
        'Dialog.',
  ];
  // Der Verweis bleibt leer: Ein „Nochmal würfeln“ über die Probensuche
  // liefe sonst ohne den Stufenmodifikator des Reittiers.
  return AusbilderprobeAufbau(
    request: ResolvedProbeRequest(
      type: basis.type,
      title: '${basis.title} ($name${imKampf ? ', im Kampf' : ''})',
      subtitle: basis.subtitle,
      ruleHint: '${basis.ruleHint} ${teile.join(' ')}',
      diceSpec: basis.diceSpec,
      targets: basis.targets,
      basePool: basis.basePool,
      specializationBonus: basis.specializationBonus,
      initialSpecializationApplied: basis.initialSpecializationApplied,
      initialSituationalModifier: basis.initialSituationalModifier,
      fixedRollTotal: basis.fixedRollTotal,
      poolHerleitung: basis.poolHerleitung,
      bedingterPoolSchritt: basis.bedingterPoolSchritt,
      spezialisierungen: basis.spezialisierungen,
      kontext: basis.kontext,
      bedingteZielAbzuege: basis.bedingteZielAbzuege,
    ),
  );
}

/// LO-Probe des Begleiters: folgt er einem gefährlichen Auftrag?
///
/// Würfelt 1W20 auf die wirksame Loyalität (Grundwert, Steigerung und
/// Ausbildung). Bei Vertrauten nennt WdZ S. 124 den lebensgefährlichen
/// Auftrag; der Meister entscheidet, wann die Probe fällig ist und was ein
/// Misslingen bedeutet.
ResolvedProbeRequest begleiterLoyalitaetsProbe(HeroCompanion begleiter) {
  final name = begleiter.name.trim();
  return buildAttributeProbeRequest(
    label: name.isEmpty ? 'LO (Loyalität)' : 'LO (Loyalität, $name)',
    effectiveValue: begleiterWirksamerWert(begleiter, 'loyalitaet') ?? 0,
  );
}

/// Ob die Karte eines Begleiters Proben anbietet.
///
/// Reiten-Probe nur für Reittiere, LO-Probe für Reittiere, deren
/// Loyalität eingetragen ist. Vertraute haben ihre Proben in den
/// Vertrautenaktionen.
bool reittierHatProben(HeroCompanion begleiter) =>
    begleiter.typ == BegleiterTyp.reittier;
