/// Rein dekorative Grundformen; sie verleihen keine regeltechnischen Merkmale.
enum KartoSiegelMotiv {
  /// Neutraler Kompass für fehlende oder unbekannte Angaben.
  neutral,

  /// Heraldische Schildform.
  mensch,

  /// Geschwungene Blattlinien.
  elf,

  /// Heraldische Form mit Blattlinie.
  halbelf,

  /// Kantige Gravur.
  zwerg,

  /// Überlappende Schuppenrauten.
  echse,

  /// Paarweise gebogene Spitzen.
  ork,

  /// Drei versetzte Wegmarken.
  goblin,
}

/// Kosmetisches Profil aus Rassenangabe und bereits berechneten Befähigungen.
class KartoSiegelProfil {
  /// Erstellt ein unabhängiges Grundmotiv mit kombinierbaren Zusatzzeichen.
  const KartoSiegelProfil({
    this.motiv = KartoSiegelMotiv.neutral,
    this.magisch = false,
    this.karmal = false,
  });

  /// Ordnet nur bekannte Schreibweisen zu; freie unbekannte Texte bleiben neutral.
  factory KartoSiegelProfil.ausAngaben({
    required String rasse,
    bool magisch = false,
    bool karmal = false,
  }) {
    var normal = rasse.toLowerCase();
    for (final ersatz in const {'ä': 'ae', 'ö': 'oe', 'ü': 'ue'}.entries) {
      normal = normal.replaceAll(ersatz.key, ersatz.value);
    }
    normal = normal.replaceAll(
      RegExp(r'\bhalb[\s-]+elf(?:e|en)?\b'),
      'halbelf',
    );
    final woerter = normal.split(RegExp('[^a-z]+')).toSet();
    final treffer = <KartoSiegelMotiv>{};
    for (final gruppe in _motive.entries) {
      if (gruppe.value.any(woerter.contains)) {
        treffer.add(gruppe.key);
      }
    }
    // Benannte Halbelfen dürfen ihre beiden Abstammungen erläutern. Andere
    // Mischangaben werden nicht nach der Reihenfolge der Aliasliste gewertet.
    if (treffer.contains(KartoSiegelMotiv.halbelf)) {
      treffer.removeAll({KartoSiegelMotiv.mensch, KartoSiegelMotiv.elf});
    }
    final motiv = treffer.length == 1
        ? treffer.single
        : KartoSiegelMotiv.neutral;
    return KartoSiegelProfil(motiv: motiv, magisch: magisch, karmal: karmal);
  }

  /// Grundmotiv bleibt auch für profane Helden vollständig.
  final KartoSiegelMotiv motiv;

  /// Vorhandene Magiebefähigung, niemals aus der Rasse abgeleitet.
  final bool magisch;

  /// Vorhandene Karmabefähigung, unabhängig von der Magiebefähigung.
  final bool karmal;

  /// Kurze Erklärung für den rein visuellen Tooltip.
  String get beschreibung {
    final grund = switch (motiv) {
      KartoSiegelMotiv.neutral => 'Neutrales Heldensiegel',
      KartoSiegelMotiv.mensch => 'Heraldisches Heldensiegel',
      KartoSiegelMotiv.elf => 'Elfisches Blattsiegel',
      KartoSiegelMotiv.halbelf => 'Halbelfisches Blattsiegel',
      KartoSiegelMotiv.zwerg => 'Zwergisches Gravursiegel',
      KartoSiegelMotiv.echse => 'Schuppensiegel',
      KartoSiegelMotiv.ork => 'Orkisches Spitzensiegel',
      KartoSiegelMotiv.goblin => 'Goblinisches Wegsiegel',
    };
    return [
      grund,
      if (magisch) 'Astraler Akzent',
      if (karmal) 'Karmaler Akzent',
    ].join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is KartoSiegelProfil &&
      other.motiv == motiv &&
      other.magisch == magisch &&
      other.karmal == karmal;

  @override
  int get hashCode => Object.hash(motiv, magisch, karmal);
}

// Explizite Aliasgruppen statt Teilwortsuche: „Menschenfreund“ ist keine Rasse.
const _motive = <KartoSiegelMotiv, Set<String>>{
  KartoSiegelMotiv.halbelf: {'halbelf', 'halbelfe', 'halbelfen'},
  KartoSiegelMotiv.elf: {
    'elf',
    'elfe',
    'elfen',
    'auelf',
    'auelfen',
    'waldelf',
    'waldelfen',
    'firnelf',
    'firnelfen',
    'steppenelf',
    'steppenelfen',
  },
  KartoSiegelMotiv.zwerg: {
    'zwerg',
    'zwerge',
    'zwergin',
    'ambosszwerg',
    'ambosszwerge',
    'huegelzwerg',
    'huegelzwerge',
    'erzzwerg',
    'erzzwerge',
    'brillantzwerg',
    'brillantzwerge',
  },
  KartoSiegelMotiv.echse: {
    'achaz',
    'echse',
    'echsen',
    'echsenmensch',
    'echsenmenschen',
  },
  KartoSiegelMotiv.ork: {'ork', 'orks', 'orkin', 'halbork'},
  KartoSiegelMotiv.goblin: {'goblin', 'goblins', 'goblinin'},
  KartoSiegelMotiv.mensch: {
    'mensch',
    'menschen',
    'mittellaender',
    'tulamide',
    'tulamidin',
    'thorwaler',
    'thorwalerin',
    'nivese',
    'nivesin',
    'norbarde',
    'norbardin',
    'waldmensch',
    'waldmenschen',
    'utulu',
    'trollzacker',
    'moha',
  },
};
