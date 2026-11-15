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

  /// Bild für den freigegebenen ersten Satz; andere Motive behalten ihren Rückfall.
  String? get assetPfad {
    if (motiv == KartoSiegelMotiv.echse) {
      return 'assets/ui/heldensiegel_v1/achaz.png';
    }
    final kultur = this.kultur;
    return kultur == null
        ? null
        : 'assets/ui/heldensiegel_v1/${kultur.name}.png';
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
    final grund = switch (kultur) {
      KartoSiegelKultur.thorwaler => 'Thorwalsches Kultursiegel',
      KartoSiegelKultur.norbarden => 'Norbardisches Kultursiegel',
      KartoSiegelKultur.novadis => 'Novadisches Kultursiegel',
      null => grundmotiv,
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
      other.kultur == kultur &&
      other.magisch == magisch &&
      other.karmal == karmal;

  @override
  int get hashCode => Object.hash(motiv, kultur, magisch, karmal);
}

/// Zunächst als Bildasset verfügbare menschliche Kultursiegel.
enum KartoSiegelKultur {
  /// Schiff, Wellen und Walflosse.
  thorwaler,

  /// Reisewagen, Rad und Gepäck.
  norbarden,

  /// Pferd, Dünen und Sonne.
  novadis,
}

// Mehrdeutige Angaben erhalten kein willkürlich ausgewähltes Kulturbild.
KartoSiegelKultur? _kulturFuer(String angabe) {
  final normal = angabe.toLowerCase().replaceAll('ô', 'o');
  final woerter = normal.split(RegExp('[^a-z]+')).toSet();
  final treffer = <KartoSiegelKultur>{};
  for (final gruppe in const {
    KartoSiegelKultur.thorwaler: {'thorwal', 'thorwaler', 'thorwalerin'},
    KartoSiegelKultur.norbarden: {
      'norbarde',
      'norbarden',
      'norbardin',
      'norbardensippe',
    },
    KartoSiegelKultur.novadis: {
      'novadi',
      'novadis',
      'novadin',
      'khom',
      'khomnomaden',
    },
  }.entries) {
    if (gruppe.value.any(woerter.contains)) treffer.add(gruppe.key);
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
