import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Quellenangabe eines alchimistischen Mittels (TRANK).
class AlchimikumBeleg {
  /// Erstellt eine Quellenangabe.
  const AlchimikumBeleg({this.buch = '', this.seite = '', this.chunkId = 0});

  /// Regelwerk, z. B. `Wege der Alchimie (2. Auflage 2012)`.
  final String buch;

  /// Gedruckte Buchseite (nicht die PDF-Seite), z. B. `56`.
  final String seite;

  /// Chunk-ID im dsa-rules-Index zum Nachlesen; 0 = nicht angegeben.
  final int chunkId;

  /// Ob Buch und Seite benannt sind.
  bool get istBenannt => buch.trim().isNotEmpty && seite.trim().isNotEmpty;

  /// Kurzform für die Anzeige, z. B. `Wege der Alchimie (2. Auflage 2012) S. 56`.
  String get kurz => istBenannt ? '$buch S. $seite' : buch;

  /// Liest eine Quellenangabe tolerant aus dem Katalog-JSON.
  factory AlchimikumBeleg.fromJson(Map<String, dynamic> json) {
    return AlchimikumBeleg(
      buch: readCatalogString(json, 'buch', fallback: ''),
      seite: readCatalogString(json, 'seite', fallback: ''),
      chunkId: readCatalogInt(json, 'chunkId', fallback: 0),
    );
  }

  /// Schreibt die Quellenangabe ohne leere Felder zurück.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (buch.isNotEmpty) 'buch': buch,
      if (seite.isNotEmpty) 'seite': seite,
      if (chunkId != 0) 'chunkId': chunkId,
    };
  }
}

/// Eine Eigenschaftsänderung auf Zeit, die ein Elixier in einer Qualitätsstufe
/// auslöst (z. B. `MU +3` für 3 Spielrunden).
///
/// Nur ausdrücklich genannte Zahlen mit Eigenschaft und Dauer stehen hier;
/// alles andere (Nachwirkungen nach Ablauf, Gruppen wie „alle geistigen
/// Eigenschaften“, AuP-Wirkungen) bleibt Text in [AlchimikumQualitaet.wirkung].
class AlchimikumEigenschaft {
  /// Erstellt eine Eigenschaftsänderung.
  const AlchimikumEigenschaft({
    required this.eigenschaft,
    required this.wert,
    required this.dauer,
    required this.einheit,
  });

  /// Eigenschaftskürzel: `MU`, `KL`, `IN`, `CH`, `FF`, `GE`, `KO` oder `KK`.
  final String eigenschaft;

  /// Änderung der Eigenschaft; negativ bei Nebenwirkungen.
  final int wert;

  /// Dauer in [einheit]; mindestens 1.
  final int dauer;

  /// Einheit der Dauer, Name von `SpellDurationUnit` (`spielrunden`,
  /// `stunden`, `tage`).
  final String einheit;

  /// Liest eine Eigenschaftsänderung tolerant aus dem Katalog-JSON.
  factory AlchimikumEigenschaft.fromJson(Map<String, dynamic> json) {
    return AlchimikumEigenschaft(
      eigenschaft: readCatalogString(json, 'eigenschaft', fallback: ''),
      wert: readCatalogInt(json, 'wert', fallback: 0),
      dauer: readCatalogInt(json, 'dauer', fallback: 0),
      einheit: readCatalogString(json, 'einheit', fallback: ''),
    );
  }

  /// Schreibt die Eigenschaftsänderung zurück.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'eigenschaft': eigenschaft,
      'wert': wert,
      'dauer': dauer,
      'einheit': einheit,
    };
  }
}

