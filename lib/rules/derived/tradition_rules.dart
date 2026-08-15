/// Zaubertraditionen, ihre Repraesentationen und Leiteigenschaften.
///
/// Quelle: Wege der Zauberei S. 19. Dort steht die vollstaendige Zuordnung
/// Tradition → Leiteigenschaft (ausschliesslich Klugheit oder Intuition) sowie
/// die Feststellung, dass Schamanen, Derwische, Durro-Dûn, Zibiljas und
/// Zaubertaenzer eine Ritualkenntnis, aber keine Repraesentation besitzen.
///
/// Diese Unterscheidung ist der Grund, warum Traditionsrituale nicht an die
/// Repraesentation gekoppelt werden duerfen: Trommelzauber verlangen die
/// Ritualkenntnis Derwisch, und ein Derwisch hat nie eine Repraesentation.
/// Die Tradition eines Helden ist deshalb die Vereinigung aus seinen
/// Repraesentationen und seinen Ritualkenntnissen.
library;

import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

/// Eine Zaubertradition mit ihrer Leiteigenschaft.
class TraditionDef {
  /// Erzeugt eine unveraenderliche Traditionsbeschreibung.
  const TraditionDef({
    required this.id,
    required this.name,
    required this.leiteigenschaft,
    this.repraesentation = '',
    this.aliasNamen = const <String>[],
  });

  /// Stabile Kennung, z. B. `gildenmagier`.
  final String id;

  /// Anzeigename der Tradition.
  final String name;

  /// Leiteigenschaft laut WdZ S. 19 — `KL` oder `IN`.
  final String leiteigenschaft;

  /// Kuerzel der zugehoerigen Repraesentation, leer bei Traditionen ohne
  /// Spruchzauberei (Schamane, Derwisch, Zibilja, Zaubertaenzer, Durro-Dûn,
  /// Alchimist, Ferkina-Besessener).
  final String repraesentation;

  /// Weitere Schreibweisen, unter denen die Tradition in Katalogtexten und
  /// Ritualkenntnissen auftaucht (`RK Gildenmagie`, `gildenmagisch`).
  final List<String> aliasNamen;

  /// Alle Namen, unter denen diese Tradition erkannt wird.
  List<String> get alleNamen => <String>[name, ...aliasNamen];
}

