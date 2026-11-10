/// Art eines Eintrags im Ortsverzeichnis.
///
/// Die Reihenfolge ist zugleich die Rangfolge bei gleich gutem Suchtreffer:
/// Siedlungen vor Regionen, Regionen vor Staaten usw.
enum OrtArt {
  /// Stadt, Dorf, Burg, Ruine …
  siedlung('Siedlung'),

  /// Landschaft, Gebirge, Wald, Meer, Insel …
  region('Region'),

  /// Staat oder Herrschaftsgebiet.
  staat('Staat'),

  /// Fluss.
  fluss('Fluss'),

  /// Straße, Pass oder Handelsweg.
  strasse('Straße');

  const OrtArt(this.bezeichnung);

  /// Anzeigename der Art.
  final String bezeichnung;

  /// Art zum Schlüssel aus dem Katalog (`siedlung`, `region` …), sonst `null`.
  static OrtArt? ausSchluessel(Object? schluessel) =>
      OrtArt.values.asNameMap()[schluessel];
}

/// Ein Ort aus dem Ortsverzeichnis (Wiki Aventurica, CC BY-SA).
///
/// Es sind nur Kurzfakten enthalten (Name, Art, Unterart, Region), keine
/// Beschreibungstexte. Ein Held speichert weiter nur den Namen als Text; der
/// Eintrag dient der Auswahl.
class OrtEintrag {
  /// Erstellt einen Eintrag.
  OrtEintrag({
    required this.name,
    required this.art,
    this.unterart = '',
    this.region = '',
    this.seite = '',
  });

  /// Anzeige- und Speichername (ohne Klammerzusatz des Wikis, z. B. „Havena“).
  final String name;

  /// Art des Orts.
  final OrtArt art;

  /// Feinere Art, z. B. „Wald“, „Insel“ oder „Ruine“; leer ohne Angabe.
  final String unterart;

  /// Region, in der der Ort liegt, z. B. „Albernia: Muhrsape“; leer ohne
  /// Angabe.
  final String region;

  /// Voller Wiki-Seitenname, wenn er vom [name] abweicht (etwa „Havena
  /// (Siedlung)“); sonst leer.
  final String seite;

  /// Unterzeile der Auswahl: Art bzw. Unterart und Region.
  String get untertitel {
    final teile = <String>[
      unterart.isNotEmpty ? unterart : art.bezeichnung,
      if (region.isNotEmpty) region,
    ];
    return teile.join(' · ');
  }

  /// Ob Avesmaps den Ort über `?siedlung=` öffnet; nur Siedlungen.
  bool get hatKartenlink => art == OrtArt.siedlung;
}
