/// Strukturierte Erwerbsvoraussetzungen fuer Katalogeintraege.
///
/// Der Freitext `voraussetzungen` bleibt die Anzeigequelle des Regelwerks;
/// dieser Strukturblock ergaenzt ihn maschinenlesbar, damit die App pruefen
/// kann, ob ein Held eine Sonderfertigkeit erwerben darf. Beide Quellen stehen
/// bewusst nebeneinander: So bleiben Hausregel-Pakete und Altbestaende ohne
/// Strukturblock uneingeschraenkt nutzbar.
library;

import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Art einer einzelnen Erwerbsvoraussetzung.
enum RequirementArt {
  /// Mindestwert einer konkreten Eigenschaft, z. B. `MU 15`.
  eigenschaft,

  /// Mindestwert der Leiteigenschaft; welche das ist, entscheidet die
  /// Tradition des Helden (Wege der Zauberei S. 19).
  leiteigenschaft,

  /// Eine andere Sonderfertigkeit, optional ab einer bestimmten Kettenstufe.
  sonderfertigkeit,

  /// Mindest-ZfW eines Zaubers, z. B. `ARCANOVI 14`.
  zauber,

  /// Mindest-TaW eines Talents, z. B. `Magiekunde 11`.
  talent,

  /// Ritualkenntnis einer Tradition, optional mit Mindest-RkW.
  ritualkenntnis,

  /// Zugehoerigkeit zu einer von mehreren Traditionen.
  tradition,

  /// Kenntnis eines Merkmals; ohne `merkmal` genuegt eine beliebige.
  merkmalskenntnis,

  /// Ein erforderlicher Vorteil.
  vorteil,

  /// Ein Nachteil, den der Held gerade nicht haben darf.
  nachteilVerboten,

  /// Ein Nachteil, den der Held haben muss. Klingt paradox, kommt aber vor:
  /// Berserkerfinesse verlangt „Vorteil Kampfrausch oder Nachteil Blutrausch“.
  nachteil,

  /// Zugehoerigkeit zu einer von mehreren Rassen.
  rasse,

  /// Eine Rasse, die der Held gerade nicht sein darf („kein Zwerg“).
  rasseVerboten,

  /// Mindestwert eines abgeleiteten Kampf-Basiswerts (`AT`, `PA`, `FK`, `INI`).
  /// Die Regelwerke formulieren das als „AT/PA-Basis 10“ oder
  /// „INI-Basiswert 10“.
  basiswert,

  /// Ein erlerntes Manoever. Viele Kampf-Sonderfertigkeiten bauen darauf auf
  /// (`Klingenwand`, `Sturmangriff`); Manoever stehen im eigenen Katalog
  /// `manoever.json` und sind deshalb keine [sonderfertigkeit].
  manoever,

  /// Eine Waffenmeisterschaft. Ohne `name` genuegt eine beliebige, sonst muss
  /// sie auf das genannte Kampftalent lauten. Eigene Art, weil Waffenmeister
  /// im Heldenmodell als `combatConfig.waffenmeisterschaften` steht und nicht
  /// unter den Sonderfertigkeits-Namen auftaucht.
  waffenmeister,

  /// Der Held muss Spruchzauberer sein (mindestens eine Repraesentation).
  spruchzauberer,

  /// Mindestens eine der enthaltenen Bedingungen muss erfuellt sein.
  oderGruppe,

  /// Alle enthaltenen Bedingungen muessen erfuellt sein. Nur als Zweig einer
  /// [oderGruppe] sinnvoll — auf oberster Ebene sind Bedingungen ohnehin
  /// UND-verknuepft. Deckt Regeltexte wie „KL 24 und IN 23 oder IN 26 und
  /// KL 20“ ab.
  undGruppe,

  /// Nicht pruefbarer Regeltext (Lehrmeister, Kontemplation, Zugang zu
  /// Buechern). Wird angezeigt, gilt aber nie als unerfuellt.
  hinweis,

  /// Im Katalog stand eine Art, die diese App nicht kennt. Verhaelt sich wie
  /// [hinweis], laesst sich aber im Katalogtest gezielt aufspueren.
  unbekannt,
}

/// Uebersetzt die JSON-Schluessel der Katalogdateien in [RequirementArt].
const Map<String, RequirementArt> _artByKey = <String, RequirementArt>{
  'eigenschaft': RequirementArt.eigenschaft,
  'leiteigenschaft': RequirementArt.leiteigenschaft,
  'sonderfertigkeit': RequirementArt.sonderfertigkeit,
  'zauber': RequirementArt.zauber,
  'talent': RequirementArt.talent,
  'ritualkenntnis': RequirementArt.ritualkenntnis,
  'tradition': RequirementArt.tradition,
  'merkmalskenntnis': RequirementArt.merkmalskenntnis,
  'vorteil': RequirementArt.vorteil,
  'nachteil_verboten': RequirementArt.nachteilVerboten,
  'nachteil': RequirementArt.nachteil,
  'rasse': RequirementArt.rasse,
  'rasse_verboten': RequirementArt.rasseVerboten,
  'basiswert': RequirementArt.basiswert,
  'manoever': RequirementArt.manoever,
  'waffenmeister': RequirementArt.waffenmeister,
  'spruchzauberer': RequirementArt.spruchzauberer,
  'oder': RequirementArt.oderGruppe,
  'und': RequirementArt.undGruppe,
  'hinweis': RequirementArt.hinweis,
};

