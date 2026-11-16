/// Landschaftsarten der Kräutertabellen (Wege des Entdeckers S. 114–118).
///
/// Die Schlüssel (`name`) stehen im Katalog `kraeuter.json`.
enum Kraeuterlandschaft {
  /// Dichter Wald.
  dichterWald('Dichter Wald'),

  /// Lichter Wald.
  lichterWald('Lichter Wald'),

  /// Dschungel und Regenwald.
  dschungel('Dschungel'),

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

  /// Südliche Savannen und Steppen.
  savanneSteppe('Südliche Savannen und Steppen'),

  /// Gebirge.
  gebirge('Gebirge'),

  /// Hochgebirge.
  hochgebirge('Hochgebirge'),

  /// Wüste.
  wueste('Wüste');

  const Kraeuterlandschaft(this.bezeichnung);

  /// Anzeigename.
  final String bezeichnung;

  /// Landschaft zum Schlüssel aus dem Katalog, sonst `null`.
  static Kraeuterlandschaft? ausSchluessel(Object? schluessel) =>
      Kraeuterlandschaft.values.asNameMap()[schluessel];
}

/// Häufigkeit eines Krauts in einer Landschaft.
///
/// [aufschlag] ist der Anteil an der Suchschwierigkeit (Wege des Entdeckers
/// S. 113: sehr häufig +1, häufig +2, gelegentlich +4, selten +8, sehr selten
/// +16).
enum Kraeuterhaeufigkeit {
  /// Sehr häufig.
  sehrHaeufig('sehr häufig', 1),

  /// Häufig.
  haeufig('häufig', 2),

  /// Gelegentlich.
  gelegentlich('gelegentlich', 4),

  /// Selten.
  selten('selten', 8),

  /// Sehr selten.
  sehrSelten('sehr selten', 16);

  const Kraeuterhaeufigkeit(this.bezeichnung, this.aufschlag);

  /// Anzeigename.
  final String bezeichnung;

  /// Aufschlag auf die Suchschwierigkeit.
  final int aufschlag;

  /// Häufigkeit zum Schlüssel aus dem Katalog, sonst `null`.
  static Kraeuterhaeufigkeit? ausSchluessel(Object? schluessel) =>
      Kraeuterhaeufigkeit.values.asNameMap()[schluessel];
}

/// Jahreszeit für die Kräutersuche.
enum Jahreszeit {
  /// Frühling.
  fruehling('Frühling'),

  /// Sommer.
  sommer('Sommer'),

  /// Herbst.
  herbst('Herbst'),

  /// Winter.
  winter('Winter');

  const Jahreszeit(this.bezeichnung);

  /// Anzeigename.
  final String bezeichnung;
}

/// Vorkommen eines Krauts in einer Landschaft.
class KrautVorkommen {
  /// Erstellt ein Vorkommen.
  const KrautVorkommen({
    required this.landschaft,
    required this.haeufigkeit,
    this.hinweis = '',
  });

  /// Landschaft des Vorkommens.
  final Kraeuterlandschaft landschaft;

  /// Häufigkeit in dieser Landschaft.
  final Kraeuterhaeufigkeit haeufigkeit;

  /// Einschränkung, die nur für diese Landschaft gilt (z. B. „nur an
  /// Seeufern“); leer ohne Angabe.
  final String hinweis;
}

/// Ein Kraut aus den Landschaftstabellen von Wege des Entdeckers.
///
/// Der Katalog enthält Kurzfakten (Bestimmung, Häufigkeit je Landschaft,
/// einzeilige Wirkung) und eine kurze, v3-verschlüsselte [beschreibung] in
/// eigenen Worten samt Fundstelle ([quelle]). Dasselbe Kraut kann in einer
/// Landschaft mehrfach vorkommen (etwa Donf an Seeufern „selten“, an Flussufern
/// „sehr selten“).
class KrautEintrag {
  /// Erstellt einen Eintrag.
  const KrautEintrag({
    required this.name,
    required this.bestimmung,
    required this.vorkommen,
    this.wirkung = '',
    this.gebiet = '',
    this.bestimmungHinweis = '',
    this.erntezeit = '',
    this.erntemonate = const <String>[],
    this.grundmenge = '',
    this.beschreibung = '',
    this.beschreibungGesperrt = false,
    this.quelle = '',
  });

  /// Name des Krauts.
  final String name;

  /// Bestimmungswert (Zuschlag der Pflanzenkunde-Probe); kann negativ sein.
  final int bestimmung;

  /// Vorkommen je Landschaft.
  final List<KrautVorkommen> vorkommen;

  /// Einzeilige Wirkung, z. B. „fiebersenkend“.
  final String wirkung;

  /// Räumliche Einschränkung als Freitext (z. B. „nördlich des Yaquir“);
  /// wird nicht maschinell ausgewertet.
  final String gebiet;

  /// Abweichende Bestimmungswerte nach Jahreszeit oder Pflanzenteil, als
  /// Freitext (z. B. „zur Blütezeit +3“).
  final String bestimmungHinweis;

  /// Erntezeit als Text laut Zoo Botanica (z. B. „Hesinde bis Praios“).
  final String erntezeit;

  /// Monatsschlüssel (`praios` … `rahja`, `namenlose_tage`), in denen nutzbare
  /// Pflanzenteile zu ernten sind; leer bedeutet ganzjährig bzw. unbekannt.
  /// Bei zusammengesetzten Angaben (mehrere Pflanzenteile oder Gebiete) steht
  /// die Vereinigung, [erntezeit] nennt die Einzelheiten.
  final List<String> erntemonate;

  /// Grundmenge nutzbarer Pflanzenteile je Fund (z. B. „2W6 Blätter“); die
  /// Würfelangabe ist Freitext und wird nicht ausgewertet.
  final String grundmenge;

  /// Kurzbeschreibung (Aussehen, Verwendung) in eigenen Worten; leer, wenn
  /// keine vorliegt oder sie gesperrt ist. Nur zur Anzeige, nie für Regeln.
  final String beschreibung;

  /// Ob eine Beschreibung vorliegt, aber ohne Katalogpasswort nicht
  /// entschlüsselt werden konnte.
  final bool beschreibungGesperrt;

  /// Fundstelle für weitere Angaben, z. B. „Zoo Botanica Aventurica S. 250“;
  /// leer ohne Angabe.
  final String quelle;
}

/// Geladene Kräutertabellen samt Diagnose.
class KraeuterKatalog {
  /// Erstellt den Katalog.
  const KraeuterKatalog({
    this.kraeuter = const <KrautEintrag>[],
    this.stand = '',
    this.verworfen = const <String>[],
  });

  /// Lesbare Kräuter in Dateireihenfolge (nach Name sortiert).
  final List<KrautEintrag> kraeuter;

  /// Stand des Imports (`JJJJ-MM-TT`); leer ohne Angabe.
  final String stand;

  /// Einträge, die nicht gelesen werden konnten, mit Grund.
  final List<String> verworfen;
}
