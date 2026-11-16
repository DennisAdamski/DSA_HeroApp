/// Vorteile, die die AP-Kosten des Lernens im Ganzen senken (ARCH-04).
///
/// Eidetisches Gedächtnis (Wege der Helden S. 252) verbilligt Wissenstalente,
/// Sprachen und Schriften sowie Zauberfertigkeiten auf die Hälfte der Kosten.
/// Gutes Gedächtnis (Wege der Helden S. 252) nennt Wissenstalente nicht und
/// verbilligt Sprachen und Schriften sowie Zauberfertigkeiten auf drei Viertel
/// der Kosten. Beide verbilligen zudem dieselbe Liste von Sonderfertigkeiten
/// ([istGedaechtnisSonderfertigkeit], WdH S. 251 und 253): Geländekunde,
/// Kulturkunde, Nandusgefälliges Wissen, Ortskenntnis, Talentspezialisierungen
/// bei Wissensfertigkeiten, alle Objektrituale, Bann- und Schutzkreise,
/// Exorzist, Invocatio Integra, Kraftlinienmagie I/II, Matrixkontrolle,
/// Ritualkenntnis (auch Schamane), Runenkunde, Schamanenrituale,
/// Signaturkenntnis, Zauberspezialisierung, Zauberzeichen, Zibilja-Rituale,
/// Liturgiekenntnis und Liturgien. Die Faktoren wirken auf die Kosten nach
/// allen Spaltenverschiebungen (Begabung, Sondererfahrung, Hexalogie …) und
/// schließen einander aus. Die Akademische Ausbildung (Gelehrter/Magier) gilt
/// nur bei der Heldenerschaffung und taucht deshalb hier nicht auf.
library;

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';

/// Katalog-IDs der Sonderfertigkeiten, die beide Gedächtnis-Vorteile
/// verbilligen (WdH S. 251 und 253). Objektrituale erkennt
/// [istGedaechtnisSonderfertigkeit] zusätzlich am Kennzeichen „(OR)“.
const Set<String> kGedaechtnisSonderfertigkeitIds = <String>{
  'asf_gelaendekunde',
  'asf_kulturkunde',
  'asf_nandusgefaelliges_wissen',
  'asf_ortskenntnis',
  'magsf_bann_und_schutzkreise',
  'magsf_exorzist',
  'magsf_invocatio_integra',
  'magsf_kraftlinienmagie_i',
  'magsf_kraftlinienmagie_ii',
  'magsf_matrixkontrolle',
  'magsf_ritualkenntnis_tradition',
  'magsf_runenkunde',
  'magsf_schamanistische_rituale',
  'magsf_signaturkenntnis',
  'magsf_zauberspezialisierung',
  'magsf_zauberzeichen',
  'magsf_zibilja_rituale',
  'karmsf_ritualkenntnis_schamanentradition',
  'karmsf_liturgiekenntnis_kirche',
  'karmsf_liturgien',
};

/// Ob die Sonderfertigkeit [id] / [name] zu den Gedächtnis-Sonderfertigkeiten
/// zählt: über die Katalog-ID oder als Objektritual („(OR)“ im Namen).
bool istGedaechtnisSonderfertigkeit({
  required String id,
  required String name,
}) {
  return kGedaechtnisSonderfertigkeitIds.contains(id) || name.contains('(OR)');
}

/// Katalog-ID des Vorteils Gutes Gedächtnis.
const String kGutesGedaechtnisId = 'adv_gutes_gedaechtnis';

/// Katalog-ID des Vorteils Eidetisches Gedächtnis.
const String kEidetischesGedaechtnisId = 'adv_eidetisches_gedaechtnis';

/// Was ein Lernziel ist, soweit es für die Faktoren zählt.
enum LernzielArt {
  /// Wissenstalent.
  wissenstalent,

  /// Sprache oder Schrift.
  sprachschrift,

  /// Zauberfertigkeit.
  zauber,

  /// Sonderfertigkeit aus der Gedächtnis-Liste, auch Ritualkenntnis und
  /// Talentspezialisierungen bei Wissensfertigkeiten.
  sonderfertigkeit,

