import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Eine Station der Reiseroute eines Helden: wo er wann war und was dort
/// geschah.
///
/// Die Kartenposition ([kartenX]/[kartenY]) liegt im Koordinatensystem von
/// Avesmaps (0 … 1024, Ursprung Südwest, `y` wächst nach Norden; eine Einheit
/// sind drei Meilen). Ohne Position bleibt die Station gültig und erscheint
/// nur in der Zeitleiste.
class HeroReiseStation {
  /// Erzeugt eine persistierbare Station.
  const HeroReiseStation({
    required this.id,
    this.ort = '',
    this.datum = const HeroAdventureDateValue(),
    this.notiz = '',
    this.adventureId = '',
    this.ortId = '',
    this.kartenX,
    this.kartenY,
    this.anreise,
    this.lastModified,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Stabile ID der Station.
  final String id;

  /// Ortsname als Freitext (z. B. „Gareth“).
  final String ort;

  /// Aventurisches Datum der Station; Speicherform wie bei Abenteuerdaten.
  final HeroAdventureDateValue datum;

  /// Was an dieser Station geschah.
  final String notiz;

  /// ID des Abenteuers, zu dem die Station gehört; leer ohne Zuordnung.
  final String adventureId;

  /// Dauerhafte Kennung des Orts bei Avesmaps (`id` der Entwickler-API); leer
  /// bei frei eingetragenen Orten und Orten ohne Kartenposition.
  final String ortId;

  /// Kartenposition Ost-West im Avesmaps-Kartensystem, oder `null`.
  final double? kartenX;

  /// Kartenposition Süd-Nord im Avesmaps-Kartensystem, oder `null`.
  final double? kartenY;

  /// Wie der Held von der vorigen Station hierher gereist ist (erlaubte
  /// Wege, Optimierung), oder `null` für die Vorgabe von Avesmaps.
  final HeroReiseAnreise? anreise;

  /// Zeitpunkt der letzten Bearbeitung (UTC).
  final DateTime? lastModified;

  /// Ob die Station eine Kartenposition trägt.
  bool get hatKartenposition => kartenX != null && kartenY != null;

  /// Gibt an, ob die Station fachlich belegt ist.
  bool get hasContent {
    return ort.trim().isNotEmpty || notiz.trim().isNotEmpty || datum.hasContent;
  }

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'ort',
    'datum',
    'notiz',
    'adventureId',
    'ortId',
    'kartenX',
    'kartenY',
    'anreise',
    'lastModified',
  };

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroReiseStation copyWith({
    String? id,
    String? ort,
    HeroAdventureDateValue? datum,
    String? notiz,
    String? adventureId,
    String? ortId,
    Object? kartenX = keepFieldValue,
    Object? kartenY = keepFieldValue,
    Object? anreise = keepFieldValue,
    Object? lastModified = keepFieldValue,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroReiseStation(
      id: id ?? this.id,
      ort: ort ?? this.ort,
      datum: datum ?? this.datum,
      notiz: notiz ?? this.notiz,
      adventureId: adventureId ?? this.adventureId,
      ortId: ortId ?? this.ortId,
      kartenX: identical(kartenX, keepFieldValue)
          ? this.kartenX
          : kartenX as double?,
      kartenY: identical(kartenY, keepFieldValue)
          ? this.kartenY
          : kartenY as double?,
      anreise: identical(anreise, keepFieldValue)
          ? this.anreise
          : anreise as HeroReiseAnreise?,
      lastModified: identical(lastModified, keepFieldValue)
          ? this.lastModified
          : lastModified as DateTime?,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Station; optionale Felder nur bei Belegung.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'id': id,
      if (ort.isNotEmpty) 'ort': ort,
      if (datum.istBelegt) 'datum': datum.toJson(),
      if (notiz.isNotEmpty) 'notiz': notiz,
      if (adventureId.isNotEmpty) 'adventureId': adventureId,
      if (ortId.isNotEmpty) 'ortId': ortId,
      if (kartenX != null) 'kartenX': kartenX,
      if (kartenY != null) 'kartenY': kartenY,
      if (anreise != null) 'anreise': anreise!.toJson(),
      if (lastModified != null)
        'lastModified': lastModified!.toUtc().toIso8601String(),
    }, unbekannteFelder);
  }

  /// Laedt eine Station tolerant gegenueber fehlenden Feldern.
  static HeroReiseStation fromJson(Map<String, dynamic> json) {
    String getString(String key) => json[key]?.toString() ?? '';

    return HeroReiseStation(
      id: getString('id'),
      ort: getString('ort'),
      datum: HeroAdventureDateValue.lese(json['datum']),
      notiz: getString('notiz'),
      adventureId: getString('adventureId'),
      ortId: getString('ortId'),
      kartenX: (json['kartenX'] as num?)?.toDouble(),
      kartenY: (json['kartenY'] as num?)?.toDouble(),
      anreise: json['anreise'] is Map
          ? HeroReiseAnreise.fromJson(
              Map<String, dynamic>.from(json['anreise'] as Map),
            )
          : null,
      lastModified: DateTime.tryParse(json['lastModified']?.toString() ?? ''),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}

/// Wie ein Held zu einer Station gereist ist: die erlaubten Wegarten und die
/// Optimierung, wie sie die Reiseschnittstelle von Avesmaps versteht, dazu
/// der Reiseplan (Abreise, Reisemittel, Tempo, Wetter, geplante Tage).
///
/// Die Werte bleiben Texte der Schnittstelle (`land`, `fluss`, `see`;
/// `schnellste`, `kuerzeste`) bzw. der Regeln (`fuss`, `beritten`, …).
/// Unbekannte Werte einer neueren App-Version bleiben so beim Speichern
/// erhalten; die Regeln übergehen sie. [geplanteTage] und [meilen] sind eine
/// Momentaufnahme des Plans, damit er ohne Netz und nach Ablauf des
/// Wegspeichers lesbar bleibt.
class HeroReiseAnreise {
  /// Erzeugt die Anreise.
  const HeroReiseAnreise({
    this.wege = const <String>[],
    this.optimierung = '',
    this.abreise = const HeroAdventureDateValue(),
    this.mittel = '',
    this.tempo = '',
    this.wetter = '',
    this.geplanteTage,
    this.meilen,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Erlaubte Wegarten; leer heißt alle.
  final List<String> wege;

  /// Optimierung; leer heißt die Vorgabe (`schnellste`).
  final String optimierung;

  /// Tag der Abreise von der vorigen Station; leer ohne Angabe.
  final HeroAdventureDateValue abreise;

  /// Reisemittel (`fuss`, `beritten`, `fuhrwerk`, `kutsche`); leer ohne Plan.
  final String mittel;

  /// Tempo (`normal`, `eil`); leer heißt normal.
  final String tempo;

  /// Wetter des Plans (`leicht`, `hitze`, …); leer heißt gutes Wetter.
  final String wetter;

  /// Geplante Reisetage nach Regelwerk, oder `null` ohne Plan.
  final double? geplanteTage;

  /// Strecke des Plans in Meilen, oder `null` ohne Plan.
  final double? meilen;

  /// JSON-Felder einer neueren App-Version.
  final Map<String, Object?> unbekannteFelder;

  /// Ob ein Reiseplan festgehalten ist.
  bool get hatPlan => geplanteTage != null;

  /// Alle Schluessel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'wege',
    'optimierung',
    'abreise',
    'mittel',
    'tempo',
    'wetter',
    'geplanteTage',
    'meilen',
  };

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroReiseAnreise copyWith({
    List<String>? wege,
    String? optimierung,
    HeroAdventureDateValue? abreise,
    String? mittel,
    String? tempo,
    String? wetter,
    Object? geplanteTage = keepFieldValue,
    Object? meilen = keepFieldValue,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroReiseAnreise(
      wege: wege ?? this.wege,
      optimierung: optimierung ?? this.optimierung,
      abreise: abreise ?? this.abreise,
      mittel: mittel ?? this.mittel,
      tempo: tempo ?? this.tempo,
      wetter: wetter ?? this.wetter,
      geplanteTage: identical(geplanteTage, keepFieldValue)
          ? this.geplanteTage
          : geplanteTage as double?,
      meilen: identical(meilen, keepFieldValue)
          ? this.meilen
          : meilen as double?,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Anreise; Felder nur bei Belegung.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      if (wege.isNotEmpty) 'wege': List<String>.of(wege),
      if (optimierung.isNotEmpty) 'optimierung': optimierung,
      if (abreise.istBelegt) 'abreise': abreise.toJson(),
      if (mittel.isNotEmpty) 'mittel': mittel,
      if (tempo.isNotEmpty) 'tempo': tempo,
      if (wetter.isNotEmpty) 'wetter': wetter,
      if (geplanteTage != null) 'geplanteTage': geplanteTage,
      if (meilen != null) 'meilen': meilen,
    }, unbekannteFelder);
  }

  /// Liest die Anreise tolerant.
  static HeroReiseAnreise fromJson(Map<String, dynamic> json) {
    final wege = json['wege'];
    double? zahl(String key) {
      final roh = json[key];
      return roh is num && roh.isFinite ? roh.toDouble() : null;
    }

    return HeroReiseAnreise(
      wege: List<String>.unmodifiable(<String>[
        if (wege is List)
          for (final w in wege)
            if (w is String && w.isNotEmpty) w,
      ]),
      optimierung: json['optimierung']?.toString() ?? '',
      abreise: HeroAdventureDateValue.lese(json['abreise']),
      mittel: json['mittel']?.toString() ?? '',
      tempo: json['tempo']?.toString() ?? '',
      wetter: json['wetter']?.toString() ?? '',
      geplanteTage: zahl('geplanteTage'),
      meilen: zahl('meilen'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}

/// Liest die Stationsliste tolerant; nur Einträge, die keine Objekte sind,
/// fallen weg.
List<HeroReiseStation> leseReiseStationen(Object? roh) {
  if (roh is! List) return const <HeroReiseStation>[];
  return List<HeroReiseStation>.unmodifiable([
    for (final eintrag in roh)
      if (eintrag is Map)
        HeroReiseStation.fromJson(Map<String, dynamic>.from(eintrag)),
  ]);
}
