/// Vorteile, die die AP-Kosten des Lernens im Ganzen senken (ARCH-04).
///
/// Gutes Gedächtnis und Eidetisches Gedächtnis (Wege der Helden S. 251/253)
/// verbilligen Wissenstalente, Sprachen und Schriften sowie Zauberfertigkeiten
/// auf drei Viertel bzw. die Hälfte der Kosten. Sie wirken auf die Kosten nach
/// allen Spaltenverschiebungen (Begabung, Sondererfahrung, Hexalogie …) und
/// schließen einander aus. Die Akademische Ausbildung (Gelehrter/Magier) gilt
/// nur bei der Heldenerschaffung und taucht deshalb hier nicht auf.
library;

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

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
List<LernkostenFaktor> lernkostenFaktoren(HeroSheet hero, LernzielArt art) {
  if (art == LernzielArt.sonstiges) return const <LernkostenFaktor>[];
  if (_hatVorteil(hero, kEidetischesGedaechtnisId, 'eidetisches gedächtnis')) {
    return const <LernkostenFaktor>[
      LernkostenFaktor(
        bezeichnung: 'Eidetisches Gedächtnis (½)',
        zaehler: 1,
        nenner: 2,
        quelle: 'Vorteil Eidetisches Gedächtnis',
      ),
    ];
  }
  if (_hatVorteil(hero, kGutesGedaechtnisId, 'gutes gedächtnis')) {
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

// Katalogisierte Eintraege wirken ueber ihre ID, freie ueber ihren Text.
bool _hatVorteil(HeroSheet hero, String katalogId, String name) {
  if (hero.vorteilEintraege.isEmpty &&
      hero.vorteileText.toLowerCase().contains(name)) {
    return true;
  }
  for (final eintrag in hero.vorteilEintraege) {
    if (eintrag.katalogId == katalogId) return true;
    if (eintrag.katalogId.isEmpty &&
        eintrag.text.toLowerCase().trim().startsWith(name)) {
      return true;
    }
  }
  return false;
}
