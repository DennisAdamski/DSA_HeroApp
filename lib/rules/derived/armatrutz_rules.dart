import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';

/// Regeln zum Zauber `Armatrutz` (Liber Cantiones S. 28).
///
/// Der Zauber legt dem Ziel eine magische Ruestung auf: Der erzauberte Wert
/// zaehlt zusaetzlich zum Ruestungsschutz der getragenen Ruestung. Behinderung
/// entsteht dabei bewusst keine -- die Ruestung ist rein magisch und taucht
/// deshalb nicht in `computeBeTotalRaw` auf.

/// Katalog-ID des Zaubers im Magie-Katalog.
const String armatrutzSpellId = 'spell_armatrutz';

/// Obergrenze fuer den zusaetzlichen RS in der Eingabe.
///
/// Das ist keine Regelgrenze, sondern nur ein Riegel gegen Vertipper: Die
/// AsP-Kosten wachsen quadratisch und begrenzen den Zauber in der Praxis
/// selbst.
const int kArmatrutzMaxRsBonus = 12;

/// Mindestkosten des Zaubers in AsP laut Zauberbeschreibung.
const int kArmatrutzMinAspCost = 4;

/// Liefert den zusaetzlichen Ruestungsschutz eines laufenden Armatrutz.
///
/// Ist der Effekt nicht aktiv oder seine Wirkungsdauer abgelaufen, ist der
/// Bonus 0. Negative Werte werden nicht durchgereicht, damit ein fehlerhafter
/// Eintrag den Ruestungsschutz nicht senkt.
int computeArmatrutzRsBonus({
  required HeroSheet sheet,
  required HeroState state,
}) {
  final isActive = isActiveSpellEffectEnabled(
    sheet: sheet,
    state: state,
    effectId: activeSpellEffectArmatrutz,
  );
  if (!isActive) {
    return 0;
  }
  final detail = state.activeSpellEffects.detailFor(activeSpellEffectArmatrutz);
  if (detail.duration?.isExpired ?? false) {
    return 0;
  }
  return detail.amount < 0 ? 0 : detail.amount;
}

/// Berechnet die AsP-Kosten eines Armatrutz.
///
/// Zauberbeschreibung: `zusaetzlicher RS mal zusaetzlicher RS minus ZfP*/2 in
/// AsP, mindestens aber 4 AsP`. Die halben ZfP* werden abgerundet, weil die
/// Zauberbeschreibung keine Aufrundung vorsieht.
int computeArmatrutzAspCost({required int rsBonus, int zfpStar = 0}) {
  final normalizedRs = rsBonus < 0 ? 0 : rsBonus;
  final normalizedZfp = zfpStar < 0 ? 0 : zfpStar;
  final rawCost = normalizedRs * normalizedRs - normalizedZfp ~/ 2;
  return rawCost < kArmatrutzMinAspCost ? kArmatrutzMinAspCost : rawCost;
}

/// Formuliert den AsP-Kostenhinweis fuer die Eingabemaske.
String describeArmatrutzAspCost({required int rsBonus, int zfpStar = 0}) {
  final cost = computeArmatrutzAspCost(rsBonus: rsBonus, zfpStar: zfpStar);
  final normalizedRs = rsBonus < 0 ? 0 : rsBonus;
  final formula = '$normalizedRs × $normalizedRs − ZfP* ($zfpStar) / 2';
  return 'Kosten: $formula → $cost AsP (mindestens $kArmatrutzMinAspCost AsP)';
}
