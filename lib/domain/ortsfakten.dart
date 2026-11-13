/// Kurzfakten einer Siedlung aus der Infobox der Wiki Aventurica.
///
/// Katalogdaten (CC BY-SA), nie im Heldendokument. Leere Felder heißen: im
/// Wiki nicht angegeben.
class SiedlungsFakten {
  /// Erstellt die Fakten.
  const SiedlungsFakten({
    this.einwohner,
    this.einwohnerText = '',
    this.oberhaupt = '',
    this.herrschaftsform = '',
    this.verkehrswege = const <String>[],
  });

  /// Hauptzahl der Einwohner, oder `null`.
  final int? einwohner;

  /// Einwohnerangabe wie im Wiki, etwa „170000 (sowie 1000 Zwerge …; 1040
  /// BF)“; leer ohne Angabe.
  final String einwohnerText;

  /// Oberhaupt der Siedlung; leer ohne Angabe.
  final String oberhaupt;

  /// Herrschaftsform; leer ohne Angabe.
  final String herrschaftsform;

  /// Straßen, Flüsse und Seewege, an denen die Siedlung liegt.
  final List<String> verkehrswege;

  /// Ob es keine einzige Angabe gibt.
  bool get istLeer =>
      einwohner == null &&
      einwohnerText.isEmpty &&
      oberhaupt.isEmpty &&
      herrschaftsform.isEmpty &&
      verkehrswege.isEmpty;
}

/// Ein Bauwerk einer Siedlung aus der Wiki Aventurica (Tempel, Burg,
/// Akademie …).
class OrtsBauwerk {
  /// Erstellt das Bauwerk.
  const OrtsBauwerk({
    required this.name,
    required this.ort,
    this.art = '',
    this.seite = '',
    this.zugehoerigkeit = '',
  });

  /// Anzeigename (ohne Klammerzusatz des Wikis).
  final String name;

  /// Wiki-Seitenname der Siedlung, in der es steht.
  final String ort;

  /// Art laut Wiki, etwa „Tempel“, „Burg“ oder „Magierakademie“; leer ohne
  /// Angabe.
  final String art;

  /// Voller Wiki-Seitenname, wenn er vom [name] abweicht; sonst leer.
  final String seite;

  /// Zugehörigkeit, etwa „Boron-Kirche: Puniner Ritus“; leer ohne Angabe.
  final String zugehoerigkeit;

  /// Wiki-Seitenname des Bauwerks.
  String get wikiSeite => seite.isNotEmpty ? seite : name;
}

/// Fakten und Bauwerke aller Siedlungen, nach Wiki-Seitenname der Siedlung.
class OrtsfaktenKatalog {
  /// Erstellt den Katalog.
  const OrtsfaktenKatalog({
    this.siedlungen = const <String, SiedlungsFakten>{},
    this.bauwerke = const <String, List<OrtsBauwerk>>{},
    this.stand = '',
  });

  /// Fakten je Siedlung.
  final Map<String, SiedlungsFakten> siedlungen;

  /// Bauwerke je Siedlung, nach Name.
  final Map<String, List<OrtsBauwerk>> bauwerke;

  /// Abrufdatum des Imports (`JJJJ-MM-TT`); leer ohne Angabe.
  final String stand;
}
