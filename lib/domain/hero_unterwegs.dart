import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Eine laufende Reise des Helden: von wo nach wo er unterwegs ist und nach
/// welchem Plan.
///
/// Gehört zum Laufzeitzustand (`HeroState.unterwegs`), weil sie sich im Spiel
/// häufig ändert. Die Ankunftsstation der Reiseroute entsteht erst bei der
/// Ankunft; Abreise, Reisemittel und Plan stehen solange in [anreise].
/// Kartenpositionen liegen wie bei `HeroReiseStation` im Avesmaps-System.
class HeroUnterwegs {
  /// Erzeugt die Reise.
  const HeroUnterwegs({
    required this.ziel,
    this.zielOrtId = '',
    this.zielKartenX,
    this.zielKartenY,
    this.vonOrt = '',
    this.vonOrtId = '',
    this.vonKartenX,
    this.vonKartenY,
    this.adventureId = '',
    this.anreise = const HeroReiseAnreise(),
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Name des Ziels (z. B. „Punin“).
  final String ziel;

  /// Avesmaps-Kennung des Ziels; leer ohne Kartenverweis.
  final String zielOrtId;

  /// Kartenposition des Ziels Ost-West, oder `null`.
  final double? zielKartenX;

  /// Kartenposition des Ziels Süd-Nord, oder `null`.
  final double? zielKartenY;

  /// Name des Ausgangsorts.
  final String vonOrt;

  /// Avesmaps-Kennung des Ausgangsorts; leer ohne Kartenverweis.
  final String vonOrtId;

  /// Kartenposition des Ausgangsorts Ost-West, oder `null`.
  final double? vonKartenX;

  /// Kartenposition des Ausgangsorts Süd-Nord, oder `null`.
  final double? vonKartenY;

  /// Abenteuer, dem die Reise zugeordnet ist; leer ohne Zuordnung.
  final String adventureId;

  /// Wege, Optimierung, Abreise und Plan der Reise.
  final HeroReiseAnreise anreise;

  /// JSON-Felder einer neueren App-Version.
  final Map<String, Object?> unbekannteFelder;

  /// Ob beide Enden eine Kartenposition tragen.
  bool get hatKartenpositionen =>
      zielKartenX != null &&
      zielKartenY != null &&
      vonKartenX != null &&
      vonKartenY != null;

  /// Alle Schluessel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'ziel',
    'zielOrtId',
    'zielKartenX',
    'zielKartenY',
    'vonOrt',
    'vonOrtId',
    'vonKartenX',
    'vonKartenY',
    'adventureId',
    'anreise',
  };

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroUnterwegs copyWith({
    String? ziel,
    String? zielOrtId,
    Object? zielKartenX = keepFieldValue,
    Object? zielKartenY = keepFieldValue,
    String? vonOrt,
    String? vonOrtId,
    Object? vonKartenX = keepFieldValue,
    Object? vonKartenY = keepFieldValue,
    String? adventureId,
    HeroReiseAnreise? anreise,
    Map<String, Object?>? unbekannteFelder,
  }) {
    double? wert(Object? neu, double? alt) =>
        identical(neu, keepFieldValue) ? alt : neu as double?;
    return HeroUnterwegs(
      ziel: ziel ?? this.ziel,
      zielOrtId: zielOrtId ?? this.zielOrtId,
      zielKartenX: wert(zielKartenX, this.zielKartenX),
      zielKartenY: wert(zielKartenY, this.zielKartenY),
      vonOrt: vonOrt ?? this.vonOrt,
      vonOrtId: vonOrtId ?? this.vonOrtId,
      vonKartenX: wert(vonKartenX, this.vonKartenX),
      vonKartenY: wert(vonKartenY, this.vonKartenY),
      adventureId: adventureId ?? this.adventureId,
      anreise: anreise ?? this.anreise,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Reise; optionale Felder nur bei Belegung.
  Map<String, dynamic> toJson() {
    final anreiseJson = anreise.toJson();
    return mitUnbekanntenFeldern(<String, dynamic>{
      'ziel': ziel,
      if (zielOrtId.isNotEmpty) 'zielOrtId': zielOrtId,
      if (zielKartenX != null) 'zielKartenX': zielKartenX,
      if (zielKartenY != null) 'zielKartenY': zielKartenY,
      if (vonOrt.isNotEmpty) 'vonOrt': vonOrt,
      if (vonOrtId.isNotEmpty) 'vonOrtId': vonOrtId,
      if (vonKartenX != null) 'vonKartenX': vonKartenX,
      if (vonKartenY != null) 'vonKartenY': vonKartenY,
      if (adventureId.isNotEmpty) 'adventureId': adventureId,
      if (anreiseJson.isNotEmpty) 'anreise': anreiseJson,
    }, unbekannteFelder);
  }

  /// Liest die Reise tolerant.
  static HeroUnterwegs fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString() ?? '';
    double? zahl(String key) {
      final roh = json[key];
      return roh is num && roh.isFinite ? roh.toDouble() : null;
    }

    return HeroUnterwegs(
      ziel: text('ziel'),
      zielOrtId: text('zielOrtId'),
      zielKartenX: zahl('zielKartenX'),
      zielKartenY: zahl('zielKartenY'),
      vonOrt: text('vonOrt'),
      vonOrtId: text('vonOrtId'),
      vonKartenX: zahl('vonKartenX'),
      vonKartenY: zahl('vonKartenY'),
      adventureId: text('adventureId'),
      anreise: json['anreise'] is Map
          ? HeroReiseAnreise.fromJson(
              Map<String, dynamic>.from(json['anreise'] as Map),
            )
          : const HeroReiseAnreise(),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
