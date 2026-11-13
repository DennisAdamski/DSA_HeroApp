import 'package:dsa_heldenverwaltung/catalog/json_asset.dart';
import 'package:dsa_heldenverwaltung/domain/ortsfakten.dart';

/// Asset mit Kurzfakten und Bauwerken der Siedlungen.
///
/// Erzeugt von `tool/import_wiki_ortsfakten.py` aus den Infoboxen der Wiki
/// Aventurica (CC BY-SA). Nur Kurzfakten (Einwohner, Oberhaupt,
/// Herrschaftsform, Verkehrswege; Bauwerke mit Art und Zugehörigkeit), keine
/// Beschreibungstexte; deshalb ist nichts verschlüsselt.
const String ortsfaktenAssetPfad =
    'assets/catalogs/house_rules_v1/ortsfakten.json';

/// Liest die Rohdaten: `siedlungen` (Seitenname → Fakten) und `bauwerke`
/// (Liste mit `name`, `ort`, optional `art`, `seite`, `zugehoerigkeit`).
///
/// Unlesbares wird übergangen; die Fakten sind eine Zugabe zur Ortsansicht.
OrtsfaktenKatalog parseOrtsfakten(Object? roh) {
  if (roh is! Map) return const OrtsfaktenKatalog();
  String text(Object? wert) => wert is String ? wert.trim() : '';

  final siedlungen = <String, SiedlungsFakten>{};
  final rohSiedlungen = roh['siedlungen'];
  if (rohSiedlungen is Map) {
    for (final MapEntry(:key, :value) in rohSiedlungen.entries) {
      if (key is! String || key.trim().isEmpty || value is! Map) continue;
      final einwohner = value['einwohner'];
      final wege = value['verkehrswege'];
      final fakten = SiedlungsFakten(
        einwohner: einwohner is int && einwohner >= 0 ? einwohner : null,
        einwohnerText: text(value['einwohnerText']),
        oberhaupt: text(value['oberhaupt']),
        herrschaftsform: text(value['herrschaftsform']),
        verkehrswege: wege is List
            ? List<String>.unmodifiable(<String>[
                for (final w in wege)
                  if (w is String && w.trim().isNotEmpty) w.trim(),
              ])
            : const <String>[],
      );
      if (!fakten.istLeer) siedlungen[key.trim()] = fakten;
    }
  }

  final bauwerke = <String, List<OrtsBauwerk>>{};
  final rohBauwerke = roh['bauwerke'];
  if (rohBauwerke is List) {
    for (final eintrag in rohBauwerke) {
      if (eintrag is! Map) continue;
      final name = text(eintrag['name']);
      final ort = text(eintrag['ort']);
      if (name.isEmpty || ort.isEmpty) continue;
      (bauwerke[ort] ??= <OrtsBauwerk>[]).add(
        OrtsBauwerk(
          name: name,
          ort: ort,
          art: text(eintrag['art']),
          seite: text(eintrag['seite']),
          zugehoerigkeit: text(eintrag['zugehoerigkeit']),
        ),
      );
    }
  }

  return OrtsfaktenKatalog(
    siedlungen: Map<String, SiedlungsFakten>.unmodifiable(siedlungen),
    bauwerke: Map<String, List<OrtsBauwerk>>.unmodifiable(
      <String, List<OrtsBauwerk>>{
        for (final MapEntry(:key, :value) in bauwerke.entries)
          key: List<OrtsBauwerk>.unmodifiable(value),
      },
    ),
    stand: text(roh['stand']),
  );
}

/// Lädt die Ortsfakten aus dem Asset; [lader] ersetzt in Tests
/// `rootBundle`. Fehlt das Asset oder ist es ungültig, ist der Katalog leer.
Future<OrtsfaktenKatalog> ladeOrtsfakten({
  Future<String> Function(String pfad)? lader,
}) async {
  try {
    return parseOrtsfakten(
      await ladeJsonAsset(ortsfaktenAssetPfad, lader: lader),
    );
  } on Object {
    return const OrtsfaktenKatalog();
  }
}