  /// Alles Übrige (Eigenschaften, andere Talente, Grundwerte …).
  sonstiges,
}

/// Ein Kostenfaktor auf die Lernkosten, etwa „Gutes Gedächtnis (¾)“.
class LernkostenFaktor {
  /// Faktor [zaehler]/[nenner] aus der [quelle].
  const LernkostenFaktor({
    required this.bezeichnung,
    required this.zaehler,
    required this.nenner,
    required this.quelle,
  });

  /// Anzeigename des Schritts.
  final String bezeichnung;

  /// Zähler des Bruchs.
  final int zaehler;

  /// Nenner des Bruchs.
  final int nenner;

  /// Vorteil, aus dem der Faktor stammt.
  final String quelle;

  /// Kosten nach diesem Faktor, kaufmännisch gerundet.
  int wende(int kosten) => (kosten * zaehler / nenner).round();
}

/// Kostenfaktoren, die für ein Lernziel der Art [art] beim Helden gelten.
///
/// Die Vorteile kommen aus [werteMerkmaleAus]: Mit [catalog] wird auch ein
/// Held erkannt, dessen Vorteile noch als Alttext vorliegen.
List<LernkostenFaktor> lernkostenFaktoren(
  HeroSheet hero,
  LernzielArt art, {
  required RulesCatalog? catalog,
}) {
  if (art == LernzielArt.sonstiges) return const <LernkostenFaktor>[];
  bool hat(String katalogId, String name) =>
      _hatVorteil(hero, catalog, katalogId, name);
  if (hat(kEidetischesGedaechtnisId, 'eidetisches gedächtnis')) {
    return const <LernkostenFaktor>[
      LernkostenFaktor(
        bezeichnung: 'Eidetisches Gedächtnis (½)',
        zaehler: 1,
        nenner: 2,
        quelle: 'Vorteil Eidetisches Gedächtnis',
      ),
    ];
  }
  if (hat(kGutesGedaechtnisId, 'gutes gedächtnis')) {
    // Das Buch nennt für Gutes Gedächtnis keine Wissenstalente, wohl aber
    // Talentspezialisierungen bei Wissensfertigkeiten (als Sonderfertigkeit).
    if (art == LernzielArt.wissenstalent) return const <LernkostenFaktor>[];
    return const <LernkostenFaktor>[
      LernkostenFaktor(
        bezeichnung: 'Gutes Gedächtnis (¾)',
        zaehler: 3,
        nenner: 4,
        quelle: 'Vorteil Gutes Gedächtnis',
      ),
    ];
  }
  return const <LernkostenFaktor>[];
}

/// Wendet [faktoren] der Reihe nach auf feste [kosten] an (Sonderfertigkeiten,
/// Ritualkenntnis), jeweils kaufmännisch gerundet wie bei Steigerungen.
int wendeLernkostenFaktorenAn(int kosten, List<LernkostenFaktor> faktoren) {
  var ergebnis = kosten;
  for (final faktor in faktoren) {
    ergebnis = faktor.wende(ergebnis);
  }
  return ergebnis;
}

/// Kurzer Anzeigetext der eingerechneten [faktoren] oder `null`.
String? lernkostenFaktorHinweis(List<LernkostenFaktor> faktoren) {
  if (faktoren.isEmpty) return null;
  final namen = faktoren.map((f) => f.bezeichnung).join(', ');
  return '$namen eingerechnet';
}

// Katalogisierte Eintraege wirken ueber ihre ID, freie ueber ihren Text.
// Gelesen werden die wirksamen Vorteile der zentralen Auswertung, nie die
// gespeicherte Liste oder der Alttext selbst.
bool _hatVorteil(
  HeroSheet hero,
  RulesCatalog? catalog,
  String katalogId,
  String name,
) {
  final vorteile = werteMerkmaleAus(hero, catalog: catalog).abgleich.vorteile;
  for (final eintrag in vorteile) {
    if (eintrag.katalogId == katalogId) return true;
    if (eintrag.katalogId.isEmpty &&
        eintrag.text.toLowerCase().trim().startsWith(name)) {
      return true;
    }
  }
  return false;
}