/// Alle bekannten Zaubertraditionen.
///
/// Die Reihenfolge bestimmt die Anzeige in Auswahldialogen; bei den Geoden
/// steht der Herr der Erde zuerst, weil er die verbreitetere Auspraegung ist.
const List<TraditionDef> kTraditionen = <TraditionDef>[
  TraditionDef(
    id: 'achaz_kristallomant',
    name: 'Achaz-Kristallomant',
    leiteigenschaft: 'IN',
    repraesentation: 'Ach',
    aliasNamen: <String>[
      'Achaz',
      'Kristallomant',
      'Kristallomantie',
      'Kristallomantisch',
    ],
  ),
  TraditionDef(
    id: 'borbaradianer',
    name: 'Borbaradianer',
    leiteigenschaft: 'KL',
    repraesentation: 'Bor',
    aliasNamen: <String>['Borbaradianisch'],
  ),
  TraditionDef(
    id: 'druide',
    name: 'Druide',
    leiteigenschaft: 'KL',
    repraesentation: 'Dru',
    aliasNamen: <String>['Druiden', 'Druidisch'],
  ),
  TraditionDef(
    id: 'elf',
    name: 'Elf',
    leiteigenschaft: 'IN',
    repraesentation: 'Elf',
    aliasNamen: <String>['Elfen', 'Elfisch'],
  ),
  TraditionDef(
    id: 'geode_herr_der_erde',
    name: 'Geode (Herr der Erde)',
    leiteigenschaft: 'KL',
    repraesentation: 'Geo',
    aliasNamen: <String>[
      'Herr der Erde',
      'Herren der Erde',
      'Geode',
      'Geoden',
      'Geodisch',
    ],
  ),
  TraditionDef(
    id: 'geode_diener_sumus',
    name: 'Geode (Diener Sumus)',
    leiteigenschaft: 'IN',
    repraesentation: 'Geo',
    aliasNamen: <String>[
      'Diener Sumus',
      'Geode',
      'Geoden',
      'Geodisch',
    ],
  ),
  TraditionDef(
    id: 'hexe',
    name: 'Hexe',
    leiteigenschaft: 'IN',
    repraesentation: 'Hex',
    aliasNamen: <String>['Hexen', 'Hexisch', 'Saturaisch'],
  ),
  TraditionDef(
    id: 'gildenmagier',
    name: 'Gildenmagier',
    leiteigenschaft: 'KL',
    repraesentation: 'Mag',
    aliasNamen: <String>['Gildenmagie', 'Gildenmagisch', 'Magier'],
  ),
  TraditionDef(
    id: 'schelm',
    name: 'Schelm',
    leiteigenschaft: 'IN',
    repraesentation: 'Sch',
    aliasNamen: <String>['Schelme', 'Schelmisch'],
  ),
  TraditionDef(
    id: 'scharlatan',
    name: 'Scharlatan',
    leiteigenschaft: 'KL',
    repraesentation: 'Srl',
    aliasNamen: <String>['Scharlatane', 'Scharlatanisch'],
  ),
  // Traditionen mit Ritualkenntnis, aber ohne Repraesentation.
  TraditionDef(
    id: 'alchimist',
    name: 'Alchimist',
    leiteigenschaft: 'KL',
    aliasNamen: <String>['Alchimie', 'Alchimisten'],
  ),
  TraditionDef(
    id: 'zibilja',
    name: 'Zibilja',
    leiteigenschaft: 'KL',
    aliasNamen: <String>['Zibiljas'],
  ),
  TraditionDef(
    id: 'derwisch',
    name: 'Derwisch',
    leiteigenschaft: 'IN',
    aliasNamen: <String>['Derwische'],
  ),
  TraditionDef(
    id: 'durro_dun',
    name: 'Durro-Dûn',
    leiteigenschaft: 'IN',
    aliasNamen: <String>['Durro Dun', 'Durro-Dun'],
  ),
  TraditionDef(
    id: 'ferkina_besessener',
    name: 'Ferkina-Besessener',
    leiteigenschaft: 'IN',
    aliasNamen: <String>['Ferkina', 'Ferkina-Besessene'],
  ),
  TraditionDef(
    id: 'schamane',
    name: 'Schamane',
    leiteigenschaft: 'IN',
    aliasNamen: <String>['Schamanen', 'Schamanistisch', 'Geister Binden'],
  ),
  TraditionDef(
    id: 'zaubertaenzer',
    name: 'Zaubertänzer',
    leiteigenschaft: 'IN',
    aliasNamen: <String>['Zaubertanz', 'Zaubertänze'],
  ),
];

/// Sucht eine Tradition ueber ihren Namen oder eine Alias-Schreibweise.
///
/// Der Vergleich ist umlaut- und schreibweisentolerant und ignoriert die in
/// Katalogtexten uebliche Vorsilbe `RK`/`Ritualkenntnis`. `null`, wenn nichts
/// passt — der Aufrufer behandelt den Namen dann als Freitext.
TraditionDef? traditionByName(String name) {
  final treffer = traditionenByName(name);
  return treffer.isEmpty ? null : treffer.first;
}

/// Alle Traditionen, auf die [name] passt.
///
/// Meist genau eine. Ein unspezifisches `Geode` trifft dagegen beide
/// geodischen Auspraegungen — genau so ist es in Katalogtexten gemeint
/// ("RK Druide oder RK Geode"), und ein Held mit einer der beiden erfuellt die
/// Bedingung.
List<TraditionDef> traditionenByName(String name) {
  final needle = _normalizeTraditionName(name);
  if (needle.isEmpty) {
    return const <TraditionDef>[];
  }
  final idNeedle = needle.replaceAll(' ', '_');
  return kTraditionen
      .where(
        (tradition) =>
            tradition.id == idNeedle ||
            tradition.alleNamen.any(
              (kandidat) => _normalizeTraditionName(kandidat) == needle,
            ),
      )
      .toList(growable: false);
}

/// Sucht eine Tradition ueber ihre stabile [TraditionDef.id].
TraditionDef? traditionById(String id) {
  final needle = id.trim();
  for (final tradition in kTraditionen) {
    if (tradition.id == needle) {
      return tradition;
    }
  }
  return null;
}

/// Alle Traditionen, die zu einem Repraesentationskuerzel gehoeren.
///
/// Nur `Geo` liefert mehr als eine: Herren der Erde und Diener Sumus teilen
/// sich die geodische Repraesentation, haben aber verschiedene
/// Leiteigenschaften.
List<TraditionDef> traditionenFuerRepraesentation(String kuerzel) {
  final needle = _normalizeTraditionName(kuerzel);
  if (needle.isEmpty) {
    return const <TraditionDef>[];
  }
  return kTraditionen
      .where(
        (tradition) =>
            _normalizeTraditionName(tradition.repraesentation) == needle,
      )
      .toList(growable: false);
}

