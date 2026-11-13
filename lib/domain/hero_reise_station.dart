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
      lastModified: DateTime.tryParse(json['lastModified']?.toString() ?? ''),
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