/// Wirkung eines Mittels in einer Qualitätsstufe (`A` bis `F`).
///
/// Die Würfelausdrücke (`2W6+4`) sind nur **Vorschläge** für den Dialog
/// „Anwenden“: Gewürfelt und gebucht wird nie automatisch. `alle …` steht für
/// eine Wirkung, die sich nicht als Zahl ausdrücken lässt.
class AlchimikumQualitaet {
  /// Erstellt eine Qualitätsstufe.
  const AlchimikumQualitaet({
    required this.stufe,
    this.lepWurf = '',
    this.aspWurf = '',
    this.aupWurf = '',
    this.lepProWunde = 0,
    this.wirkung = '',
    this.eigenschaften = const <AlchimikumEigenschaft>[],
  });

  /// Stufe `A` bis `F`.
  final String stufe;

  /// Eigenschaftsänderungen auf Zeit (Elixiere); jede läuft mit eigener Dauer.
  final List<AlchimikumEigenschaft> eigenschaften;

  /// Ob die Stufe Eigenschaften auf Zeit verändert.
  bool get hatEigenschaftsWirkung => eigenschaften.isNotEmpty;

  /// Vorschlag für die zurückkehrenden LeP.
  final String lepWurf;

  /// Vorschlag für die zurückkehrenden AsP.
  final String aspWurf;

  /// Vorschlag für die zurückkehrenden AuP.
  final String aupWurf;

  /// Je so viele zurückgewonnene LeP schließt sich eine Wunde; 0 = nie.
  final int lepProWunde;

  /// Kurzbeschreibung von Wirkung und Nebenwirkung dieser Stufe.
  final String wirkung;

  /// Ob die Stufe Vitalwerte oder Wunden unmittelbar beeinflusst.
  bool get hatVitalwirkung =>
      lepWurf.isNotEmpty ||
      aspWurf.isNotEmpty ||
      aupWurf.isNotEmpty ||
      lepProWunde > 0;

  /// Liest eine Stufe tolerant aus dem Katalog-JSON.
  factory AlchimikumQualitaet.fromJson(Map<String, dynamic> json) {
    return AlchimikumQualitaet(
      stufe: readCatalogString(json, 'stufe', fallback: ''),
      lepWurf: readCatalogString(json, 'lepWurf', fallback: ''),
      aspWurf: readCatalogString(json, 'aspWurf', fallback: ''),
      aupWurf: readCatalogString(json, 'aupWurf', fallback: ''),
      lepProWunde: readCatalogInt(json, 'lepProWunde', fallback: 0),
      wirkung: readCatalogString(json, 'wirkung', fallback: ''),
      eigenschaften: readCatalogObjectList(
        json,
        'eigenschaften',
      ).map(AlchimikumEigenschaft.fromJson).toList(growable: false),
    );
  }

  /// Schreibt die Stufe ohne leere Felder zurück.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stufe': stufe,
      if (lepWurf.isNotEmpty) 'lepWurf': lepWurf,
      if (aspWurf.isNotEmpty) 'aspWurf': aspWurf,
      if (aupWurf.isNotEmpty) 'aupWurf': aupWurf,
      if (lepProWunde > 0) 'lepProWunde': lepProWunde,
      if (wirkung.isNotEmpty) 'wirkung': wirkung,
      if (eigenschaften.isNotEmpty)
        'eigenschaften': eigenschaften
            .map((e) => e.toJson())
            .toList(growable: false),
    };
  }
}

/// Alchimistisches Mittel aus den Regelbüchern (TRANK): Heiltrank,
/// Wundpulver, Antidot …
///
/// Der Katalog hält nur belegte Eckdaten mit Quelle. Die Wirkungstexte sind
/// kurze eigene Zusammenfassungen, keine Buchzitate. Brauen, Rezepturenerwerb
/// und Labor sind nicht Teil des Katalogs.
class AlchimikumDef {
  /// Erstellt ein Mittel.
  const AlchimikumDef({
    required this.id,
    required this.name,
    this.art = '',
    this.gruppe = '',
    this.beleg = const AlchimikumBeleg(),
    this.brauProbe,
    this.analyseProbe,
    this.labor = '',
    this.haltbarkeit = '',
    this.verbreitung = '',
    this.preisSilber,
    this.preisText = '',
    this.wirkung = '',
    this.qualitaeten = const <AlchimikumQualitaet>[],
  });

