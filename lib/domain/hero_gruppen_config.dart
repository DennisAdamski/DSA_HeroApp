import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Mitgliedschaft eines Helden in einer Gruppe.
///
/// Ein Held kann mehreren Gruppen gleichzeitig angehoeren.
/// Der [gruppenCode] identifiziert die Gruppe in Firestore
/// (Collection `gruppen/{gruppenCode}/mitglieder`).
class HeroGruppenMitgliedschaft {
  const HeroGruppenMitgliedschaft({
    required this.gruppenCode,
    this.gruppenName = '',
    this.externeHeldIds = const <String>[],
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// UUID der Gruppe — dient als Firestore-Dokumentschluessel.
  final String gruppenCode;

  /// Anzeigename der Gruppe.
  final String gruppenName;

  /// IDs externer Helden, die dieser Gruppe zugeordnet sind.
  /// Referenziert [ExternerHeld.id] in der externen-Helden-Box.
  final List<String> externeHeldIds;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'gruppenCode',
    'gruppenName',
    'externeHeldIds',
  };

  HeroGruppenMitgliedschaft copyWith({
    String? gruppenCode,
    String? gruppenName,
    List<String>? externeHeldIds,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroGruppenMitgliedschaft(
      gruppenCode: gruppenCode ?? this.gruppenCode,
      gruppenName: gruppenName ?? this.gruppenName,
      externeHeldIds: externeHeldIds ?? this.externeHeldIds,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'gruppenCode': gruppenCode,
      'gruppenName': gruppenName,
      'externeHeldIds': externeHeldIds,
    }, unbekannteFelder);
  }

  static HeroGruppenMitgliedschaft fromJson(Map<String, dynamic> json) {
    final rawIds = json['externeHeldIds'] as List? ?? const [];
    return HeroGruppenMitgliedschaft(
      gruppenCode: json['gruppenCode'] as String? ?? '',
      gruppenName: json['gruppenName'] as String? ?? '',
      externeHeldIds: rawIds.whereType<String>().toList(growable: false),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
