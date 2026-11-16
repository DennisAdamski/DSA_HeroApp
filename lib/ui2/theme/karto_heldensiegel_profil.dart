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
///
/// Eine unterstützte menschliche Kultur ergänzt das Grundmotiv um ein Bildasset.
class KartoSiegelProfil {
  /// Erstellt ein unabhängiges Grundmotiv mit kombinierbaren Zusatzzeichen.
  const KartoSiegelProfil({
    this.motiv = KartoSiegelMotiv.neutral,
    this.magisch = false,
    this.karmal = false,
    this.kultur,
  });

  /// Ordnet nur bekannte Schreibweisen zu; freie unbekannte Texte bleiben neutral.
  factory KartoSiegelProfil.ausAngaben({
    required String rasse,
    String kultur = '',
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
    final kulturBasis = kultur.trim().isEmpty ? rasse : kultur;
    final erlaubtKultursiegel = const {
      KartoSiegelMotiv.neutral,
      KartoSiegelMotiv.mensch,
      KartoSiegelMotiv.halbelf,
    }.contains(motiv);
    return KartoSiegelProfil(
      motiv: motiv,
      magisch: magisch,
      karmal: karmal,
      kultur: erlaubtKultursiegel ? _kulturFuer(kulturBasis) : null,
    );
  }

  /// Grundmotiv bleibt auch für profane Helden vollständig.
  final KartoSiegelMotiv motiv;

  /// Vorhandene Magiebefähigung, niemals aus der Rasse abgeleitet.
  final bool magisch;

  /// Vorhandene Karmabefähigung, unabhängig von der Magiebefähigung.
  final bool karmal;

  /// Unterstützte eingetragene Kultur; unabhängig von Befähigungen.
  final KartoSiegelKultur? kultur;

  /// Fertiges Kultur- oder Speziesbild; unbekannte Angaben erhalten das neutrale Motiv.
  String? get assetPfad {
    final kultur = this.kultur;
    if (kultur != null) {
      return 'assets/ui/heldensiegel_v1/${kultur.name}.png';
    }
    final datei = motiv == KartoSiegelMotiv.echse ? 'achaz' : motiv.name;
    return 'assets/ui/heldensiegel_v1/$datei.png';
  }

  /// Kurze Erklärung für den rein visuellen Tooltip.
  String get beschreibung {
    final grundmotiv = switch (motiv) {
      KartoSiegelMotiv.neutral => 'Neutrales Heldensiegel',
      KartoSiegelMotiv.mensch => 'Heraldisches Heldensiegel',
      KartoSiegelMotiv.elf => 'Elfisches Blattsiegel',
      KartoSiegelMotiv.halbelf => 'Halbelfisches Blattsiegel',
      KartoSiegelMotiv.zwerg => 'Zwergisches Gravursiegel',
      KartoSiegelMotiv.echse => 'Schuppensiegel',
      KartoSiegelMotiv.ork => 'Orkisches Spitzensiegel',
      KartoSiegelMotiv.goblin => 'Goblinisches Wegsiegel',
    };
    final grund = kultur?.beschreibung ?? grundmotiv;
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
      other.kultur == kultur &&
      other.magisch == magisch &&
      other.karmal == karmal;

  @override
  int get hashCode => Object.hash(motiv, kultur, magisch, karmal);
}

/// Freigegebene menschliche Kultursiegel samt Beschriftung und Schreibweisen.
enum KartoSiegelKultur {
  /// Schiff, Wellen und Walflosse.
  thorwaler('Thorwalsches Kultursiegel', {
    'thorwal',
    'thorwaler',
    'thorwalerin',
  }),

  /// Reisewagen, Rad und Gepäck.
  norbarden('Norbardisches Kultursiegel', {
    'norbarde',
    'norbarden',
    'norbardin',
    'norbardensippe',
  }),

  /// Pferd, Dünen und Sonne.
  novadis('Novadisches Kultursiegel', {
    'novadi',
    'novadis',
    'novadin',
    'khom',
    'khomnomaden',
  }),

  /// Heraldischer Löwe und Stadttor.
  mittelreicher('Mittelreichisches Kultursiegel', {
    'mittelreich',
    'mittelreicher',
    'mittelreicherin',
    'mittellaendisch',
    'mittellaendische',
  }),

  /// Rapier, Feder und Lorbeer.
  horasier('Horasisches Kultursiegel', {
    'horasreich',
    'horasier',
    'horasierin',
    'horasisch',
    'horasische',
  }),

  /// Palastbogen, Öllampe und Palmzweig.
  tulamiden('Tulamidisches Kultursiegel', {
    'tulamiden',
    'tulamide',
    'tulamidin',
    'tulamidisch',
    'tulamidische',
    'mhanadistan',
    'mhanadistani',
  }),

  /// Laufender Wolf vor verschneiten Nadelbäumen.
  nivesen('Nivesisches Kultursiegel', {
    'nivesen',
    'nivese',
    'nivesin',
    'nivesisch',
    'nivesische',
    'nivesenstaemme',
  }),

  /// Bär, Tannenzweig und befestigtes Tor.
  bornlaender('Bornländisches Kultursiegel', {
    'bornland',
    'bornlaender',
    'bornlaenderin',
    'bornlaendisch',
    'bornlaendische',
  }),

  /// Geschwungene Klinge und tropische Farnwedel.
  maraskaner('Maraskanisches Kultursiegel', {
    'maraskan',
    'maraskaner',
    'maraskanerin',
    'maraskanisch',
    'maraskanische',
  }),

  /// Rabe mit ausgebreiteten Schwingen und goldenem Palmzweig.
  alanfaner('Al’Anfanisches Kultursiegel', {
    'alanfa',
    'anfa',
    'alanfaner',
    'anfaner',
    'alanfanerin',
    'anfanerin',
    'alanfanisch',
    'anfanisch',
  }),

  /// Eichenblatt, Eicheln und Holzaxt.
  andergaster('Andergastisches Kultursiegel', {
    'andergast',
    'andergaster',
    'andergasterin',
    'andergastisch',
    'andergastische',
  }),

  /// Silberner Fisch über Wellen.
  nostrier('Nostrisches Kultursiegel', {
    'nostria',
    'nostrier',
    'nostrierin',
    'nostrisch',
    'nostrische',
  });

  const KartoSiegelKultur(this.beschreibung, this.aliase);

  /// Benutzerlesbare Bezeichnung des rein kosmetischen Motivs.
  final String beschreibung;

  /// Explizite, normalisierte Schreibweisen ohne unsichere Teilwortsuche.
  final Set<String> aliase;
}

// Mehrdeutige Angaben erhalten kein willkürlich ausgewähltes Kulturbild.
KartoSiegelKultur? _kulturFuer(String angabe) {
  var normal = angabe.toLowerCase();
  for (final ersatz in const {
    'ä': 'ae',
    'ö': 'oe',
    'ü': 'ue',
    'ô': 'o',
  }.entries) {
    normal = normal.replaceAll(ersatz.key, ersatz.value);
  }
  final woerter = normal.split(RegExp('[^a-z]+')).toSet();
  final treffer = <KartoSiegelKultur>{};
  for (final kultur in KartoSiegelKultur.values) {
    if (kultur.aliase.any(woerter.contains)) treffer.add(kultur);
  }
  return treffer.length == 1 ? treffer.single : null;
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
