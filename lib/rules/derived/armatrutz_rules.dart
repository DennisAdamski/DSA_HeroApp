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
/// Das ist keine Regelgrenze, sondern nur ein Riegel gegen Vertipper. Die
/// Regelgrenze ist ZfW/2 ([armatrutzRsGrenze]); sie greift in der Rechnung,
/// nicht in der Eingabe, damit gespeicherte Werte nie still geaendert werden.
const int kArmatrutzMaxRsBonus = 12;

/// Der ZfW des Helden im Armatrutz oder `null`, wenn er den Zauber nicht
/// fuehrt oder noch keinen Wert eingetragen hat.
///
/// Das Regelwerk nennt den ZfW, deshalb ohne eigenen Modifikator (ZfW*).
int? armatrutzZfw(HeroSheet sheet) =>
    sheet.spells[armatrutzSpellId]?.spellValue;

/// Hoechster zusaetzlicher RS laut Liber Cantiones S. 28: „Die Staerke der
/// zusaetzlichen Ruestung darf maximal ZfW/2 Punkte betragen.“
///
/// Gerundet wird auf (Tischregel 18.10.2026: Spielerwerte werden
/// aufgerundet, Kosten abgerundet, die MR ausgenommen); ZfW 9 ergibt 5.
/// `null`, wenn der ZfW unbekannt ist (etwa bei einer fremden Quelle ueber
/// die Modifikation Beruehrung) -- dann prueft die App keine Grenze.
int? armatrutzRsGrenze({required HeroSheet sheet}) {
  final zfw = armatrutzZfw(sheet);
  if (zfw == null) {
    return null;
  }
  final normalisiert = zfw < 0 ? 0 : zfw;
  return (normalisiert + 1) ~/ 2;
}

/// Der wirksame zusaetzliche RS: [gespeichert], hoechstens [grenze].
int begrenzeArmatrutzRs({required int gespeichert, required int? grenze}) {
  if (grenze == null || gespeichert <= grenze) {
    return gespeichert;
  }
  return grenze;
}

/// Kurzer Hinweis zur ZfW/2-Grenze fuer Eingabe und Effektliste.
///
/// [grenze] `null` heisst: ZfW unbekannt, Grenze nicht geprueft.
String describeArmatrutzGrenze({required int rsBonus, required int? grenze}) {
  if (grenze == null) {
    return 'ZfW im Armatrutz unbekannt – die Grenze ZfW/2 wird nicht geprüft.';
  }
  if (rsBonus > grenze) {
    return 'Höchstens $grenze (ZfW/2, aufgerundet): Es wirken nur $grenze '
        'Punkte, der eingetragene Wert bleibt gespeichert.';
  }
  return 'Höchstens $grenze (ZfW/2, aufgerundet).';
}

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

/// Wertzeile des laufenden Armatrutz fuer die Effektliste: gespeicherter
/// RS und, falls er laeuft, die ZfW/2-Grenze samt wirksamem Wert.
String describeArmatrutzWert({
  required HeroSheet sheet,
  required HeroState state,
}) {
  final gespeichert = state.activeSpellEffects
      .detailFor(activeSpellEffectArmatrutz)
      .amount;
  final text = 'Zusätzlicher RS: $gespeichert';
  if (gespeichert <= 0) {
    return text;
  }
  return '$text · ${describeArmatrutzGrenze(
    rsBonus: gespeichert,
    grenze: armatrutzRsGrenze(sheet: sheet),
  )}';
}

/// Berechnet die AsP-Kosten eines Armatrutz.
///
/// Zauberbeschreibung: `zusaetzlicher RS mal zusaetzlicher RS minus ZfP*/2 in
/// AsP, mindestens aber 4 AsP`. Die Endkosten werden abgerundet
/// (Tischregel 18./19.10.2026: Kosten abrunden), die halben ZfP* also
/// aufgerundet abgezogen -- wie im Beispiel des Zaubertexts: RS 4, ZfP* 5
/// ergibt 16 − 2,5 = 13,5, also 13 AsP.
int computeArmatrutzAspCost({required int rsBonus, int zfpStar = 0}) {
  final normalizedRs = rsBonus < 0 ? 0 : rsBonus;
  final normalizedZfp = zfpStar < 0 ? 0 : zfpStar;
  final rawCost = normalizedRs * normalizedRs - (normalizedZfp + 1) ~/ 2;
  return rawCost < kArmatrutzMinAspCost ? kArmatrutzMinAspCost : rawCost;
}

/// Formuliert den AsP-Kostenhinweis fuer die Eingabemaske.
String describeArmatrutzAspCost({required int rsBonus, int zfpStar = 0}) {
  final cost = computeArmatrutzAspCost(rsBonus: rsBonus, zfpStar: zfpStar);
  final normalizedRs = rsBonus < 0 ? 0 : rsBonus;
  final formula = '$normalizedRs × $normalizedRs − ZfP* ($zfpStar) / 2';
  return 'Kosten: $formula, abgerundet → $cost AsP '
      '(mindestens $kArmatrutzMinAspCost AsP)';
}
