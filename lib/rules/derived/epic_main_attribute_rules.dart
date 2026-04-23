import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';

/// Pruefnungsergebnis: Gate fuer die Haupteigenschafts-Boni aus Kap. 2.1.
///
/// Der Bonus gilt nur, wenn der Held episch ist, die Regel aktiv ist
/// und die entsprechende Eigenschaft als Haupteigenschaft gewaehlt wurde.
bool isEpicMainAttributeBonusActive({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
  required AttributeCode code,
}) {
  if (!ruleActive || !isEpisch) return false;
  return readAttributeValue(mainAttributes, code) > 0;
}

/// MR-Bonus gegen angstausloesende Zauber (MU-Haupteigenschaft).
///
/// Quelle: Kap. 2.1 — „Gegen Angstausloesende Zauber ist ihre MR um 7 erhoeht."
int epicMrBonusVsFear({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  return isEpicMainAttributeBonusActive(
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    mainAttributes: mainAttributes,
    code: AttributeCode.mu,
  )
      ? 7
      : 0;
}

/// Erschwernis-Aufschlag fuer gegnerische Finten (IN-Haupteigenschaft).
///
/// Quelle: Kap. 2.1 — „Finten gegen alle Helden mit Haupteigenschaft IN
/// sind um 2 erschwert."
int epicFinteErschwernis({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  return isEpicMainAttributeBonusActive(
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    mainAttributes: mainAttributes,
    code: AttributeCode.inn,
  )
      ? 2
      : 0;
}

/// Multiplikator auf die Tragkraft (KK-Haupteigenschaft).
///
/// Quelle: Kap. 2.1 — „Die Tragkraftgrenzenbasis ist KK*1,5 statt KK."
/// Neutralwert ist 1.0.
double epicTragkraftMultiplier({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  return isEpicMainAttributeBonusActive(
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    mainAttributes: mainAttributes,
    code: AttributeCode.kk,
  )
      ? 1.5
      : 1.0;
}

/// Multiplikator auf die effektive BE bei KK-basierten Talenten.
///
/// Quelle: Kap. 2.1 — „Koerperliche Talente die KK-Proben beinhalten haben
/// eine halbierte effektive Behinderung." Neutralwert ist 1.0.
double epicKkBeMultiplier({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  return isEpicMainAttributeBonusActive(
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    mainAttributes: mainAttributes,
    code: AttributeCode.kk,
  )
      ? 0.5
      : 1.0;
}

/// Multiplikator auf den eingehenden Giftschaden (KO-Haupteigenschaft).
///
/// Quelle: Kap. 2.1 — „Gifte richten ihren Schaden nur in halber
/// Geschwindigkeit an und die KO-Probe zum Widerstehen ist nur um die
/// halbe Giftstufe erschwert." Neutralwert ist 1.0.
double epicGiftDamageMultiplier({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  return isEpicMainAttributeBonusActive(
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    mainAttributes: mainAttributes,
    code: AttributeCode.ko,
  )
      ? 0.5
      : 1.0;
}

/// Multiplikator auf die Krankheits-Dauer (KO-Haupteigenschaft).
///
/// Quelle: Kap. 2.1 — „Krankheiten sind in 70 % der normalen Zeit
/// auskuriert." Neutralwert ist 1.0.
double epicKrankheitTimeMultiplier({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  return isEpicMainAttributeBonusActive(
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    mainAttributes: mainAttributes,
    code: AttributeCode.ko,
  )
      ? 0.7
      : 1.0;
}

/// Wertmultiplikator fuer handwerkliche Produkte (FF-Haupteigenschaft).
///
/// Quelle: Kap. 2.1 — „Handwerkliche Produkte sind 10 % wertvoller …"
/// Neutralwert ist 1.0.
double epicHandwerkWertMultiplier({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  return isEpicMainAttributeBonusActive(
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    mainAttributes: mainAttributes,
    code: AttributeCode.ff,
  )
      ? 1.1
      : 1.0;
}

/// Liefert kurze Textbeschreibungen der aktiven Boni fuer UI-Anzeige.
///
/// Reihenfolge entspricht der Eigenschafts-Reihenfolge im Charakterblatt
/// (MU, KL, IN, CH, FF, GE, KO, KK). Leer, wenn keine Regel greift.
List<String> activeEpicMainAttributeHints({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  if (!ruleActive || !isEpisch) return const <String>[];
  final hints = <String>[];
  if (mainAttributes.mu > 0) {
    hints.add(
      'MU: MR +7 gegen angstausloesende Zauber; 2x/Tag Manipulationsprobe '
      'abwehren; Aurapanzer stark verstaerken.',
    );
  }
  if (mainAttributes.kl > 0) {
    hints.add(
      'KL: Nach gelungener Wissenstalent-Probe sind Folgeproben zum Ziel '
      'um 3 erleichtert; AT/PA/TP gegen analysiertes Ziel +1.',
    );
  }
  if (mainAttributes.inn > 0) {
    hints.add(
      'IN: Gefahreninstinkt-Immunitaet gegen Ueberraschung; '
      'Finten gegen den Helden sind um 2 erschwert.',
    );
  }
  if (mainAttributes.ch > 0) {
    hints.add(
      'CH: Mitstreiter duerfen CH-Wert fuer MU-Proben nutzen (max. MU x 1.5); '
      'Zuneigungs-/Loyalitaetszauber +7 erschwert.',
    );
  }
  if (mainAttributes.ff > 0) {
    hints.add(
      'FF: Handwerksprodukte 10 % wertvoller und mit einer Zusatzverbesserung; '
      'FF-Probe ersetzt Ausweichen gegen Fernwaffen.',
    );
  }
  if (mainAttributes.ge > 0) {
    hints.add(
      'GE: Gezieltes Ausweichen bereits auf ein Drittel des Wertes; '
      'Immunitaet gegen Passierschlaege durch Ausweichen.',
    );
  }
  if (mainAttributes.ko > 0) {
    hints.add(
      'KO: Gifte halber Schaden und halbe Giftstufen-Erschwernis; '
      'Krankheiten 70 % Zeit; Ansteckungswurf wiederholen; '
      'Wund-Erschwernis halbiert.',
    );
  }
  if (mainAttributes.kk > 0) {
    hints.add(
      'KK: eBE bei KK-Talenten halbiert; Tragkraft KK x 1.5; '
      'Niederwerfen-KK-Probe wiederholen; Zurueckdraengen moeglich.',
    );
  }
  return List<String>.unmodifiable(hints);
}
