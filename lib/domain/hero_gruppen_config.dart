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
  });

  /// UUID der Gruppe — dient als Firestore-Dokumentschluessel.
  final String gruppenCode;

  /// Anzeigename der Gruppe.
  final String gruppenName;

  /// IDs externer Helden, die dieser Gruppe zugeordnet sind.
  /// Referenziert [ExternerHeld.id] in der externen-Helden-Box.
  final List<String> externeHeldIds;

  HeroGruppenMitgliedschaft copyWith({
    String? gruppenCode,
    String? gruppenName,
    List<String>? externeHeldIds,
  }) {
    return HeroGruppenMitgliedschaft(
      gruppenCode: gruppenCode ?? this.gruppenCode,
      gruppenName: gruppenName ?? this.gruppenName,
      externeHeldIds: externeHeldIds ?? this.externeHeldIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'gruppenCode': gruppenCode,
      'gruppenName': gruppenName,
      'externeHeldIds': externeHeldIds,
    };
  }

  static HeroGruppenMitgliedschaft fromJson(Map<String, dynamic> json) {
    final rawIds = json['externeHeldIds'] as List? ?? const [];
    return HeroGruppenMitgliedschaft(
      gruppenCode: json['gruppenCode'] as String? ?? '',
      gruppenName: json['gruppenName'] as String? ?? '',
      externeHeldIds: rawIds
          .whereType<String>()
          .toList(growable: false),
    );
  }
}
