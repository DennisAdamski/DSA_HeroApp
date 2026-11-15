import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';

// Regelgrundlage: Wege der Helden S. 276 f. (Geländekunde: −3 auf Proben in
// einer vertrauten Wildnisart, je Gelände einzeln erworben) und S. 277 f.
// (Ortskenntnis: für ein Gebiet bis 100 Rechtmeilen oder eine Strecke, bis zu
// 7 Punkte Zuschläge entfallen); Wege des Entdeckers S. 112 f. (−3/−1/−7 auf
// Nahrung sammeln und Kräuter Suchen, „ähnlich“ nach Meisterentscheid), Zoo
// Botanica Aventurica S. 61 (gleiche Erleichterung bei Jagdproben).

/// Basisname der Sonderfertigkeit Geländekunde.
const String kGelaendekundeName = 'Geländekunde';

/// Basisname der Sonderfertigkeit Ortskenntnis.
const String kOrtskenntnisName = 'Ortskenntnis';

/// Was die Sonderfertigkeiten eines Helden für eine Wildnisprobe leisten.
class WildnisSonderfertigkeiten {
  /// Erstellt das Ergebnis.
  const WildnisSonderfertigkeiten({
    this.gelaendekunde = Gelaendekunde.keine,
    this.ortskenntnis = false,
    this.gelaendekundeHerkunft,
    this.ortskenntnisHerkunft,
  });

  /// Keine einschlägige Sonderfertigkeit.
  static const WildnisSonderfertigkeiten keine = WildnisSonderfertigkeiten();

  /// Geländekunde für die gewählte Landschaft.
  final Gelaendekunde gelaendekunde;

  /// Ob eine Ortskenntnis für den Standort vorliegt.
  final bool ortskenntnis;

  /// Gespeicherter Name der Sonderfertigkeit, aus der [gelaendekunde] stammt
  /// (`Geländekunde (Waldkundig)`); `null` ohne Treffer.
  final String? gelaendekundeHerkunft;

  /// Gespeicherter Name der Sonderfertigkeit, aus der [ortskenntnis] stammt
  /// (`Ortskenntnis (Gareth)`); `null` ohne Treffer.
  final String? ortskenntnisHerkunft;
}

/// Geländeart zu einer Variante der Geländekunde, sonst `null`.
///
/// Verglichen wird über [normalizeSpecialAbilityName]; neben der
/// Katalogvariante (`Waldkundig`) gilt auch die Kurzform (`Wald`).
Gelaendeart? gelaendeartAusVariante(String variante) {
  final gesucht = normalizeSpecialAbilityName(variante);
  if (gesucht.isEmpty) return null;
  for (final art in Gelaendeart.values) {
    if (normalizeSpecialAbilityName(art.variante) == gesucht ||
        normalizeSpecialAbilityName(art.bezeichnung) == gesucht) {
      return art;
    }
  }
  return null;
}

/// Erkennt Geländekunde und Ortskenntnis des Helden für eine Wildnisprobe.
///
/// Die Auswertung gilt für jede Wildnistätigkeit (Kräuter suchen, Nahrung
/// sammeln, Jagd …) und schreibt nichts am Helden; das Ergebnis dient der
/// Vorbelegung, die der Spieler überschreiben kann.
///
/// **Geländekunde:** Jede erworbene Variante (`Geländekunde (Waldkundig)`)
/// wird einer [Gelaendeart] zugeordnet. Liegt sie in
/// [WildnisLandschaft.gelaende], gilt die Geländekunde als passend (−3), liegt
/// sie in [WildnisLandschaft.aehnlicheGelaende], als ähnlich (−1); die beste
/// Stufe gewinnt. Altbestand ohne Variante und nicht zuordenbare Varianten
/// zählen nicht.
///
/// **Ortskenntnis:** Sie ist an einen Ort gebunden und gilt deshalb nur für
/// den [standort] des Helden, nicht für jede Landschaft gleicher Art. Die
/// Variante (Freitext, etwa `Gareth` oder `Gareth (Südquartier)`) passt, wenn
/// sie nach [suchFaltung] dem Standort entspricht (auch ohne Klammerzusatz,
/// etwa `Havena (Siedlung)` oder `Gareth (Südquartier)`).
WildnisSonderfertigkeiten werteWildnisSonderfertigkeitenAus({
  required HeroSheet hero,
  required WildnisLandschaft landschaft,
  required String standort,
  required RulesCatalog? catalog,
}) {
  final namen = heroSpecialAbilityNames(hero, catalog: catalog);

  var gelaendekunde = Gelaendekunde.keine;
  String? gelaendeHerkunft;
  var ortskenntnis = false;
  String? ortHerkunft;

  final gelaendeBasis = normalizeSpecialAbilityName(kGelaendekundeName);
  final ortBasis = normalizeSpecialAbilityName(kOrtskenntnisName);

  for (final name in namen) {
    final basis = normalizeSpecialAbilityName(specialAbilityBaseName(name));
    final variante = specialAbilityVariant(name);
    if (variante == null) continue;

    if (basis == gelaendeBasis) {
      final art = gelaendeartAusVariante(variante);
      if (art == null) continue;
      final stufe = landschaft.gelaende.contains(art)
          ? Gelaendekunde.passend
          : landschaft.aehnlicheGelaende.contains(art)
          ? Gelaendekunde.aehnlich
          : Gelaendekunde.keine;
      // Je kleiner die Erschwernis, desto besser die Stufe.
      if (stufe.erschwernis < gelaendekunde.erschwernis) {
        gelaendekunde = stufe;
        gelaendeHerkunft = name;
      }
    } else if (basis == ortBasis && !ortskenntnis) {
      if (_ortskenntnisPasst(variante, standort)) {
        ortskenntnis = true;
        ortHerkunft = name;
      }
    }
  }

  return WildnisSonderfertigkeiten(
    gelaendekunde: gelaendekunde,
    ortskenntnis: ortskenntnis,
    gelaendekundeHerkunft: gelaendeHerkunft,
    ortskenntnisHerkunft: ortHerkunft,
  );
}

bool _ortskenntnisPasst(String variante, String standort) {
  final ziel = suchFaltung(bereinigeStandort(standort));
  if (ziel.isEmpty) return false;
  final voll = suchFaltung(bereinigeStandort(variante));
  final ohneZusatz = suchFaltung(
    bereinigeStandort(variante.replaceFirst(RegExp(r'\s*\(.*$'), '')),
  );
  return voll == ziel || (ohneZusatz.isNotEmpty && ohneZusatz == ziel);
}
