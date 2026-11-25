/// Szenen des Klangpults: jede bündelt Ambiente-Ebenen, Musik und
/// Einzeleffekte als hinterlegte Freesound-Suchen.
///
/// Gesucht wird englisch, weil die meisten Klänge bei Freesound so
/// verschlagwortet sind.
library;

/// Eine Ambiente-Ebene, die als Schleife läuft.
class Klangebene {
  /// Erstellt die Ebene.
  const Klangebene(
    this.id,
    this.titel,
    this.anfrage, {
    this.mindestSekunden = 30,
    this.staerke = 0.6,
  });

  /// Kennung, eindeutig innerhalb der Szene.
  final String id;

  /// Anzeigename.
  final String titel;

  /// Suchbegriffe bei Freesound.
  final String anfrage;

  /// Kürzeste Länge eines Treffers; kurze Effekte taugen nicht als Schleife.
  final double mindestSekunden;

  /// Anfangsstärke von 0 bis 1.
  final double staerke;
}

/// Lage der Musik.
enum Musiklage {
  /// Ruhige Begleitung.
  erkunden('Erkunden'),

  /// Treibende Kampfmusik.
  kampf('Kampf'),

  /// Einmaliger Siegesklang, läuft ohne Schleife.
  sieg('Sieg');

  const Musiklage(this.titel);

  /// Anzeigename.
  final String titel;
}

/// Standardsuchen der Musik, falls eine Szene keine eigene hat.
const Map<Musiklage, String> kMusikStandard = <Musiklage, String>{
  Musiklage.erkunden: 'medieval music loop',
  Musiklage.kampf: 'epic battle music loop',
  Musiklage.sieg: 'victory fanfare',
};

/// Ein Einzeleffekt zum Antippen.
class Klangeffekt {
  /// Erstellt den Effekt.
  const Klangeffekt(
    this.id,
    this.titel,
    this.anfrage, {
    this.hoechstSekunden = 6,
  });

  /// Stabile Kennung (auch szenenübergreifend für den Suchcache).
  final String id;

  /// Anzeigename.
  final String titel;

  /// Suchbegriffe bei Freesound.
  final String anfrage;

  /// Längste Länge eines Treffers.
  final double hoechstSekunden;
}

/// Eine Szene des Klangpults.
class Klangszene {
  /// Erstellt die Szene.
  const Klangszene(
    this.id,
    this.titel, {
    required this.ambiente,
    this.musik = const <Musiklage, String>{},
    this.effekte = const <Klangeffekt>[],
  });

  /// Stabile Kennung.
  final String id;

  /// Anzeigename.
  final String titel;

  /// Gleichzeitig laufende Ebenen.
  final List<Klangebene> ambiente;

  /// Eigene Musiksuchen; fehlende Lagen nehmen [kMusikStandard].
  final Map<Musiklage, String> musik;

  /// Angeheftete Einzeleffekte.
  final List<Klangeffekt> effekte;

  /// Suche für [lage].
  String musikAnfrage(Musiklage lage) => musik[lage] ?? kMusikStandard[lage]!;
}

const _tuer = Klangeffekt('tuer', 'Tür', 'wooden door creak');
const _schwert = Klangeffekt('schwert', 'Schwert', 'sword clash');
const _donner = Klangeffekt(
  'donner',
  'Donner',
  'thunder clap',
  hoechstSekunden: 10,
);
const _wolf = Klangeffekt(
  'wolf',
  'Wolfsheulen',
  'wolf howl',
  hoechstSekunden: 10,
);
const _schrei = Klangeffekt('schrei', 'Schrei', 'scream male');
const _glocke = Klangeffekt(
  'glocke',
  'Glocke',
  'church bell single',
  hoechstSekunden: 10,
);
const _muenzen = Klangeffekt('muenzen', 'Münzen', 'coins drop');
const _knurren = Klangeffekt('knurren', 'Knurren', 'monster growl');
const _pfeil = Klangeffekt('pfeil', 'Pfeil', 'arrow whoosh impact');
const _zauber = Klangeffekt('zauber', 'Zauber', 'magic spell cast');

