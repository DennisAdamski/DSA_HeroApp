import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Mitgliedschaft eines Helden in einer Gruppe.
///
/// Ein Held kann mehreren Gruppen gleichzeitig angehoeren.
/// Der [gruppenCode] ist die Dokument-ID der Gruppe in Firestore
/// (`groups_v2/{gruppenCode}`, siehe [kontoGruppe]). Der teilbare
/// Beitrittscode steht nicht hier, sondern im Gruppendokument.
class HeroGruppenMitgliedschaft {
  const HeroGruppenMitgliedschaft({
    required this.gruppenCode,
    this.gruppenName = '',
    this.externeHeldIds = const <String>[],
    this.kontoGruppe = false,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// UUID der Gruppe — dient als Firestore-Dokumentschluessel.
  final String gruppenCode;

  /// Anzeigename der Gruppe.
  final String gruppenName;

  /// IDs externer Helden, die dieser Gruppe zugeordnet sind.
  /// Referenziert [ExternerHeld.id] in der externen-Helden-Box.
  final List<String> externeHeldIds;

  /// `true` bei Gruppen im UID-gebundenen Format `groups_v2`.
  ///
  /// Gruppen ohne diese Markierung stammen aus dem gesperrten Legacy-Pfad
  /// `gruppen/*`: Sie werden nie synchronisiert oder automatisch übernommen.
  final bool kontoGruppe;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'gruppenCode',
    'gruppenName',
    'externeHeldIds',
    'kontoGruppe',
  };

  HeroGruppenMitgliedschaft copyWith({
    String? gruppenCode,
    String? gruppenName,
    List<String>? externeHeldIds,
    bool? kontoGruppe,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroGruppenMitgliedschaft(
      gruppenCode: gruppenCode ?? this.gruppenCode,
      gruppenName: gruppenName ?? this.gruppenName,
      externeHeldIds: externeHeldIds ?? this.externeHeldIds,
      kontoGruppe: kontoGruppe ?? this.kontoGruppe,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'gruppenCode': gruppenCode,
      'gruppenName': gruppenName,
      'externeHeldIds': externeHeldIds,
      // Nur bei Belegung, damit sich der Hash von Bestandshelden nicht ändert.
      if (kontoGruppe) 'kontoGruppe': true,
    }, unbekannteFelder);
  }

  static HeroGruppenMitgliedschaft fromJson(Map<String, dynamic> json) {
    final rawIds = json['externeHeldIds'] as List? ?? const [];
    return HeroGruppenMitgliedschaft(
      gruppenCode: json['gruppenCode'] as String? ?? '',
      gruppenName: json['gruppenName'] as String? ?? '',
      externeHeldIds: rawIds.whereType<String>().toList(growable: false),
      kontoGruppe: json['kontoGruppe'] == true,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
