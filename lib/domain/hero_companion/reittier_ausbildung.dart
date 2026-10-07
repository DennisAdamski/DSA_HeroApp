/// Ausbildungsstand eines Reittiers (ZBA S. 32–37).
///
/// Die eingetragenen Werte des Begleiters (KK, LO, Angriffe, Geschwindigkeit)
/// enthalten bereits alles bis zur [ReittierAusbildung.ausgangsstufe]. Erst
/// die in der App gebuchten [ReittierAusbildung.schritte], die Variante
/// (beim Schritt nach „geschult“) und die Unarten verändern die Wirkwerte —
/// abgeleitet in `reittier_ausbildung_rules.dart`, nie in die Grundwerte
/// geschrieben. So zählt kein Schritt doppelt.
library;

import 'package:dsa_heldenverwaltung/domain/hero_companion/reittier_ausbildungsstufe.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

export 'package:dsa_heldenverwaltung/domain/hero_companion/reittier_ausbildungsstufe.dart';

/// Ausbildungsstand eines Reittiers.
class ReittierAusbildung {
  /// Erstellt den Ausbildungsstand.
  const ReittierAusbildung({
    this.ausgangsstufe = ReittierAusbildungsstufe.ungearbeitet,
    this.ausgangsart = ReittierAusbildungsart.laendlich,
    this.varianteId = '',
    this.schritte = const <ReittierAusbildungsschritt>[],
    this.unartIds = const <String>[],
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  });

  /// Stufe, bis zu der die eingetragenen Werte die Ausbildung schon enthalten.
  final ReittierAusbildungsstufe ausgangsstufe;

  /// Ausbildungsart bis zur [ausgangsstufe].
  final ReittierAusbildungsart ausgangsart;

  /// Gewählte Ausbildungsvariante (`pvar_…`), leer wenn keine.
  final String varianteId;

  /// In der App gebuchte Ausbildungsschritte, in Reihenfolge.
  final List<ReittierAusbildungsschritt> schritte;

  /// Unarten des Tiers (`punart_…`).
  final List<String> unartIds;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzählungswerte einer neueren App-Version (JSON-Schlüssel
  /// -> Rohwert); siehe `unbekannte_json_felder.dart`.
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'ausgangsstufe',
    'ausgangsart',
    'varianteId',
    'schritte',
    'unarten',
  };

