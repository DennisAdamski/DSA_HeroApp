import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kraeutersuche_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';

// Regelgrundlage: Wege des Entdeckers S. 107–113 („Probenmodifikationen je
// nach Region“ bei Pirsch-, Ansitz- und Hetzjagd, Angeln, Speerfischen,
// Tierfallen und Nahrung sammeln). Die Regionen entsprechen den
// Landschaftstabellen der Kräutersuche (S. 115–118) plus dem Ewigen Eis, das
// nur bei der Nahrungsbeschaffung vorkommt.

/// Eine Region der Nahrungsbeschaffung (Wege des Entdeckers S. 107–113).
///
/// Die Schlüssel ([name]) der zwölf Landschaften, die auch die Kräutersuche
/// kennt, stimmen mit [Kraeuterlandschaft] überein; so bleibt die Wahl beim
/// Wechsel zwischen den Tätigkeiten der Wildnis-Kachel erhalten.
enum Wildnisregion {
  /// Lichter Wald.
  lichterWald('Lichter Wald'),

  /// Dichter Wald.
  dichterWald('Dichter Wald'),

  /// Dschungel und Regenwald (außer Maraskan).
  dschungel('Dschungel und Regenwald'),

  /// Maraskanischer Dschungel.
  maraskanDschungel('Maraskanischer Dschungel'),

  /// Nördliche Sümpfe und Moore.
  suempfeNord('Nördliche Sümpfe und Moore'),

  /// Südliche Sümpfe und Marschen.
  suempfeSued('Südliche Sümpfe und Marschen'),

  /// Tundra.
  tundra('Tundra'),

  /// Grasland und Heide.
  graslandHeide('Grasland und Heide'),

  /// Savanne und Steppe.
  savanneSteppe('Savanne und Steppe'),

  /// Gebirge.
  gebirge('Gebirge'),

  /// Hochgebirge.
  hochgebirge('Hochgebirge'),

  /// Wüste.
  wueste('Wüste'),

  /// Ewiges Eis.
  ewigesEis('Ewiges Eis');

  const Wildnisregion(this.bezeichnung);

  /// Anzeigename.
  final String bezeichnung;

  /// Region zum Schlüssel, sonst `null`.
  static Wildnisregion? ausSchluessel(Object? schluessel) =>
      Wildnisregion.values.asNameMap()[schluessel];

  /// Die gleichnamige Landschaft der Kräutersuche; `null` für das Ewige Eis.
  Kraeuterlandschaft? get kraeuterlandschaft =>
      Kraeuterlandschaft.ausSchluessel(name);
}

/// Die Region als Landschaftsoption der Wildnis-Kachel, samt den Geländearten,
/// für die eine Geländekunde passt (wie bei der Kräutersuche; das Ewige Eis
/// verlangt Eiskundig).
WildnisLandschaft wildnisRegionAlsLandschaft(Wildnisregion region) {
  final kraeuter = region.kraeuterlandschaft;
  if (kraeuter != null) {
    final landschaft = kraeuterLandschaftAlsWildnis(kraeuter);
    return WildnisLandschaft(
      schluessel: region.name,
      bezeichnung: region.bezeichnung,
      gelaende: landschaft.gelaende,
      aehnlicheGelaende: landschaft.aehnlicheGelaende,
    );
  }
  return WildnisLandschaft(
    schluessel: region.name,
    bezeichnung: region.bezeichnung,
    gelaende: const <Gelaendeart>{Gelaendeart.eis},
  );
}

/// Alle Regionen als Landschaftsoptionen.
List<WildnisLandschaft> wildnisRegionenAlsLandschaften() => <WildnisLandschaft>[
  for (final region in Wildnisregion.values) wildnisRegionAlsLandschaft(region),
];

/// Regionen, die zu einem Ort des Ortsverzeichnisses passen.
///
/// Wie [kraeuterLandschaftenFuerOrt]; zusätzlich führen Eiswüsten ins Ewige
/// Eis und Gletscher wahlweise ins Hochgebirge oder ins Ewige Eis.
List<Wildnisregion> wildnisRegionenFuerOrt(OrtEintrag ort) {
  if (ort.art != OrtArt.region) return const <Wildnisregion>[];
  final art = ort.unterart
      .replaceAll(RegExp(r'\s*\(.*\)\s*'), '')
      .trim()
      .toLowerCase();
  switch (art) {
    case 'eiswüste' || 'eis' || 'packeis':
      return const <Wildnisregion>[Wildnisregion.ewigesEis];
    case 'gletscher':
      return const <Wildnisregion>[
        Wildnisregion.hochgebirge,
        Wildnisregion.ewigesEis,
      ];
  }
  return <Wildnisregion>[
    for (final landschaft in kraeuterLandschaftenFuerOrt(ort))
      ?Wildnisregion.ausSchluessel(landschaft.name),
  ];
}

/// Die Region zum Schlüssel einer Landschaftsoption; wirft bei unbekanntem
/// Schlüssel, weil die Kachel nur eigene Landschaften anbietet.
Wildnisregion wildnisRegionZuLandschaft(WildnisLandschaft landschaft) {
  final region = Wildnisregion.ausSchluessel(landschaft.schluessel);
  if (region == null) {
    throw StateError('Unbekannte Region ${landschaft.schluessel}.');
  }
  return region;
}