/// Eine einzelne Erwerbsvoraussetzung.
///
/// Bewusst ein einziger Typ mit optionalen Feldern statt einer Klassenhierarchie:
/// Die Bedingungen werden ausschliesslich aus JSON gelesen, in einer flachen
/// Liste ausgewertet und als Checkliste angezeigt — eine Hierarchie wuerde
/// Parser und UI nur aufblaehen, ohne etwas zu gewinnen.
class SpecialAbilityRequirement {
  /// Erzeugt eine unveraenderliche Voraussetzung.
  const SpecialAbilityRequirement({
    required this.art,
    this.code = '',
    this.name = '',
    this.namen = const <String>[],
    this.min,
    this.stufe,
    this.text = '',
    this.bedingungen = const <SpecialAbilityRequirement>[],
  });

  /// Art der Bedingung; entscheidet, welche Felder gefuellt sind.
  final RequirementArt art;

  /// Eigenschaftskuerzel (`MU`, `KL`, …) bei [RequirementArt.eigenschaft].
  final String code;

  /// Name des referenzierten Objekts (Sonderfertigkeit, Zauber, Talent,
  /// Vorteil, Nachteil, Merkmal, Tradition).
  final String name;

  /// Mehrere gleichwertige Namen (Traditionen, Rassen) — eine Uebereinstimmung
  /// genuegt.
  final List<String> namen;

  /// Geforderter Mindestwert, sofern die Art einen kennt.
  final int? min;

  /// Geforderte Kettenstufe einer Sonderfertigkeit.
  final int? stufe;

  /// Anzeigetext fuer [RequirementArt.hinweis] und [RequirementArt.unbekannt].
  final String text;

  /// Teilbedingungen einer [RequirementArt.oderGruppe] oder
  /// [RequirementArt.undGruppe].
  final List<SpecialAbilityRequirement> bedingungen;

  /// Alle Namen dieser Bedingung — `name` und `namen` zusammengefasst.
  List<String> get alleNamen => <String>[
    if (name.trim().isNotEmpty) name.trim(),
    ...namen.where((eintrag) => eintrag.trim().isNotEmpty),
  ];

  /// Liest eine Bedingung tolerant aus JSON; unbekannte Arten werden zu
  /// [RequirementArt.unbekannt] statt einen Ladefehler auszuloesen.
  factory SpecialAbilityRequirement.fromJson(Map<String, dynamic> json) {
    final artKey = readCatalogString(json, 'art', fallback: '').trim();
    final art = _artByKey[artKey] ?? RequirementArt.unbekannt;
    return SpecialAbilityRequirement(
      art: art,
      code: readCatalogString(json, 'code', fallback: '').trim(),
      name: readCatalogString(json, 'name', fallback: '').trim(),
      namen: readCatalogStringList(json, 'namen'),
      min: _readNullableInt(json, 'min'),
      stufe: _readNullableInt(json, 'stufe'),
      text: readCatalogString(
        json,
        'text',
        fallback: art == RequirementArt.unbekannt ? artKey : '',
      ),
      bedingungen: readCatalogObjectList(json, 'bedingungen')
          .map(SpecialAbilityRequirement.fromJson)
          .toList(growable: false),
    );
  }

  /// Serialisiert die Bedingung; leere Felder bleiben weg.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'art': _keyForArt(art),
      if (code.isNotEmpty) 'code': code,
      if (name.isNotEmpty) 'name': name,
      if (namen.isNotEmpty) 'namen': namen,
      if (min != null) 'min': min,
      if (stufe != null) 'stufe': stufe,
      if (text.isNotEmpty) 'text': text,
      if (bedingungen.isNotEmpty)
        'bedingungen': bedingungen
            .map((bedingung) => bedingung.toJson())
            .toList(growable: false),
    };
  }
}

/// Zuordnung eines Katalogeintrags zu einer Stufenkette.
///
/// Eine Kette besteht aus mehreren Katalogeintraegen, die dieselbe [id] tragen
/// und sich nur in der [stufe] unterscheiden — `Eiserner Wille I` und
/// `Eiserner Wille II` sind zwei Eintraege derselben Kette. Die Regelwerke
/// vergeben je Stufe eigene AP-Kosten und Voraussetzungen; deshalb bleibt jede
/// Stufe ein eigenstaendiger Eintrag statt einer Liste in einem Sammeleintrag.
class SpecialAbilityChainRef {
  /// Erzeugt eine unveraenderliche Kettenzuordnung.
  const SpecialAbilityChainRef({
    required this.id,
    this.stufe = 1,
    this.label = '',
  });

  /// Gemeinsame Kennung aller Stufen einer Kette.
  final String id;

  /// Position dieses Eintrags in der Kette, beginnend bei 1.
  final int stufe;

  /// Anzeigename der Kette; leer bedeutet, dass die UI den Basisnamen der
  /// ersten Stufe verwendet.
  final String label;

  /// Liest eine Kettenzuordnung tolerant aus JSON.
  factory SpecialAbilityChainRef.fromJson(Map<String, dynamic> json) {
    return SpecialAbilityChainRef(
      id: readCatalogString(json, 'id', fallback: '').trim(),
      stufe: readCatalogInt(json, 'stufe', fallback: 1),
      label: readCatalogString(json, 'label', fallback: '').trim(),
    );
  }

  /// Serialisiert die Kettenzuordnung.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'stufe': stufe,
      if (label.isNotEmpty) 'label': label,
    };
  }
}

String _keyForArt(RequirementArt art) {
  for (final entry in _artByKey.entries) {
    if (entry.value == art) {
      return entry.key;
    }
  }
  return 'hinweis';
}

int? _readNullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