/// Ob der Nutzer beim Erwerb dieser Repraesentation die Tradition waehlen muss.
bool repraesentationBrauchtTraditionswahl(String kuerzel) =>
    traditionenFuerRepraesentation(kuerzel).length > 1;

/// Loest die Traditionen eines Helden auf.
///
/// [repraesentationen] sind die Kuerzel aus `HeroSheet.representationen`,
/// [gewaehlteTraditionen] die bewusst gewaehlte Auspraegung je Kuerzel
/// (`Geo` → `geode_diener_sumus`), [ritualkenntnisse] die Namen der
/// Ritualkategorien des Helden.
///
/// Ist bei einer mehrdeutigen Repraesentation nichts gewaehlt, liefert die
/// Funktion bewusst alle Kandidaten: Das ist der Zustand direkt nach dem
/// Laden eines Altbestands, und eine zu enge Annahme wuerde dort faelschlich
/// Voraussetzungen als unerfuellt melden.
List<TraditionDef> resolveHeroTraditionen({
  Iterable<String> repraesentationen = const <String>[],
  Map<String, String> gewaehlteTraditionen = const <String, String>{},
  Iterable<String> ritualkenntnisse = const <String>[],
}) {
  final result = <TraditionDef>[];
  final seen = <String>{};

  void add(TraditionDef? tradition) {
    if (tradition != null && seen.add(tradition.id)) {
      result.add(tradition);
    }
  }

  for (final kuerzel in repraesentationen) {
    final gewaehlt = gewaehlteTraditionen[kuerzel.trim()];
    final kandidaten = traditionenFuerRepraesentation(kuerzel);
    if (gewaehlt != null && gewaehlt.trim().isNotEmpty) {
      final tradition =
          traditionById(gewaehlt) ?? traditionByName(gewaehlt);
      if (tradition != null && tradition.repraesentation == kuerzel.trim()) {
        add(tradition);
        continue;
      }
    }
    kandidaten.forEach(add);
  }

  // Eine getroffene Traditionswahl darf durch eine unspezifische
  // Ritualkenntnis nicht wieder aufgeweicht werden: Wer sich als Diener Sumus
  // eingetragen hat, wird durch die Ritualkategorie „Geode“ nicht zusaetzlich
  // zum Herrn der Erde.
  final entschiedeneRepraesentationen = gewaehlteTraditionen.entries
      .where((eintrag) => eintrag.value.trim().isNotEmpty)
      .map((eintrag) => eintrag.key.trim())
      .toSet();
  for (final kenntnis in ritualkenntnisse) {
    for (final tradition in traditionenByName(kenntnis)) {
      if (tradition.repraesentation.isNotEmpty &&
          entschiedeneRepraesentationen.contains(tradition.repraesentation) &&
          !seen.contains(tradition.id)) {
        continue;
      }
      add(tradition);
    }
  }

  return List<TraditionDef>.unmodifiable(result);
}

/// Die Leiteigenschafts-Kuerzel zu einer Menge von Traditionen.
///
/// Ein nicht leerer [override] (das manuelle Feld `HeroSheet.magicLeadAttribute`)
/// schlaegt die Traditionen: Der Nutzer hat dann bewusst eine abweichende
/// Leiteigenschaft eingetragen, etwa fuer eine Hausregel-Tradition.
Set<String> leiteigenschaftenFuer(
  Iterable<TraditionDef> traditionen, {
  String override = '',
}) {
  final gesetzt = override.trim().toUpperCase();
  if (gesetzt.isNotEmpty) {
    return <String>{gesetzt};
  }
  return traditionen
      .map((tradition) => tradition.leiteigenschaft)
      .where((code) => code.isNotEmpty)
      .toSet();
}

/// Normalisiert Traditionsnamen fuer den Vergleich.
///
/// Entfernt die in Katalogtexten uebliche Vorsilbe `RK` bzw. `Ritualkenntnis`
/// und faltet danach Umlaute und Sonderzeichen wie beim Sonderfertigkeits-
/// Abgleich.
String _normalizeTraditionName(String value) {
  var text = value.trim();
  final vorsilbe = RegExp(
    r'^(rk|rkw|ritualkenntnis)\b[\s:]*',
    caseSensitive: false,
  );
  text = text.replaceFirst(vorsilbe, '');
  return normalizeSpecialAbilityName(text);
}
