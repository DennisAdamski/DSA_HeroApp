import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Freier Zustandsmarker des Helden (SPIEL-03), etwa „Betäubung“, „Furcht“
/// oder „Schmerz“.
///
/// Ein Marker ist eine Merkhilfe am Spieltisch und **keine Regelautomatik**:
/// Er verändert weder Werte noch Proben. Die optionale Dauer zählt der Spieler
/// pro Runde herunter (`HeroState.zustandsmarker`); ein abgelaufener Marker
/// (`rest == 0`) bleibt stehen, bis er entfernt wird.
///
/// Liegt im `HeroState` und wird nur bei Belegung ins JSON geschrieben, damit
/// Bestandszustände ihren Inhalts-Hash behalten.
class ZustandsMarker {
  /// Erstellt einen Marker.
  const ZustandsMarker({
    required this.id,
    required this.name,
    this.rest,
    this.notiz = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Stabile Kennung; der Sync führt die Liste über sie zusammen.
  final String id;

  /// Freier Name, etwa „Betäubung“.
  final String name;

  /// Verbleibende Runden; `null` heißt „ohne Dauer“.
  final int? rest;

  /// Freie Anmerkung, etwa die Quelle oder der Grund; leer, wenn keine.
  final String notiz;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'name',
    'rest',
    'notiz',
  };

  /// Ob der Marker eine Dauer trägt.
  bool get hatDauer => rest != null;

  /// Ob die Dauer abgelaufen ist (nur mit Dauer).
  bool get istAbgelaufen => rest != null && rest! <= 0;

  /// Kopie mit geänderten Feldern; `null` für [rest] entfernt die Dauer.
  ZustandsMarker copyWith({
    String? name,
    Object? rest = keepFieldValue,
    String? notiz,
  }) {
    return ZustandsMarker(
      id: id,
      name: name ?? this.name,
      rest: identical(rest, keepFieldValue) ? this.rest : rest as int?,
      notiz: notiz ?? this.notiz,
      unbekannteFelder: unbekannteFelder,
    );
  }

  /// Serialisiert nur belegte Werte.
  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'id': id,
    'name': name,
    'rest': ?rest,
    if (notiz.isNotEmpty) 'notiz': notiz,
  }, unbekannteFelder);

  /// Liest einen Marker; eine negative Dauer zählt als abgelaufen.
  static ZustandsMarker fromJson(Map<String, dynamic> json) {
    final rest = (json['rest'] as num?)?.toInt();
    return ZustandsMarker(
      id: json['id'] is String ? json['id'] as String : '',
      name: json['name'] is String ? json['name'] as String : '',
      rest: rest == null ? null : (rest < 0 ? 0 : rest),
      notiz: json['notiz'] is String ? json['notiz'] as String : '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  /// Liest die Liste aus dem JSON und sichert eindeutige, nicht leere IDs zu.
  ///
  /// Ein Eintrag ohne ID oder mit doppelter ID bekommt eine feste Ersatz-ID
  /// (`marker-<Stelle>`), damit der Sync die Liste je Element zusammenführen
  /// kann; verworfen wird nichts.
  static List<ZustandsMarker> listeAusJson(List<dynamic> roh) {
    final gelesen = roh
        .whereType<Map>()
        .map((e) => ZustandsMarker.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
    final gesehen = <String>{};
    final ergebnis = <ZustandsMarker>[];
    for (var i = 0; i < gelesen.length; i++) {
      var marker = gelesen[i];
      if (marker.id.isEmpty || gesehen.contains(marker.id)) {
        var ersatz = 'marker-$i';
        while (gesehen.contains(ersatz)) {
          ersatz = '$ersatz-';
        }
        marker = ZustandsMarker(
          id: ersatz,
          name: marker.name,
          rest: marker.rest,
          notiz: marker.notiz,
          unbekannteFelder: marker.unbekannteFelder,
        );
      }
      gesehen.add(marker.id);
      ergebnis.add(marker);
    }
    return List<ZustandsMarker>.unmodifiable(ergebnis);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZustandsMarker &&
          id == other.id &&
          name == other.name &&
          rest == other.rest &&
          notiz == other.notiz &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    rest,
    notiz,
    unbekannteFelderHash(unbekannteFelder),
  );
}
