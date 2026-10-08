/// Bindung eines Vertrauten an seine Hexe (WdZ S. 123–125).
///
/// Hält nur, was sich nicht aus den Werten des Begleiters ablesen lässt:
/// Art, Machtvoll, die bei der Hexe gebuchten Bindungskosten, übertragene AP,
/// den Zähler des AP-Anteils und gebuchte Ausbildungen. Die Startwerte selbst
/// stehen wie bei jedem Begleiter in seinen Grundwerten; Ausbildungen wirken
/// nur abgeleitet (`vertrauten_ausbildung_rules.dart`).
library;

import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Bindung eines Vertrauten.
class VertrautenBindung {
  /// Erstellt die Bindung.
  const VertrautenBindung({
    this.artId = '',
    this.machtvoll = false,
    this.bindungskosten,
    this.apUebertragen = 0,
    this.abenteuerApErfasst,
    this.ausbildungen = const <VertrautenAusbildungsbuchung>[],
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Vertrautenart (`vart_…`); leer für eine Art außerhalb des Katalogs.
  final String artId;

  /// Machtvoller Vertrauter (WdH S. 255).
  final bool machtvoll;

  /// Bei der Hexe als ausgegeben gebuchte AP; `null`, wenn die Bindung ohne
  /// Buchung erfasst wurde (Bestandsvertraute).
  final int? bindungskosten;

  /// Von der Hexe übertragene AP (WdZ S. 125), Grundlage der Loyalität.
  final int apUebertragen;

  /// Abenteuer-AP der Hexe, von denen der Vertraute seinen Anteil schon
  /// erhalten hat; `null`, solange der Anteil nicht eingerichtet ist.
  final int? abenteuerApErfasst;

  /// Gebuchte Ausbildungsstufen und Fertigkeiten, in Reihenfolge.
  final List<VertrautenAusbildungsbuchung> ausbildungen;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'artId',
    'machtvoll',
    'bindungskosten',
    'apUebertragen',
    'abenteuerApErfasst',
    'ausbildungen',
  };

  /// Kopie mit geänderten Feldern; nullable Felder lassen sich über
  /// [ohneBindungskosten] bzw. [ohneAbenteuerAp] leeren.
  VertrautenBindung copyWith({
    String? artId,
    bool? machtvoll,
    int? bindungskosten,
    bool ohneBindungskosten = false,
    int? apUebertragen,
    int? abenteuerApErfasst,
    bool ohneAbenteuerAp = false,
    List<VertrautenAusbildungsbuchung>? ausbildungen,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return VertrautenBindung(
      artId: artId ?? this.artId,
      machtvoll: machtvoll ?? this.machtvoll,
      bindungskosten: ohneBindungskosten
          ? null
          : bindungskosten ?? this.bindungskosten,
      apUebertragen: apUebertragen ?? this.apUebertragen,
      abenteuerApErfasst: ohneAbenteuerAp
          ? null
          : abenteuerApErfasst ?? this.abenteuerApErfasst,
      ausbildungen: ausbildungen ?? this.ausbildungen,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// JSON-Abbild; nur belegte Felder.
  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    if (artId.isNotEmpty) 'artId': artId,
    if (machtvoll) 'machtvoll': true,
    if (bindungskosten != null) 'bindungskosten': bindungskosten,
    if (apUebertragen != 0) 'apUebertragen': apUebertragen,
    if (abenteuerApErfasst != null) 'abenteuerApErfasst': abenteuerApErfasst,
    if (ausbildungen.isNotEmpty)
      'ausbildungen': ausbildungen
          .map((a) => a.toJson())
          .toList(growable: false),
  }, unbekannteFelder);

  /// Liest die Bindung.
  static VertrautenBindung fromJson(Map<String, dynamic> json) {
    return VertrautenBindung(
      artId: (json['artId'] as String?) ?? '',
      machtvoll: (json['machtvoll'] as bool?) ?? false,
      bindungskosten: (json['bindungskosten'] as num?)?.toInt(),
      apUebertragen: (json['apUebertragen'] as num?)?.toInt() ?? 0,
      abenteuerApErfasst: (json['abenteuerApErfasst'] as num?)?.toInt(),
      ausbildungen: ((json['ausbildungen'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (m) => VertrautenAusbildungsbuchung.fromJson(
              m.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  /// Liest den Wert unter `vertrautenBindung`; `null` ohne Eintrag.
  static VertrautenBindung? fromJsonValue(Object? wert) {
    if (wert is! Map) return null;
    return fromJson(wert.cast<String, dynamic>());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VertrautenBindung &&
          artId == other.artId &&
          machtvoll == other.machtvoll &&
          bindungskosten == other.bindungskosten &&
          apUebertragen == other.apUebertragen &&
          abenteuerApErfasst == other.abenteuerApErfasst &&
          _listeGleich(ausbildungen, other.ausbildungen) &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    artId,
    machtvoll,
    bindungskosten,
    apUebertragen,
    abenteuerApErfasst,
    ...ausbildungen,
    unbekannteFelderHash(unbekannteFelder),
  ]);
}

/// Eine gebuchte Ausbildungsstufe (`vausb_…`) oder Fertigkeit (`vfert_…`).
class VertrautenAusbildungsbuchung {
  /// Erstellt die Buchung.
  const VertrautenAusbildungsbuchung({
    required this.katalogId,
    this.apKosten = 0,
    this.bezeichnung = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Katalog-ID der Stufe oder Fertigkeit.
  final String katalogId;

  /// Aus den AP des Vertrauten bezahlte Kosten.
  final int apKosten;

  /// Freie Bezeichnung, z. B. der Name eines Tricks.
  final String bezeichnung;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'katalogId',
    'apKosten',
    'bezeichnung',
  };

  /// Kopie mit geänderten Feldern.
  VertrautenAusbildungsbuchung copyWith({
    String? katalogId,
    int? apKosten,
    String? bezeichnung,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return VertrautenAusbildungsbuchung(
      katalogId: katalogId ?? this.katalogId,
      apKosten: apKosten ?? this.apKosten,
      bezeichnung: bezeichnung ?? this.bezeichnung,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// JSON-Abbild; Kosten und Bezeichnung nur bei Belegung.
  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'katalogId': katalogId,
    if (apKosten != 0) 'apKosten': apKosten,
    if (bezeichnung.isNotEmpty) 'bezeichnung': bezeichnung,
  }, unbekannteFelder);

  /// Liest die Buchung.
  static VertrautenAusbildungsbuchung fromJson(Map<String, dynamic> json) {
    return VertrautenAusbildungsbuchung(
      katalogId: (json['katalogId'] as String?) ?? '',
      apKosten: (json['apKosten'] as num?)?.toInt() ?? 0,
      bezeichnung: (json['bezeichnung'] as String?) ?? '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VertrautenAusbildungsbuchung &&
          katalogId == other.katalogId &&
          apKosten == other.apKosten &&
          bezeichnung == other.bezeichnung &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hash(
    katalogId,
    apKosten,
    bezeichnung,
    unbekannteFelderHash(unbekannteFelder),
  );
}

// Vergleicht zwei Listen elementweise.
bool _listeGleich<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
