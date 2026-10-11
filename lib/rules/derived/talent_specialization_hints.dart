/// Empfohlene Spezialisierungen je Talent.
///
/// Die Listen stammen aus den Talentbeschreibungen von „Wege des Schwerts“
/// (Zeile „Spezialisierungen“, per dsa-rules-MCP geprüft). Sie sind
/// Empfehlungen zur Auswahl, keine Sperre: Das Regelwerk erlaubt ausdrücklich
/// weitere Spezialisierungen in Absprache mit dem Meister, und Talente mit
/// „nach Kultur“, „nach Region“ o. Ä. lassen sich nicht abschließend auflisten.
/// Kampftalente sind nicht enthalten, sie wählen weiterhin aus ihren
/// Waffenkategorien.
class TalentSpezialisierungsHinweis {
  /// Fasst Empfehlungen, freie Wahlmöglichkeiten und Zusatzhinweise zusammen.
  const TalentSpezialisierungsHinweis({
    this.vorschlaege = const [],
    this.freieWahl,
    this.weitereOptionen = const [],
    this.anmerkung,
    this.keine = false,
  });

  /// Im Regelwerk ausdrücklich genannte Spezialisierungen.
  final List<String> vorschlaege;

  /// Beschreibt, was sich zusätzlich frei benennen lässt („nach Kultur“).
  final String? freieWahl;

  /// Vorschläge für die Eingabe, die nicht als Empfehlung hervorgehoben werden.
  final List<String> weitereOptionen;

  /// Voraussetzungen oder Auslegung aus der Talentbeschreibung.
  final String? anmerkung;

  /// Das Regelwerk sieht für dieses Talent keine Spezialisierung vor.
  final bool keine;

  /// Gibt es überhaupt konkrete Namen zum Anklicken?
  bool get hatVorschlaege => vorschlaege.isNotEmpty;
}

/// Quellenangabe für die Anzeige.
const String kSpezialisierungsQuelle =
    'Wege des Schwerts, Talentbeschreibungen';

/// Die wählbaren Kulturen aus der Sonderfertigkeit Kulturkunde (WdS).
const List<String> kSpezialisierungsKulturen = [
  'Mittelreich',
  'Almada',
  'Andergast und Nostria',
  'Bornland',
  'Svellttal',
  'Nordlande',
  'Horasreich',
  'Zyklopeninseln',
  'Amazonen',
  'Aranien',
  'Tulamidenlande',
  'Novadi',
  'Ferkina',
  'Zahori',
  'Thorwal',
  'Gjalskerländer',
  'Fjarninger',
  'Waldmenschen',
  'Tocamuyac',
  'Maraskan',
  'Südaventurien',
  'Bukanier',
  'Nivesen',
  'Norbarden',
  'Trollzacker',
  'Schwarze Lande',
  'Ambosszwerge',
  'Brillantzwerge',
  'Erzzwerge',
  'Hügelzwerge',
  'Brobim',
  'Auelfen',
  'Waldelfen',
  'Firnelfen',
  'Steppenelfen',
  'Orks',
  'Goblins',
  'Archaische Achaz',
  'Stammes-Achaz',
  'Trolle',
  'Grolme',
];

const _nachKultur = TalentSpezialisierungsHinweis(
  freieWahl: 'nach Kultur',
  weitereOptionen: kSpezialisierungsKulturen,
);

const _keine = TalentSpezialisierungsHinweis(keine: true);

