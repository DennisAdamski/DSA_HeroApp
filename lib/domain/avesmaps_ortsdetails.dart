import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';

/// Ein Gebiet aus den Ortsdetails von Avesmaps (Reich, Mark, Baronie …).
class AvesmapsGebiet {
  /// Erstellt ein Gebiet.
  const AvesmapsGebiet({required this.id, required this.name, this.art = ''});

  /// Kennung des Gebiets bei Avesmaps.
  final String id;

  /// Name, etwa „Kaisermark Gareth“.
  final String name;

  /// Art als Rohwert der Schnittstelle, etwa „Kaisermark“; leer ohne Angabe.
  final String art;

  /// Liest ein Gebiet; ohne Kennung oder Name `null`.
  static AvesmapsGebiet? ausJson(Object? roh) {
    if (roh is! Map) return null;
    final id = roh['id'];
    final name = roh['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final art = roh['art'];
    return AvesmapsGebiet(
      id: id,
      name: name.trim(),
      art: art is String ? art.trim() : '',
    );
  }
}

/// Die Details eines Orts von Avesmaps (`GET /api/v1/orte/{id}`).
///
/// Wie das Ortsverzeichnis nur im Speicher der Sitzung, nie im
/// Heldendokument. Unbekannte Felder werden übergangen.
class AvesmapsOrtsdetails {
  /// Erstellt die Details.
  const AvesmapsOrtsdetails({
    required this.ort,
    this.wikiUrl = '',
    this.wikiTitel = '',
    this.gebiete = const <List<AvesmapsGebiet>>[],
  });

  /// Der Ort selbst (Kennung, Name, Klasse, Position).
  final AvesmapsOrt ort;

  /// Adresse des Artikels in der Wiki Aventurica; leer ohne Artikel.
  final String wikiUrl;

  /// Titel des Wiki-Artikels; leer ohne Angabe.
  final String wikiTitel;

  /// Gebietsketten vom Reich bis zur Baronie, je Kette außen nach innen.
  ///
  /// Mehrere Ketten gibt es bei umstrittenen oder geteilten Orten.
  final List<List<AvesmapsGebiet>> gebiete;

  /// Liest die Details; ohne lesbaren Ort `null`.
  static AvesmapsOrtsdetails? ausJson(Object? roh) {
    final ort = AvesmapsOrt.ausJson(roh);
    if (ort == null || roh is! Map) return null;
    final wiki = roh['wiki'];
    final url = wiki is Map ? wiki['url'] : null;
    final titel = wiki is Map ? wiki['titel'] : null;
    final ketten = <List<AvesmapsGebiet>>[];
    final gebiete = roh['gebiete'];
    if (gebiete is List) {
      for (final kette in gebiete) {
        if (kette is! List) continue;
        final gelesen = <AvesmapsGebiet>[
          for (final gebiet in kette) ?AvesmapsGebiet.ausJson(gebiet),
        ];
        if (gelesen.isNotEmpty) {
          ketten.add(List<AvesmapsGebiet>.unmodifiable(gelesen));
        }
      }
    }
    return AvesmapsOrtsdetails(
      ort: ort,
      wikiUrl: url is String ? url.trim() : '',
      wikiTitel: titel is String ? titel.trim() : '',
      gebiete: List<List<AvesmapsGebiet>>.unmodifiable(ketten),
    );
  }
}
