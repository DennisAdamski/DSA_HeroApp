/// Elementare Hexalogien und das Siegel der Elemente.
///
/// Quelle: Wege der Zauberei S. 382–386 („Hexalogien“, „Bekannte Hexalogien“)
/// und die Anmerkungen im Liber Cantiones. Eine Hexalogie ist eine Gruppe von
/// Zaubern mit je einer Entsprechung in allen sechs Elementen. Ihre Zauber sind
/// eng verwandt: Der Zauber mit dem höchsten ZfW wird normal gesteigert, alle
/// anderen eine Spalte leichter aktiviert und bis zu diesem ZfW leichter
/// gesteigert. Die Tabelle nennt nur Zauber, die der Basiskatalog führt; ein
/// Test gleicht sie mit ihm ab.
library;

/// Die sechs Elemente der Magie (nicht zu verwechseln mit Flutters `Element`).
enum Magieelement {
  /// Feuer.
  feuer('Feuer'),

  /// Wasser.
  wasser('Wasser'),

  /// Humus.
  humus('Humus'),

  /// Eis.
  eis('Eis'),

  /// Erz.
  erz('Erz'),

  /// Luft.
  luft('Luft');

  const Magieelement(this.anzeige);

  /// Name, wie er im Merkmal `Elementar (…)` steht.
  final String anzeige;

  /// Gegenelement nach dem Siegel der Elemente (WdZ S. 382): Feuer–Wasser,
  /// Erz–Luft, Humus–Eis.
  Magieelement get gegenelement => switch (this) {
    Magieelement.feuer => Magieelement.wasser,
    Magieelement.wasser => Magieelement.feuer,
    Magieelement.erz => Magieelement.luft,
    Magieelement.luft => Magieelement.erz,
    Magieelement.humus => Magieelement.eis,
    Magieelement.eis => Magieelement.humus,
  };

  /// Merkmal in der Schreibweise des Katalogs, etwa `Elementar (Erz)`.
  String get merkmal => 'Elementar ($anzeige)';
}

/// Das Magieelement hinter einem Merkmal `Elementar (…)`; `null` für „allgemein“
/// und für alle anderen Merkmale.
Magieelement? elementAusMerkmal(String merkmal) {
  final text = merkmal.trim().toLowerCase();
  for (final element in Magieelement.values) {
    if (text == element.merkmal.toLowerCase()) return element;
  }
  return null;
}

/// Das einzige Magieelement eines Zaubers; `null`, wenn er keines oder mehrere
/// (etwa Luft und Wasser beim Nebelleib) trägt.
Magieelement? einzigesElement(Iterable<String> merkmale) {
  final elemente = <Magieelement>{
    for (final m in merkmale) ?elementAusMerkmal(m),
  };
  return elemente.length == 1 ? elemente.single : null;
}

/// Eine Hexalogie mit den Zaubern, die der Basiskatalog kennt.
class HexalogieDef {
  /// Erzeugt die Hexalogie [name] aus den Zauber-IDs [zauberIds].
  const HexalogieDef(this.name, this.zauberIds);

  /// Anzeigename, etwa „Elementare Wände“.
  final String name;

  /// IDs der Zauber im Katalog.
  final List<String> zauberIds;
}

/// Hexalogien mit mindestens zwei Zaubern im Basiskatalog.
const List<HexalogieDef> kHexalogien = <HexalogieDef>[
  HexalogieDef('Elementare Wände', <String>[
    'spell_wand_aus_flammen',
    'spell_wand_aus_erz',
    'spell_wand_aus_luft',
    'spell_wand_aus_wasser',
    'spell_wand_aus_dornen',
    'spell_gletscherwand',
  ]),
  HexalogieDef('Elementare Geschosse', <String>[
    'spell_ignifaxius',
    'spell_archofaxius',
    'spell_orcanofaxius',
    'spell_frigifaxius',
    'spell_aquafaxius',
    'spell_humofaxius',
  ]),
  HexalogieDef('Elementare Explosionen', <String>[
    'spell_ignisphaero',
    'spell_archosphaero',
    'spell_orcanosphaero',
    'spell_frigisphaero',
    'spell_aquasphaero',
    'spell_humosphaero',
  ]),
  HexalogieDef('Elementare Leiber', <String>[
    'spell_leib_des_feuers',
    'spell_leib_des_erzes',
    'spell_leib_des_windes',
    'spell_leib_des_eises',
    'spell_leib_der_wogen',
    'spell_leib_der_erde',
  ]),
  HexalogieDef('Elementare Verzauberung eines Geschosses', <String>[
    'spell_pfeil_des_feuers',
    'spell_pfeil_des_erzes',
    'spell_pfeil_der_luft',
    'spell_pfeil_des_eises',
    'spell_pfeil_des_wassers',
    'spell_pfeil_des_humus',
  ]),
  HexalogieDef('Elementare Bewegung', <String>[
    'spell_firnlauf',
    'spell_wellenlauf',
    'spell_wipfellauf',
  ]),
  HexalogieDef('Elementare Wirbel', <String>[
    'spell_mahlstrom',
    'spell_windhose',
  ]),
];

/// Die Hexalogie, zu der der Zauber [zauberId] gehört; `null` sonst.
HexalogieDef? hexalogieFuerZauber(String zauberId) {
  for (final hexalogie in kHexalogien) {
    if (hexalogie.zauberIds.contains(zauberId)) return hexalogie;
  }
  return null;
}