// Schlüssel sind normalisierte Talentnamen (siehe [_schluessel]).
const Map<String, TalentSpezialisierungsHinweis> _hinweise = {
  // Körperliche Talente
  'akrobatik': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Balancieren',
      'Bodenakrobatik',
      'Schwingen',
      'Sprünge',
      'Winden',
    ],
  ),
  'athletik': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Hochsprung',
      'Kraftakte',
      'Langlauf',
      'Sprint',
      'Weitsprung',
    ],
  ),
  'klettern': TalentSpezialisierungsHinweis(
    vorschlaege: ['Bergsteigen', 'Eisklettern', 'Freiklettern', 'Seilklettern'],
  ),
  'fliegen': TalentSpezialisierungsHinweis(
    vorschlaege: ['Hexenbesen', 'Fliegender Teppich'],
    freieWahl: 'weitere magische Fluggeräte',
    anmerkung: 'Je Spezialisierung nur ein einzelnes Gerät.',
  ),
  'gaukeleien': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Bauchreden',
      'Feuerkunst',
      'Jonglieren',
      'Possenreißen',
      'Taschenspielereien',
    ],
  ),
  'körperbeherrschung': TalentSpezialisierungsHinweis(
    vorschlaege: ['Fallen', 'Sprünge', 'Standfestigkeit'],
  ),
  'reiten': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Pferd/Esel/Muli',
      'Kamel',
      'Strauß',
      'Reitechse',
      'Flugechse',
      'Hippogriff',
      'Goblinisches Reit-Wildschwein',
    ],
    freieWahl: 'nach Tierart',
  ),
  'schleichen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Eis/Schnee',
      'Gebäude',
      'Geröll',
      'Straßen',
      'Wald/Dschungel',
    ],
    anmerkung: 'Spezialisierung nach Gelände.',
  ),
  'schwimmen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Langstreckenschwimmen',
      'Schnellschwimmen',
      'Tauchen',
      'Unterwasserkampf',
    ],
  ),
  'selbstbeherrschung': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Erschöpfung Ignorieren',
      'Schmerz Unterdrücken',
      'Störungen Ignorieren',
      'Wunden Ignorieren',
    ],
    anmerkung:
        'Je ignoriertem Punkt Probenmodifikation ist die Probe um 5 Punkte '
        'erschwert; die Wirkung hält 5 KR an.',
  ),
  'sichverstecken': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Gebäude',
      'Gebirge',
      'Grasland',
      'Eis/Schnee',
      'Stadt',
      'Wald/Dschungel',
      'Wüste',
    ],
  ),
  'singen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Balladenvortrag',
      'Chorgesang',
      'Mehrstimmigkeit',
      'Operngesang',
    ],
  ),
  'sinnesschärfe': TalentSpezialisierungsHinweis(
    vorschlaege: ['Hören', 'Riechen/Schmecken', 'Sehen', 'Tasten'],
  ),
  'sinnenschärfe': TalentSpezialisierungsHinweis(
    vorschlaege: ['Hören', 'Riechen/Schmecken', 'Sehen', 'Tasten'],
  ),
  'tanzen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Ausdruckstänze',
      'Formationstänze',
      'Höfische Tänze',
      'Kulttänze',
      'Meditationstänze',
    ],
    anmerkung:
        'Höfische Tänze setzen Etikette 6+, Kulttänze Götter/Kulte 6+ voraus.',
  ),
  'stimmenimitieren': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Haustiere',
      'Jagdwild',
      'Menschliche Stimmen',
      'Raubtiere',
      'Vögel',
    ],
  ),
  'skifahren': _keine,
  'taschendiebstahl': _keine,
  'zechen': _keine,

  // Gesellschaftliche Talente
  'betören': _nachKultur,
  'etikette': _nachKultur,
  'menschenkenntnis': _nachKultur,
  'gassenwissen': TalentSpezialisierungsHinweis(
    vorschlaege: ['Beschatten', 'Hehlerei', 'Kontakte', 'Ortseinschätzung'],
  ),
  'lehren': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Kampftalente',
      'Körperliche Talente',
      'Gesellschaftliche Talente',
      'Natur-Talente',
      'Wissenstalente',
      'Handwerkstalente',
      'Sprachen und Schriften',
    ],
    anmerkung: 'Spezialisierung nach Talentgruppe.',
  ),
  'schauspielerei': TalentSpezialisierungsHinweis(
    vorschlaege: ['Komödie', 'Posse', 'Tragödie'],
  ),
  'schriftlicherausdruck': TalentSpezialisierungsHinweis(
    vorschlaege: ['Schreiber', 'Schriftsteller'],
  ),
  'sichverkleiden': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Anderer Stand',
      'Anderes Geschlecht',
      'Andere Rasse',
      'Fremde Kultur',
    ],
  ),
  'überreden': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Aufwiegeln',
      'Betteln',
      'Einschüchtern',
      'Feilschen',
      'Lügen',
    ],
    anmerkung: 'Aufwiegeln ist nötig, um mehr als 4 Personen gleichzeitig zu überreden.',
  ),
  'überzeugen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Öffentliche Rede',
      'Einzelgespräch',
      'Diskussions-Rhetorik',
      'Schriftliche Rhetorik',
    ],
    anmerkung:
        'Öffentliche Rede umfasst Demagogie, Plädoyer und Predigt; '
        'Einzelgespräch Verhör und Bekehrung.',
  ),

  // Natur-Talente
  'fährtensuchen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Eis/Schnee',
      'Gebirge',
      'Grasland',
      'Stadt',
      'Sumpf',
      'Unterirdisch',
      'Wald/Dschungel',
      'Wüste',
    ],
  ),
  'fallenstellen': TalentSpezialisierungsHinweis(
    vorschlaege: ['Gruben', 'Schlingen', 'Speere'],
  ),
  'fesseln/entfesseln': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Entfesseln',
      'Fesseln',
      'Knotenkunde',
      'Taue Spleißen',
      'Netze Knüpfen',
    ],
  ),
  'fischen/angeln': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Flüsse/Bäche',
      'Hochseeangeln',
      'Seen/Sumpf/Brackwasser',
      'Strand/Riff',
      'Seefischerei',
    ],
  ),
  'orientierung': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Dschungel',
      'Eis/Schnee',
      'Gebirge',
      'Grasland',
      'Meer',
      'Stadt',
      'Unterirdisch',
      'Wald',
      'Wüste',
    ],
  ),
  'wettervorhersage': TalentSpezialisierungsHinweis(
    freieWahl: 'nach Geländetyp oder Region',
  ),
  'wildnisleben': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Dschungel',
      'Eis/Schnee',
      'Gebirge',
      'Meer',
      'Steppe',
      'Sumpf',
      'Wald',
      'Wüste',
    ],
  ),

  // Wissenstalente
  'anatomie': TalentSpezialisierungsHinweis(freieWahl: 'nach Spezies'),
  'baukunst': TalentSpezialisierungsHinweis(
    vorschlaege: ['Hochbau', 'Tiefbau', 'Wehranlagen'],
    anmerkung:
        'Hochbau: Wohn- und Repräsentationsgebäude; Tiefbau: Brücken, Kanäle, '
        'Straßen.',
  ),
  'brett-/kartenspiel': TalentSpezialisierungsHinweis(freieWahl: 'nach Spiel'),
  'geographie': TalentSpezialisierungsHinweis(freieWahl: 'nach Region'),
  'geschichtswissen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Bau- und Kunstgeschichte',
      'Militärgeschichte',
      'Religionsgeschichte',
      'Wissenschaftsgeschichte',
    ],
    freieWahl: 'oder nach Kultur',
    weitereOptionen: kSpezialisierungsKulturen,
  ),
  'gesteinskunde': TalentSpezialisierungsHinweis(
    vorschlaege: ['Baugestein', 'Edelmetalle', 'Edelsteine'],
  ),
  'götter/kulte': TalentSpezialisierungsHinweis(
    freieWahl: 'je nach Glaubensausrichtung',
    anmerkung:
        'Ab TaW 7 darf die erste Spezialisierung auch eine fremde Religion '
        'betreffen.',
  ),
  'heraldik': TalentSpezialisierungsHinweis(freieWahl: 'nach Staat'),
  'hüttenkunde': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Edelmetalle',
      'Eisen/Stahl',
      'Kupfer/Bronze/Messing',
      'Zinn',
      'Magische Metalle',
    ],
    anmerkung: 'Spezialisierung nach Metall oder Erz.',
  ),
  'kriegskunst': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Logistik',
      'Militärgeschichte',
      'Monstren',
      'Seegefechte',
      'Strategie',
      'Taktik',
    ],
    anmerkung:
        'Zwerge können sich zusätzlich auf Drachen und deren '
        'Bekämpfung spezialisieren.',
  ),
  'kryptographie': _keine,
  'magiekunde': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Artefaktherstellung',
      'Dämonologie',
      'Elementarismus',
      'Magiehistorie',
      'Magietheorie',
      'Magische Analyse',
      'Sphärologie',
      'Zauberpraxis',
      'Zauberwerkstatt',
    ],
    anmerkung:
        'Magische Analyse, Zauberwerkstatt und Artefaktherstellung setzen '
        'zumindest rudimentäre magische Begabung voraus.',
  ),
  'mechanik': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Belagerungswaffen',
      'Kräne/Hebewerke/Mahlwerke',
      'Materialkunde',
      'Pumpen und Wasserkraft',
      'Windkraft',
    ],
  ),
  'pflanzenkunde': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Dschungel',
      'Gebirge',
      'Grasland',
      'Meer',
      'Steppe',
      'Sumpf',
      'Tundra',
      'Wald',
      'Wüste',
    ],
    anmerkung: 'Spezialisierung nach Gelände.',
  ),
  'philosophie': _keine,
  'rechnen': TalentSpezialisierungsHinweis(
    vorschlaege: ['Arithmetik', 'Buchführung', 'Geometrie'],
  ),
  'rechtskunde': TalentSpezialisierungsHinweis(
    vorschlaege: ['Gildenrecht', 'Kirchenrecht', 'Strafrecht', 'Staatsrecht'],
    freieWahl: 'oder nach Staat',
  ),
  'sagen/legenden': _nachKultur,
  'schätzen': TalentSpezialisierungsHinweis(
    vorschlaege: ['Antiquitäten', 'Materialwert', 'Schmuck', 'Handwerksgüter'],
  ),
  'sprachenkunde': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Garethi-Familie',
      'Tulamidya-Familie',
      'Elfisch (Isdira, Asdharia)',
      'Zwergisch (Rogolan, Angram)',
    ],
    freieWahl: 'nach Sprachfamilie',
  ),
  'staatskunst': TalentSpezialisierungsHinweis(
    vorschlaege: ['Diplomatie', 'Intrige', 'Verwaltung'],
  ),
  'sternkunde': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Himmelskartographie',
      'Horoskope',
      'Navigation',
      'Zeitbestimmung',
    ],
  ),
  'tierkunde': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Drachen',
      'Jagdwild',
      'Meeresgetier',
      'Monstren',
      'Nutztiere',
      'Raubtiere',
      'Schädlinge',
      'Vielbeiner',
      'Vögel',
    ],
    freieWahl: 'oder nach Region',
  ),

  // Handwerkstalente
  'abrichten': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Dompteur',
      'Echsenbändiger',
      'Falkner',
      'Hundeführer',
      'Zureiter',
    ],
    anmerkung:
        'Ein Pferd zum Schlachtross auszubilden verlangt die Spezialisierung '
        'Zureiter.',
  ),
  'ackerbau': TalentSpezialisierungsHinweis(
    vorschlaege: ['Zwergische Pilzzucht'],
    freieWahl: 'nach angebauter Frucht oder Klimazone',
  ),
  'alchemie': _alchimie,
  'alchimie': _alchimie,
  'bergbau': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Bergwerke',
      'Kanalisation',
      'Natürliche Höhlen',
      'Sappeur',
      'Unterirdische Städte',
    ],
  ),
  'bogenbau': TalentSpezialisierungsHinweis(
    vorschlaege: ['Armbrust', 'Bogen', 'Bolzen/Pfeile', 'Torsionswaffen'],
  ),
  'bootefahren': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Einmaster (Segeln)',
      'Floß (Staken)',
      'Kanus/Kajaks (Paddeln)',
      'Ruderboote (Rudern)',
      'Eissegler',
    ],
  ),
  'brauer': _keine,
  'drucker': TalentSpezialisierungsHinweis(
    vorschlaege: ['Buchdruck', 'Druckereitechnik', 'Pamphlete', 'Typographie'],
  ),
  'fahrzeuglenken': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Lastkarren',
      'Streitwagen',
      'Zuggespanne',
      'Hunde- und Dachsschlitten',
    ],
  ),
  'falschspiel': TalentSpezialisierungsHinweis(
    vorschlaege: ['Würfel', 'Karten'],
  ),
  'feinmechanik': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Gold- und Silberschmied',
      'Gravieren',
      'Schlösser',
      'Siegelstöcke',
      'Trickwaffen/Fallen',
      'Uhrwerke',
    ],
  ),
  'feuersteinbearbeitung': _keine,
  'fleischer': TalentSpezialisierungsHinweis(
    vorschlaege: ['Fische', 'Geflügel', 'Reptilien', 'Säugetiere'],
  ),
  'gerber/kürschner': TalentSpezialisierungsHinweis(
    vorschlaege: ['Gerber', 'Kürschner', 'Trophäen'],
  ),
  'glaskunst': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Fensterscheiben',
      'Glasbläserei',
      'Linsenschleifen',
      'Spiegel',
    ],
  ),
  'grobschmied': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Drahtzieher/Sarwirker',
      'Hufschmied',
      'Plättner',
      'Schwarzschmied',
      'Spengler',
      'Waffenschmied',
    ],
  ),
  'handel': TalentSpezialisierungsHinweis(
    vorschlaege: ['Geldwechsel', 'Korn', 'Metalle', 'Sklaven'],
    freieWahl: 'nach Region oder Warengruppe',
  ),
  'hauswirtschaft': TalentSpezialisierungsHinweis(
    vorschlaege: ['Bewirtung/Feiern', 'Personal', 'Vorratshaltung'],
  ),
  'heilkundegift': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Alchimistische/Zaubergifte',
      'Mineralische Gifte',
      'Pflanzliche Gifte',
      'Tierische Gifte',
      'Atemgifte',
      'Einnahmegifte',
      'Kontaktgifte',
      'Waffengifte',
      'Tierheilkunde',
    ],
    anmerkung: 'Spezialisierung nach Art oder nach Wirkung des Gifts.',
  ),
  'heilkundekrankheiten': TalentSpezialisierungsHinweis(
    vorschlaege: ['Tierheilkunde'],
    freieWahl: 'nach Region',
  ),
  'heilkundeseele': _keine,
  'heilkundewunden': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Brüche/Quetschungen',
      'Innere Verletzungen',
      'Schnitte',
      'Tierheilkunde',
      'Verbrennungen',
      'Zahnleiden',
    ],
  ),
  'holzbearbeitung': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Beinschnitzerei',
      'Holzkunde',
      'Holzwaffen',
      'Küfer/Wagner',
      'Möbelschreinerei/Tischlerei',
      'Schnitzen',
    ],
  ),
  'instrumentenbauer': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Blasinstrumente',
      'Saiteninstrumente',
      'Tasteninstrumente',
      'Trommeln',
    ],
  ),
  'kartographie': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Gebäude',
      'Höhlen/Tunnel',
      'Küsten/Meere',
      'Landschaften',
      'Stadt',
    ],
  ),
  'kochen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Backen/Braten',
      'Festmahle',
      'Haltbarmachen',
      'Marschversorgung',
      'Tränke',
      'Vorkoster',
    ],
  ),
  'kristallzucht': _keine,
  'lederarbeiten': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Gurte/Riemen',
      'Lederkleidung',
      'Lederrüstungen',
      'Sättel',
      'Schuhwerk',
    ],
  ),
  'malen/zeichnen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Architektur',
      'Landschaften',
      'Porträt',
      'Technische Skizze',
    ],
  ),
  'maurer': TalentSpezialisierungsHinweis(
    vorschlaege: ['Steinbau', 'Steinguss', 'Ziegelbau'],
  ),
  'metallguss': TalentSpezialisierungsHinweis(
    vorschlaege: ['Klangkörper', 'Rohre', 'Reliefplatten/Statuen'],
  ),
  'musizieren': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Blechblasinstrumente',
      'Flöten',
      'Harfen',
      'Kapellmeister/Dirigent',
      'Lauten',
      'Rhythmusinstrumente',
      'Streichinstrumente',
      'Tasteninstrumente',
    ],
  ),
  'schlösserknacken': TalentSpezialisierungsHinweis(
    vorschlaege: ['Fallen', 'Schlösser'],
  ),
  'schnapsbrennen': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Alchimistische Destillation',
      'Beeren-/Obstbrände',
      'Kornbrände',
      'Kräuterschnäpse',
      'Lagerung',
    ],
  ),
  'schneidern': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Entwurf/Festgewänder',
      'Flick-/Gebrauchsschneiderei',
      'Maßschneidern',
      'Tuchrüstungen',
    ],
  ),
  'seefahrt': TalentSpezialisierungsHinweis(
    vorschlaege: ['Ruderschiff', 'Segelschiff', 'Steuermann'],
  ),
  'seiler': _keine,
  'steinmetz': TalentSpezialisierungsHinweis(
    vorschlaege: ['Baugestein', 'Reliefs', 'Statuen'],
  ),
  'steinschneider/juwelier': _keine,
  'stellmacher': TalentSpezialisierungsHinweis(
    vorschlaege: ['Karren/Wagen', 'Schlitten', 'Streitwagen'],
  ),
  'stoffefärben': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Alchimistische Farben',
      'Mineralische Farben',
      'Pflanzliche Farben',
      'Tierische Farben',
      'Stoffdruck',
    ],
    freieWahl: 'oder nach Art des Stoffes',
  ),
  'tätowieren': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Naturalistische Darstellung',
      'Ornamente',
      'Zaubertätowierungen',
    ],
  ),
  'töpfern': TalentSpezialisierungsHinweis(
    vorschlaege: ['Gefäße', 'Statuetten', 'Ziegelei'],
  ),
  'viehzucht': TalentSpezialisierungsHinweis(
    vorschlaege: ['Rind', 'Schaf/Ziege', 'Schwein', 'Pferd', 'Hund'],
    freieWahl: 'nach Tierart',
  ),
  'webkunst': TalentSpezialisierungsHinweis(
    vorschlaege: ['Häkeln', 'Klöppeln', 'Stricken', 'Teppichknüpfen', 'Weben'],
    freieWahl: 'oder nach Material',
  ),
  'winzer': TalentSpezialisierungsHinweis(
    vorschlaege: ['Wein', 'Fruchtweine', 'Schaumweine', 'Weinkenner'],
  ),
  'zimmermann': TalentSpezialisierungsHinweis(
    vorschlaege: [
      'Dachdecker',
      'Holzkonstruktionen',
      'Schiffszimmermann',
      'Schiffbau',
    ],
    anmerkung:
        'Schiffbau erfordert Lesen/Schreiben, Malen/Zeichnen, Rechnen und '
        'Seefahrt jeweils auf TaW 4.',
  ),

  // Gaben (Wege der Helden): nur die Tierempathie kennt Spezialisierungen.
  'tierempathie': TalentSpezialisierungsHinweis(
    freieWahl: 'nach Tierart',
    anmerkung:
        'Nur bei einer Tierempathie für alle Tierarten möglich '
        '(Steigerung nach Spalte F).',
  ),
};

const _alchimie = TalentSpezialisierungsHinweis(
  vorschlaege: [
    'Brandmittel',
    'Gifte',
    'Laborpraxis',
    'Zauber-Elixiere',
    'Farben/Lacke',
    'Materialveredelung',
    'Theoretische Alchimie',
  ],
);

String _schluessel(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// Liefert die Empfehlungen für ein Talent oder `null`, wenn das Regelwerk
/// dazu nichts nennt (etwa bei den meisten Gaben).
TalentSpezialisierungsHinweis? talentSpezialisierungsHinweis(
  String talentName,
) => _hinweise[_schluessel(talentName)];