/// Die festen Szenen in Anzeigereihenfolge.
const List<Klangszene> kKlangszenen = <Klangszene>[
  Klangszene(
    'taverne',
    'Taverne',
    ambiente: [
      Klangebene('menge', 'Gäste', 'tavern ambience crowd'),
      Klangebene('feuer', 'Kamin', 'fireplace crackling', staerke: 0.4),
    ],
    musik: {Musiklage.erkunden: 'tavern music medieval'},
    effekte: [
      _tuer,
      Klangeffekt('krug', 'Krüge', 'beer mugs clink'),
      _muenzen,
      Klangeffekt('lachen', 'Gelächter', 'crowd laugh'),
      _schwert,
    ],
  ),
  Klangszene(
    'stadt',
    'Stadt & Markt',
    ambiente: [
      Klangebene('markt', 'Markt', 'medieval market crowd ambience'),
      Klangebene(
        'pferde',
        'Pferde',
        'horse carriage cobblestone',
        staerke: 0.3,
      ),
    ],
    effekte: [
      _glocke,
      Klangeffekt('ausrufer', 'Ausrufer', 'town crier shout'),
      _muenzen,
      Klangeffekt('hund', 'Hund', 'dog bark'),
      _tuer,
    ],
  ),
  Klangszene(
    'wald',
    'Wald',
    ambiente: [
      Klangebene('voegel', 'Vögel', 'forest birds ambience'),
      Klangebene('wind', 'Blätter', 'wind leaves trees', staerke: 0.4),
      Klangebene('bach', 'Bach', 'stream water flowing', staerke: 0.3),
    ],
    effekte: [
      _wolf,
      Klangeffekt('ast', 'Ast bricht', 'branch snap'),
      Klangeffekt('rabe', 'Rabe', 'crow caw'),
      _pfeil,
      _knurren,
    ],
  ),
  Klangszene(
    'nachtlager',
    'Nachtlager',
    ambiente: [
      Klangebene('feuer', 'Lagerfeuer', 'campfire crackling'),
      Klangebene('grillen', 'Grillen', 'night crickets ambience', staerke: 0.4),
    ],
    musik: {Musiklage.erkunden: 'calm lute music'},
    effekte: [
      _wolf,
      Klangeffekt('eule', 'Eule', 'owl hoot'),
      Klangeffekt('ast', 'Ast bricht', 'branch snap'),
      _knurren,
    ],
  ),
  Klangszene(
    'hoehle',
    'Höhle & Gruft',
    ambiente: [
      Klangebene('tropfen', 'Tropfen', 'cave dripping ambience'),
      Klangebene('drohnen', 'Dunkelheit', 'dark ambient drone', staerke: 0.4),
    ],
    musik: {Musiklage.erkunden: 'dark dungeon music loop'},
    effekte: [
      Klangeffekt('stein', 'Steinschlag', 'rocks falling'),
      Klangeffekt('ketten', 'Ketten', 'chains rattle'),
      _knurren,
      Klangeffekt('fledermaus', 'Fledermäuse', 'bats flying'),
      _schrei,
    ],
  ),
  Klangszene(
    'sturm',
    'Sturm',
    ambiente: [
      Klangebene('regen', 'Regen', 'heavy rain ambience'),
      Klangebene('wind', 'Wind', 'wind howling', staerke: 0.5),
    ],
    effekte: [
      _donner,
      Klangeffekt('fenster', 'Fensterladen', 'shutter bang'),
      _tuer,
    ],
  ),
  Klangszene(
    'meer',
    'Meer & Schiff',
    ambiente: [
      Klangebene('wellen', 'Wellen', 'ocean waves'),
      Klangebene('holz', 'Schiffsholz', 'wooden ship creaking', staerke: 0.4),
      Klangebene('moewen', 'Möwen', 'seagulls', staerke: 0.3),
    ],
    musik: {Musiklage.erkunden: 'sea shanty music'},
    effekte: [
      Klangeffekt('schiffsglocke', 'Schiffsglocke', 'ship bell'),
      _donner,
      Klangeffekt('kanone', 'Kanone', 'cannon shot'),
      Klangeffekt('platsch', 'Platschen', 'water splash'),
    ],
  ),
  Klangszene(
    'tempel',
    'Tempel',
    ambiente: [
      Klangebene('chor', 'Chor', 'church choir ambience'),
      Klangebene('halle', 'Halle', 'cathedral room tone', staerke: 0.3),
    ],
    musik: {Musiklage.erkunden: 'sacred choir music'},
    effekte: [
      _glocke,
      _zauber,
      Klangeffekt('gong', 'Gong', 'gong hit', hoechstSekunden: 10),
    ],
  ),
  Klangszene(
    'wueste',
    'Wüste',
    ambiente: [
      Klangebene('wind', 'Wüstenwind', 'desert wind ambience'),
      Klangebene('sand', 'Sand', 'sand blowing', staerke: 0.3),
    ],
    musik: {Musiklage.erkunden: 'arabic oud music'},
    effekte: [
      Klangeffekt('kamel', 'Kamel', 'camel grunt'),
      _pfeil,
      _schwert,
      Klangeffekt('geier', 'Geier', 'vulture bird call'),
    ],
  ),
  Klangszene(
    'gebirge',
    'Gebirge & Schnee',
    ambiente: [
      Klangebene('sturm', 'Schneesturm', 'blizzard wind'),
      Klangebene(
        'schritte',
        'Schritte im Schnee',
        'footsteps snow',
        staerke: 0.3,
      ),
    ],
    effekte: [
      _wolf,
      Klangeffekt('lawine', 'Lawine', 'avalanche rumble', hoechstSekunden: 12),
      Klangeffekt('adler', 'Adler', 'eagle cry'),
      Klangeffekt('eis', 'Eis bricht', 'ice crack'),
    ],
  ),
  Klangszene(
    'sumpf',
    'Sumpf',
    ambiente: [
      Klangebene('froesche', 'Frösche', 'swamp frogs ambience'),
      Klangebene('blubbern', 'Blubbern', 'mud bubbling', staerke: 0.4),
      Klangebene('insekten', 'Insekten', 'insects buzzing', staerke: 0.3),
    ],
    effekte: [
      Klangeffekt('platsch', 'Platschen', 'water splash'),
      _knurren,
      _schrei,
      _zauber,
    ],
  ),
];