  /// Stabile ID, z. B. `alch_heiltrank`.
  final String id;

  /// Anzeigename.
  final String name;

  /// Darreichung: `trank`, `pastille`, `salbe`, `pulver` …
  final String art;

  /// Gruppe laut Regelwerk, z. B. `Spagyrik`.
  final String gruppe;

  /// Quelle der Werte.
  final AlchimikumBeleg beleg;

  /// Zuschlag der Brauprobe (nur Information).
  final int? brauProbe;

  /// Zuschlag der Analyseprobe (nur Information).
  final int? analyseProbe;

  /// Benötigtes Labor (nur Information).
  final String labor;

  /// Haltbarkeit als Regelwerkstext, z. B. `1W6+20 Monate`.
  final String haltbarkeit;

  /// Verbreitung laut Regelwerk.
  final String verbreitung;

  /// Richtpreis je Stück in Silbertalern, wenn das Regelwerk einen eindeutigen
  /// Wert nennt; `null` sonst.
  final int? preisSilber;

  /// Preisangabe als Text, wie sie das Regelwerk nennt.
  final String preisText;

  /// Kurzbeschreibung der Wirkung ohne Qualitätsstufe.
  final String wirkung;

  /// Qualitätsstufen `A` bis `F`; leer bei Mitteln ohne Stufen.
  final List<AlchimikumQualitaet> qualitaeten;

  /// Ob das Mittel Qualitätsstufen kennt.
  bool get hatQualitaeten => qualitaeten.isNotEmpty;

  /// Liest ein Mittel tolerant aus dem Katalog-JSON.
  factory AlchimikumDef.fromJson(Map<String, dynamic> json) {
    final belegJson = readCatalogObject(json, 'beleg');
    final preis = json['preisSilber'];
    final brau = json['brauProbe'];
    final analyse = json['analyseProbe'];
    return AlchimikumDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      art: readCatalogString(json, 'art', fallback: ''),
      gruppe: readCatalogString(json, 'gruppe', fallback: ''),
      beleg: belegJson == null
          ? const AlchimikumBeleg()
          : AlchimikumBeleg.fromJson(belegJson),
      brauProbe: brau is num ? brau.toInt() : null,
      analyseProbe: analyse is num ? analyse.toInt() : null,
      labor: readCatalogString(json, 'labor', fallback: ''),
      haltbarkeit: readCatalogString(json, 'haltbarkeit', fallback: ''),
      verbreitung: readCatalogString(json, 'verbreitung', fallback: ''),
      preisSilber: preis is num ? preis.toInt() : null,
      preisText: readCatalogString(json, 'preisText', fallback: ''),
      wirkung: readCatalogString(json, 'wirkung', fallback: ''),
      qualitaeten: readCatalogObjectList(
        json,
        'qualitaeten',
      ).map(AlchimikumQualitaet.fromJson).toList(growable: false),
    );
  }

  /// Schreibt das Mittel ohne leere Felder zurück.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      if (art.isNotEmpty) 'art': art,
      if (gruppe.isNotEmpty) 'gruppe': gruppe,
      'beleg': beleg.toJson(),
      if (brauProbe != null) 'brauProbe': brauProbe,
      if (analyseProbe != null) 'analyseProbe': analyseProbe,
      if (labor.isNotEmpty) 'labor': labor,
      if (haltbarkeit.isNotEmpty) 'haltbarkeit': haltbarkeit,
      if (verbreitung.isNotEmpty) 'verbreitung': verbreitung,
      if (preisSilber != null) 'preisSilber': preisSilber,
      if (preisText.isNotEmpty) 'preisText': preisText,
      if (wirkung.isNotEmpty) 'wirkung': wirkung,
      'qualitaeten': qualitaeten
          .map((stufe) => stufe.toJson())
          .toList(growable: false),
    };
  }
}
