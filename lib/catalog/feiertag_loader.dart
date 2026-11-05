import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:dsa_heldenverwaltung/domain/aventurischer_feiertag.dart';

/// Asset der datumsfesten Feiertage (Top-Level-Liste).
///
/// Grundstock ist die Liste „Fest- und Feiertage“ der Geographia Aventurica
/// (2. Auflage, S. 203 f.); eine umfassendere Liste führt die Wiki Aventurica
/// (`feiertagWikiListeUrl`). Eingetragen sind nur Kurzfakten (Name, Datum,
/// Art, Gottheit, Verbreitung), keine Beschreibungstexte aus Regelwerken;
/// deshalb ist nichts verschlüsselt.
///
/// Nicht aufgenommen sind Feste mit Wochentag- oder Mondbezug (etwa das
/// Turnier ab dem 1. Praiostag im Praios) und die monatsfüllenden
/// Theaterfestspiele im Rondra: Der Kalender kennt keine Wochentage, und ein
/// Eintrag über den ganzen Monat würde jede Auswahl in der Nähe dominieren.
/// Weitere Einträge gehören einfach in diese Datei.
const String feiertageAssetPfad =
    'assets/catalogs/house_rules_v1/feiertage.json';

/// Geladene Feiertage samt Diagnose.
class FeiertagKatalog {
  /// Erstellt den Katalog.
  const FeiertagKatalog({
    this.feiertage = const <AventurischerFeiertag>[],
    this.verworfen = const <String>[],
  });

  /// Lesbare Feiertage in Dateireihenfolge.
  final List<AventurischerFeiertag> feiertage;

  /// Einträge, die nicht gelesen werden konnten, mit Grund.
  final List<String> verworfen;
}

/// Liest die Rohliste des Assets.
///
/// Felder je Eintrag: `name`, `tag`, `monat` (Schlüssel wie `praios`), optional
/// `bis_tag`, `bis_monat`, `art` (Name von [FeiertagArt]), `gottheit`,
/// `verbreitung`. Ein unvollständiger oder ungültiger Eintrag landet in
/// [FeiertagKatalog.verworfen] statt still falsch angezeigt zu werden.
FeiertagKatalog parseFeiertage(List<dynamic> roh) {
  final feiertage = <AventurischerFeiertag>[];
  final verworfen = <String>[];
  for (var i = 0; i < roh.length; i++) {
    final eintrag = roh[i];
    if (eintrag is! Map) {
      verworfen.add('#$i: kein Objekt');
      continue;
    }
    final name = eintrag['name'];
    final tag = eintrag['tag'];
    final monat = eintrag['monat'];
    final art = FeiertagArt.values.asNameMap()[eintrag['art']];
    if (name is! String || name.trim().isEmpty || tag is! int) {
      verworfen.add('#$i: Name oder Tag fehlt');
      continue;
    }
    if (monat is! String || art == null) {
      verworfen.add('$name: Monat oder Art fehlt');
      continue;
    }
    try {
      feiertage.add(
        AventurischerFeiertag.am(
          name: name.trim(),
          tag: tag,
          monat: monat,
          bisTag: eintrag['bis_tag'] is int ? eintrag['bis_tag'] as int : null,
          bisMonat: eintrag['bis_monat'] is String
              ? eintrag['bis_monat'] as String
              : null,
          art: art,
          gottheit: eintrag['gottheit'] is String
              ? eintrag['gottheit'] as String
              : null,
          verbreitung: eintrag['verbreitung'] is String
              ? eintrag['verbreitung'] as String
              : '',
        ),
      );
    } on ArgumentError catch (fehler) {
      verworfen.add('$name: ${fehler.message}');
    }
  }
  return FeiertagKatalog(
    feiertage: List<AventurischerFeiertag>.unmodifiable(feiertage),
    verworfen: List<String>.unmodifiable(verworfen),
  );
}

/// Lädt die Feiertage aus dem Asset; [lader] ersetzt in Tests `rootBundle`.
///
/// Fehlt das Asset oder ist es kein JSON-Array, ist der Katalog leer: die
/// Feiertage sind eine Zusatzangabe und dürfen nichts blockieren.
Future<FeiertagKatalog> ladeFeiertage({
  Future<String> Function(String pfad)? lader,
}) async {
  final laden = lader ?? rootBundle.loadString;
  try {
    final decoded = jsonDecode(await laden(feiertageAssetPfad));
    return decoded is List ? parseFeiertage(decoded) : const FeiertagKatalog();
  } on Object {
    return const FeiertagKatalog();
  }
}
