/// Erwerbskosten fuer magische Kenntnisse, die nicht als Sonderfertigkeit
/// im Katalog stehen, sondern als eigene Felder im Heldenmodell:
/// Merkmalskenntnisse (`HeroSheet.merkmalskenntnisse`) und Repraesentationen
/// (`HeroSheet.representationen`).
///
/// Quellen: Wege der Helden S. 289 (Merkmalskenntnis) und S. 290
/// (Repraesentation).
library;

import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

/// Aktivierungskosten fuer die Ritualkenntnis einer fremden Tradition
/// (WdH S. 290). Die eigene Tradition wird ueber die Profession aktiviert.
const int kRitualkenntnisFremdeTraditionAp = 250;

/// Merkmale der Klassifikation I (WdH S. 289).
const List<String> kMerkmaleKlassifikationI = [
  'Dämonisch (Amazeroth)',
  'Dämonisch (Asfaloth)',
  'Dämonisch (Blakharaz)',
  'Dämonisch (Lolgramoth)',
  'Dämonisch (Mishkara)',
  'Dämonisch (Thargunitoth)',
  'Elementar (Eis)',
  'Elementar (Erz)',
  'Elementar (Feuer)',
  'Elementar (Humus)',
  'Elementar (Luft)',
  'Elementar (Wasser)',
  'Geisterwesen',
  'Heilung',
  'Herbeirufung',
  'Illusion',
  'Schaden',
  'Telekinese',
  'Verständigung',
];

/// Merkmale der Klassifikation II (WdH S. 289).
const List<String> kMerkmaleKlassifikationII = [
  'Antimagie',
  'Beschwörung',
  'Eigenschaften',
  'Einfluss',
  'Form',
  'Hellsicht',
  'Herrschaft',
  'Kraft',
  'Objekt',
  'Umwelt',
];

/// Merkmale der Klassifikation III (WdH S. 289).
const List<String> kMerkmaleKlassifikationIII = [
  'Dämonisch (allgemein)',
  'Elementar (allgemein)',
  'Limbus',
  'Metamagie',
  'Temporal',
];

/// Liefert die Merkmalsklassifikation `1`, `2` oder `3`.
///
/// Dieselbe Einteilung traegt drei Preistabellen: Merkmalskenntnis
/// (100/200/300 AP), Arkane Meisterschaft (400/550/700 AP) und
/// Merkmalsgrossmeister (600/800/1000 AP). Unbekannte Merkmale — etwa aus
/// einem Hausregel-Katalog — werden als Stufe II behandelt, damit der
/// Vorschlag in der Mitte liegt statt zu billig oder zu teuer zu raten.
int merkmalsklassifikation(String merkmal) {
  final needle = normalizeSpecialAbilityName(merkmal);
  if (needle.isEmpty) {
    return 2;
  }
  bool contains(List<String> liste) => liste.any(
    (eintrag) => normalizeSpecialAbilityName(eintrag) == needle,
  );
  if (contains(kMerkmaleKlassifikationI)) {
    return 1;
  }
  if (contains(kMerkmaleKlassifikationIII)) {
    return 3;
  }
  return 2;
}

/// AP-Kosten einer Merkmalskenntnis: 100 / 200 / 300 AP je Klassifikation.
///
/// Die erste Merkmalskenntnis ist bei Magiern, Hexen, Druiden, Geoden,
/// Kristallomanten und Scharlatanen ueblicherweise in der Profession
/// enthalten; das entscheidet der Spieler im Erwerbsdialog, indem er die
/// Kosten auf 0 setzt.
int merkmalskenntnisApCost(String merkmal) {
  switch (merkmalsklassifikation(merkmal)) {
    case 1:
      return 100;
    case 3:
      return 300;
    default:
      return 200;
  }
}

/// AP-Kosten fuer den Erwerb einer weiteren Repraesentation (WdH S. 290).
///
/// [anzahlVorhanden] ist die Zahl der bereits bekannten Repraesentationen.
/// Die zweite kostet Vollzauberer 2.000 AP und Halbzauberer 3.000 AP, die
/// dritte Vollzauberer 4.000 AP. Fuer Halbzauberer ist ab der dritten laut
/// Regelwerk kein Erwerb vorgesehen — dann liefert die Funktion `null`, und
/// die UI weist darauf hin, ohne den Erwerb zu blockieren (Meisterentscheid).
int? repraesentationApCost({
  required int anzahlVorhanden,
  required bool istHalbzauberer,
}) {
  if (anzahlVorhanden <= 0) {
    // Die erste Repraesentation kommt aus Kultur/Profession und kostet nichts.
    return 0;
  }
  if (anzahlVorhanden == 1) {
    return istHalbzauberer ? 3000 : 2000;
  }
  if (anzahlVorhanden == 2 && !istHalbzauberer) {
    return 4000;
  }
  return null;
}
