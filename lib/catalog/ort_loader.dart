import 'package:dsa_heldenverwaltung/catalog/json_asset.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';

/// Asset des Ortsverzeichnisses (Siedlungen, Regionen, Staaten, Flüsse,
/// Straßen).
///
/// Erzeugt von `tool/import_wiki_orte.py` aus der Wiki Aventurica
/// (CC BY-SA, Lizenzeintrag in der App unter „Lizenzen“). Aufgenommen sind nur
/// Kurzfakten (Name, Art, Unterart, Region), keine Beschreibungstexte aus
/// Regelwerken; deshalb ist nichts verschlüsselt.
const String ortAssetPfad = 'assets/catalogs/house_rules_v1/orte.json';

/// Geladenes Ortsverzeichnis samt Diagnose.
class OrtKatalog {
  /// Erstellt den Katalog.
  const OrtKatalog({
    this.orte = const <OrtEintrag>[],
    this.stand = '',
    this.verworfen = const <String>[],
  });

  /// Lesbare Orte, nach Name sortiert (Dateireihenfolge).
  final List<OrtEintrag> orte;

  /// Abrufdatum des Imports (`JJJJ-MM-TT`); leer ohne Angabe.
  final String stand;

  /// Einträge, die nicht gelesen werden konnten, mit Grund.
  final List<String> verworfen;
}

/// Liest die Rohdaten des Assets: ein Objekt mit der Liste `orte` und
/// optional `stand`.
///
/// Je Eintrag: `name`, `art` (Schlüssel von [OrtArt]), optional `unterart`,
/// `region`, `seite`. Ein unvollständiger Eintrag landet in
/// [OrtKatalog.verworfen] statt still falsch angezeigt zu werden.
OrtKatalog parseOrte(Object? roh) {
  if (roh is! Map || roh['orte'] is! List) return const OrtKatalog();
  final liste = roh['orte'] as List<dynamic>;
  final orte = <OrtEintrag>[];
  final verworfen = <String>[];
  String text(Object? wert) => wert is String ? wert.trim() : '';
  for (var i = 0; i < liste.length; i++) {
    final eintrag = liste[i];
    if (eintrag is! Map) {
      verworfen.add('#$i: kein Objekt');
      continue;
    }
    final name = text(eintrag['name']);
    final art = OrtArt.ausSchluessel(eintrag['art']);
    if (name.isEmpty || art == null) {
      verworfen.add('#$i: Name oder Art fehlt');
      continue;
    }
    orte.add(
      OrtEintrag(
        name: name,
        art: art,
        unterart: text(eintrag['unterart']),
        region: text(eintrag['region']),
        seite: text(eintrag['seite']),
      ),
    );
  }
  return OrtKatalog(
    orte: List<OrtEintrag>.unmodifiable(orte),
    stand: text(roh['stand']),
    verworfen: List<String>.unmodifiable(verworfen),
  );
}

/// Lädt das Ortsverzeichnis aus dem Asset; [lader] ersetzt in Tests
/// `rootBundle`.
///
/// Fehlt das Asset oder ist es ungültig, ist der Katalog leer: Das
/// Verzeichnis ist eine Auswahlhilfe, der Ort bleibt frei eintragbar.
Future<OrtKatalog> ladeOrte({
  Future<String> Function(String pfad)? lader,
}) async {
  try {
    return parseOrte(await ladeJsonAsset(ortAssetPfad, lader: lader));
  } on Object {
    return const OrtKatalog();
  }
}
