import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';

/// Wie weit die App einen Haupteigenschafts-Bonus unterstuetzt.
///
/// Der Katalog aus Kap. 2.1 beschreibt Effekte quer durch das ganze
/// Regelwerk. Nur ein Teil davon hat in dieser App ueberhaupt einen
/// Rechenpunkt. Damit Spieler erkennen, welcher Wert bereits stimmt und was
/// sie selbst nachhalten muessen, traegt jeder Einzelbonus seinen
/// Umsetzungsgrad.
enum EpicBonusUmsetzung {
  /// Die App rechnet den Bonus in den angezeigten Wert ein.
  automatisch,

  /// Die App blendet den Bonus an der passenden Stelle ein; angewandt wird
  /// er am Spieltisch (wie der Fintenhinweis des Axxeleratus).
  hinweis,

  /// Die App unterstuetzt den Bonus noch nicht.
  manuell,
}

/// Ein einzelner Haupteigenschafts-Bonus aus Kap. 2.1.
class EpicMainAttributeBonus {
  /// Erzeugt einen unveraenderlichen Bonus-Eintrag.
  const EpicMainAttributeBonus({
    required this.code,
    required this.text,
    required this.umsetzung,
  });

  /// Haupteigenschaft, an die der Bonus gebunden ist.
  final AttributeCode code;

  /// Regeltext des Einzelbonus.
  final String text;

  /// Unterstuetzungsgrad in dieser App.
  final EpicBonusUmsetzung umsetzung;
}

