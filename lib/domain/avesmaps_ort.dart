/// Ein Ort aus dem Ortsverzeichnis von Avesmaps (Entwickler-API v1).
///
/// Die Kartenposition liegt im Koordinatensystem von Avesmaps: 0 … 1024,
/// Ursprung Südwest, [y] wächst nach Norden; eine Einheit sind drei Meilen.
/// Das Verzeichnis liegt nur im lokalen Zwischenspeicher, nie im
/// Heldendokument; ein Held übernimmt bei der Auswahl [id] und Position.
class AvesmapsOrt {
  /// Erstellt einen Ort.
  const AvesmapsOrt({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.art = '',
  });

  /// Dauerhafte Kennung (UUID) des Orts bei Avesmaps.
  final String id;

  /// Name, bei gleichnamigen Orten mit Klammerzusatz („Auweiler
  /// (Darpatien)“).
  final String name;

  /// Ortsklasse als Rohwert der Schnittstelle (`metropole`, `stadt`, `dorf`
  /// …). Neue Werte können dazukommen und bleiben erhalten.
  final String art;

  /// Kartenposition Ost-West.
  final double x;

  /// Kartenposition Süd-Nord.
  final double y;

  static const Map<String, String> _artBezeichnungen = <String, String>{
    'metropole': 'Metropole',
    'grossstadt': 'Großstadt',
    'stadt': 'Stadt',
    'kleinstadt': 'Kleinstadt',
    'dorf': 'Dorf',
    'gebaeude': 'Gebäude',
    'stadtviertel': 'Stadtviertel',
  };

  /// Anzeigename der Ortsklasse; eine unbekannte Klasse heißt schlicht „Ort“.
  String get artBezeichnung => _artBezeichnungen[art] ?? 'Ort';

  /// Liest einen Ort aus der Antwort der Schnittstelle oder dem
  /// Zwischenspeicher.
  ///
  /// Liefert `null`, wenn Kennung, Name oder Position fehlen: Ein Ort ohne
  /// diese Angaben lässt sich weder verknüpfen noch auf der Karte zeigen.
  /// Unbekannte Felder werden übergangen.
  static AvesmapsOrt? ausJson(Object? roh) {
    if (roh is! Map) return null;
    final id = roh['id'];
    final name = roh['name'];
    final x = roh['x'];
    final y = roh['y'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    if (x is! num || y is! num) return null;
    final art = roh['art'];
    return AvesmapsOrt(
      id: id,
      name: name.trim(),
      art: art is String ? art : '',
      x: x.toDouble(),
      y: y.toDouble(),
    );
  }

  /// Schreibt den Ort für den lokalen Zwischenspeicher.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    if (art.isNotEmpty) 'art': art,
    'x': x,
    'y': y,
  };
}

/// Liest eine Liste von Orten; unlesbare Einträge fallen weg.
List<AvesmapsOrt> leseAvesmapsOrte(Object? roh) {
  if (roh is! List) return const <AvesmapsOrt>[];
  return List<AvesmapsOrt>.unmodifiable(<AvesmapsOrt>[
    for (final eintrag in roh) ?AvesmapsOrt.ausJson(eintrag),
  ]);
}

/// Das Ortsverzeichnis von Avesmaps samt Zeitpunkt des Abrufs.
class AvesmapsOrtsliste {
  /// Erstellt die Liste.
  const AvesmapsOrtsliste({required this.orte, required this.abgerufen});

  /// Alle sichtbaren Orte, nach Namen sortiert (Reihenfolge der
  /// Schnittstelle).
  final List<AvesmapsOrt> orte;

  /// Zeitpunkt des Abrufs (UTC).
  final DateTime abgerufen;
}