  /// Kopie mit geänderten Feldern; ein anderer Enum-Wert ersetzt den
  /// bewahrten Rohwert, derselbe lässt ihn stehen.
  ReittierAusbildung copyWith({
    ReittierAusbildungsstufe? ausgangsstufe,
    ReittierAusbildungsart? ausgangsart,
    String? varianteId,
    List<ReittierAusbildungsschritt>? schritte,
    List<String>? unartIds,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
  }) {
    final stufeGeaendert =
        ausgangsstufe != null && ausgangsstufe != this.ausgangsstufe;
    final artGeaendert = ausgangsart != null && ausgangsart != this.ausgangsart;
    return ReittierAusbildung(
      ausgangsstufe: ausgangsstufe ?? this.ausgangsstufe,
      ausgangsart: ausgangsart ?? this.ausgangsart,
      varianteId: varianteId ?? this.varianteId,
      schritte: schritte ?? this.schritte,
      unartIds: unartIds ?? this.unartIds,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'ausgangsstufe': stufeGeaendert,
            'ausgangsart': artGeaendert,
          }),
    );
  }

  /// JSON-Abbild; leere Listen und eine leere Variante entfallen.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'ausgangsstufe': ausgangsstufe.name,
      'ausgangsart': ausgangsart.name,
      if (varianteId.isNotEmpty) 'varianteId': varianteId,
      if (schritte.isNotEmpty)
        'schritte': schritte.map((s) => s.toJson()).toList(growable: false),
      if (unartIds.isNotEmpty) 'unarten': unartIds,
    };
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(json, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Liest den Ausbildungsstand; unbekannte Stufen fallen auf
  /// „ungearbeitet“, unbekannte Arten auf „ländlich“ zurück.
  static ReittierAusbildung fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    return ReittierAusbildung(
      ausgangsstufe: leseEnumWert(
        json['ausgangsstufe'],
        'ausgangsstufe',
        erkenne: (roh) => enumNachName(ReittierAusbildungsstufe.values, roh),
        ersatz: ReittierAusbildungsstufe.ungearbeitet,
        unbekannt: enumRoh,
      ),
      ausgangsart: leseEnumWert(
        json['ausgangsart'],
        'ausgangsart',
        erkenne: (roh) => enumNachName(ReittierAusbildungsart.values, roh),
        ersatz: ReittierAusbildungsart.laendlich,
        unbekannt: enumRoh,
      ),
      varianteId: (json['varianteId'] as String?) ?? '',
      schritte: ((json['schritte'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (m) =>
                ReittierAusbildungsschritt.fromJson(m.cast<String, dynamic>()),
          )
          .toList(growable: false),
      unartIds: ((json['unarten'] as List?) ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }

  /// Liest den Wert unter `reittierAusbildung`; `null` ohne Eintrag.
  static ReittierAusbildung? fromJsonValue(Object? wert) {
    if (wert is! Map) {
      return null;
    }
    return fromJson(wert.cast<String, dynamic>());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReittierAusbildung &&
          ausgangsstufe == other.ausgangsstufe &&
          ausgangsart == other.ausgangsart &&
          varianteId == other.varianteId &&
          _listeGleich(schritte, other.schritte) &&
          _listeGleich(unartIds, other.unartIds) &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder) &&
          unbekannteFelderGleich(
            unbekannteEnumWerte,
            other.unbekannteEnumWerte,
          );

  @override
  int get hashCode => Object.hashAll(<Object?>[
    ausgangsstufe,
    ausgangsart,
    varianteId,
    ...schritte,
    ...unartIds,
    unbekannteFelderHash(unbekannteFelder),
    unbekannteFelderHash(unbekannteEnumWerte),
  ]);
}

/// Ein in der App gebuchter Ausbildungsschritt.
class ReittierAusbildungsschritt {
  /// Erstellt den Schritt.
  const ReittierAusbildungsschritt({
    required this.nach,
    required this.art,
    this.fehlschlaege = 0,
    this.ausbilder = '',
    this.notiz = '',
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  });

  /// Erreichte Stufe.
  final ReittierAusbildungsstufe nach;

  /// Ausbildungsart des Schritts.
  final ReittierAusbildungsart art;

  /// Misslungene Ausbilderproben (je drei ziehen eine Unart nach sich).
  final int fehlschlaege;

  /// Wer ausgebildet hat (Held oder Zureiter), als Freitext.
  final String ausbilder;

  /// Freie Notiz zum Schritt.
  final String notiz;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzählungswerte einer neueren App-Version.
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'nach',
    'art',
    'fehlschlaege',
    'ausbilder',
    'notiz',
  };

  /// Kopie mit geänderten Feldern.
  ReittierAusbildungsschritt copyWith({
    ReittierAusbildungsstufe? nach,
    ReittierAusbildungsart? art,
    int? fehlschlaege,
    String? ausbilder,
    String? notiz,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
  }) {
    return ReittierAusbildungsschritt(
      nach: nach ?? this.nach,
      art: art ?? this.art,
      fehlschlaege: fehlschlaege ?? this.fehlschlaege,
      ausbilder: ausbilder ?? this.ausbilder,
      notiz: notiz ?? this.notiz,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'nach': nach != null && nach != this.nach,
            'art': art != null && art != this.art,
          }),
    );
  }

  /// JSON-Abbild; Fehlschläge, Ausbilder und Notiz nur bei Belegung.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'nach': nach.name,
      'art': art.name,
      if (fehlschlaege > 0) 'fehlschlaege': fehlschlaege,
      if (ausbilder.isNotEmpty) 'ausbilder': ausbilder,
      if (notiz.isNotEmpty) 'notiz': notiz,
    };
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(json, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Liest den Schritt; unbekannte Stufen fallen auf „ungearbeitet“, unbekannte
  /// Arten auf „ländlich“ zurück.
  static ReittierAusbildungsschritt fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    return ReittierAusbildungsschritt(
      nach: leseEnumWert(
        json['nach'],
        'nach',
        erkenne: (roh) => enumNachName(ReittierAusbildungsstufe.values, roh),
        ersatz: ReittierAusbildungsstufe.ungearbeitet,
        unbekannt: enumRoh,
      ),
      art: leseEnumWert(
        json['art'],
        'art',
        erkenne: (roh) => enumNachName(ReittierAusbildungsart.values, roh),
        ersatz: ReittierAusbildungsart.laendlich,
        unbekannt: enumRoh,
      ),
      fehlschlaege: (json['fehlschlaege'] as num?)?.toInt() ?? 0,
      ausbilder: (json['ausbilder'] as String?) ?? '',
      notiz: (json['notiz'] as String?) ?? '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReittierAusbildungsschritt &&
          nach == other.nach &&
          art == other.art &&
          fehlschlaege == other.fehlschlaege &&
          ausbilder == other.ausbilder &&
          notiz == other.notiz &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder) &&
          unbekannteFelderGleich(
            unbekannteEnumWerte,
            other.unbekannteEnumWerte,
          );

  @override
  int get hashCode => Object.hash(
    nach,
    art,
    fehlschlaege,
    ausbilder,
    notiz,
    unbekannteFelderHash(unbekannteFelder),
    unbekannteFelderHash(unbekannteEnumWerte),
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