/// Alle Haupteigenschafts-Boni in Charakterblatt-Reihenfolge.
///
/// Quelle: Hausregeln Kap. 2.1 – „Haupteigenschaften". Bewusst in
/// Einzelaussagen zerlegt, weil eine Eigenschaft Boni mit
/// unterschiedlichem Umsetzungsgrad mischt (KK: eBE-Halbierung wird
/// gerechnet, Tragkraft nicht).
const List<EpicMainAttributeBonus> epicMainAttributeBonuses =
    <EpicMainAttributeBonus>[
  EpicMainAttributeBonus(
    code: AttributeCode.mu,
    text: 'MR +7 gegen angstauslösende Zauber',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.mu,
    text: 'Manipulationsprobe 2×/Tag abwehren',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.mu,
    text: 'Aurapanzer stark verstärken',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.kl,
    text: 'Nach gelungener Wissenstalent-Probe: Folgeproben zum Ziel '
        'um 3 erleichtert',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.kl,
    text: 'AT/PA/TP gegen analysiertes Ziel +1',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.inn,
    text: 'Gefahreninstinkt-Immunität gegen Überraschung',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.inn,
    text: 'Finten gegen den Helden um 2 erschwert',
    umsetzung: EpicBonusUmsetzung.hinweis,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ch,
    text: 'Mitstreiter dürfen CH-Wert für MU-Proben nutzen (max. MU × 1,5)',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ch,
    text: 'Zuneigungs-/Loyalitätszauber +7 erschwert',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ff,
    text: 'Handwerksprodukte 10 % wertvoller + Zusatzverbesserung',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ff,
    text: 'FF-Probe ersetzt Ausweichen gegen Fernwaffen',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ge,
    text: 'Gezieltes Ausweichen bereits auf ⅓ des Wertes',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ge,
    text: 'Immunität gegen Passierschläge durch Ausweichen',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ko,
    text: 'Gifte: ½ Schaden, ½ Giftstufen-Erschwernis',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ko,
    text: 'Krankheiten: 70 % Zeit',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ko,
    text: 'Ansteckungswurf wiederholen',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.ko,
    text: 'Wund-Erschwernis auf Proben halbiert',
    umsetzung: EpicBonusUmsetzung.automatisch,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.kk,
    text: 'eBE bei KK-Talenten halbiert',
    umsetzung: EpicBonusUmsetzung.automatisch,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.kk,
    text: 'Tragkraft KK × 1,5',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.kk,
    text: 'Niederwerfen-KK-Probe wiederholen',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
  EpicMainAttributeBonus(
    code: AttributeCode.kk,
    text: 'Zurückdrängen möglich',
    umsetzung: EpicBonusUmsetzung.manuell,
  ),
];

/// Liefert alle Boni-Eintraege einer einzelnen Haupteigenschaft.
List<EpicMainAttributeBonus> epicMainAttributeBonusesFor(AttributeCode code) {
  return List<EpicMainAttributeBonus>.unmodifiable(
    epicMainAttributeBonuses.where((bonus) => bonus.code == code),
  );
}

/// Fasst die Boni einer Eigenschaft als Fliesstext zusammen.
///
/// Genutzt fuer Chip-Tooltips im Aktivierungsdialog, wo eine Liste mit
/// Markern nicht darstellbar ist.
String epicMainAttributeBonusSummary(AttributeCode code) {
  return epicMainAttributeBonusesFor(
    code,
  ).map((bonus) => bonus.text).join('; ');
}

/// Prüft, ob [code] in [mainAttributes] als Haupteigenschaft markiert ist.
///
/// Bewusst unabhängig von Hausregel-Schaltern und vom epischen Status: die
/// Markierung selbst ist eine reine Eigenschaft des Heldenbogens. Wer die
/// Boni aus Kap. 2.1 prüfen will, nutzt [isEpicMainAttributeBonusActive];
/// wer die Kostenregel aus Kap. 2.2 prüfen will, nutzt dieses Prädikat.
bool isEpicMainAttribute({
  required Attributes mainAttributes,
  required AttributeCode code,
}) {
  return readAttributeValue(mainAttributes, code) > 0;
}

/// Prüfungsergebnis: Gate für die Haupteigenschafts-Boni aus Kap. 2.1.
///
/// Der Bonus gilt nur, wenn der Held episch ist, die Regel aktiv ist
/// und die entsprechende Eigenschaft als Haupteigenschaft gewählt wurde.
bool isEpicMainAttributeBonusActive({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
  required AttributeCode code,
}) {
  if (!ruleActive || !isEpisch) return false;
  return isEpicMainAttribute(mainAttributes: mainAttributes, code: code);
}

/// MR-Bonus gegen angstauslösende Zauber (MU-Haupteigenschaft).
///
/// Quelle: Kap. 2.1 — „Gegen angstauslösende Zauber ist ihre MR um 7 erhöht."
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

/// Erschwernis-Aufschlag für gegnerische Finten (IN-Haupteigenschaft).
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
/// Quelle: Kap. 2.1 — „Körperliche Talente die KK-Proben beinhalten haben
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

/// Prueft, ob eine Talent-Probenkette die Eigenschaft [code] enthaelt.
///
/// [talentAttributes] sind die Katalognamen aus `TalentDef.attributes`
/// (z. B. `['Mut', 'Gewandheit', 'Koerperkraft']`). Die Erkennung laeuft
/// ueber `parseAttributeCode`, das Kurzformen und Umlaut-Varianten abdeckt.
bool talentProbeUsesAttribute(
  List<String> talentAttributes,
  AttributeCode code,
) {
  for (final raw in talentAttributes) {
    if (parseAttributeCode(raw) == code) {
      return true;
    }
  }
  return false;
}

/// Multiplikator auf die effektive Behinderung eines einzelnen Talents.
///
/// Quelle: Kap. 2.1 — „Körperliche Talente die KK-Proben beinhalten haben
/// eine halbierte effektive Behinderung." Greift nur, wenn KK
/// Haupteigenschaft ist und die Probenkette des Talents KK enthaelt.
/// Neutralwert ist 1.0.
double epicTalentEbeMultiplier({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
  required List<String> talentAttributes,
}) {
  if (!talentProbeUsesAttribute(talentAttributes, AttributeCode.kk)) {
    return 1.0;
  }
  return epicKkBeMultiplier(
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    mainAttributes: mainAttributes,
  );
}

/// Wertmultiplikator für handwerkliche Produkte (FF-Haupteigenschaft).
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

/// Liefert die Boni aller gewaehlten Haupteigenschaften.
///
/// Reihenfolge entspricht der Eigenschafts-Reihenfolge im Charakterblatt
/// (MU, KL, IN, CH, FF, GE, KO, KK). Leer, wenn die Regel nicht greift oder
/// der Held keine Haupteigenschaften gewaehlt hat.
List<EpicMainAttributeBonus> activeEpicMainAttributeBonuses({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  if (!ruleActive || !isEpisch) return const <EpicMainAttributeBonus>[];
  return List<EpicMainAttributeBonus>.unmodifiable(
    epicMainAttributeBonuses.where(
      (bonus) => isEpicMainAttribute(
        mainAttributes: mainAttributes,
        code: bonus.code,
      ),
    ),
  );
}

/// Anzeigetext fuer die gegnerische Finten-Erschwernis (IN-Haupteigenschaft).
///
/// Quelle: Kap. 2.1 — „Finten gegen alle Helden mit Haupteigenschaft IN
/// sind um 2 erschwert." Der Bonus wirkt auf die Probe des Gegners und
/// laesst sich deshalb nicht in einen Heldenwert einrechnen. Er wird wie
/// der Axxeleratus-Fintenhinweis in der Kampfvorschau eingeblendet
/// (vgl. `buildAxxeleratusDefenseHint` in `magic_rules.dart`).
/// Liefert den leeren String, wenn der Bonus nicht greift.
String buildEpicFinteDefenseHint({
  required bool ruleActive,
  required bool isEpisch,
  required Attributes mainAttributes,
}) {
  final erschwernis = epicFinteErschwernis(
    ruleActive: ruleActive,
    isEpisch: isEpisch,
    mainAttributes: mainAttributes,
  );
  if (erschwernis <= 0) {
    return '';
  }
  return 'Haupteigenschaft IN: Finten gegen dich sind um '
      '$erschwernis erschwert';
}
