/// Persistierter Reisebericht-Zustand eines Helden.
///
/// Speichert welche Eintraege abgehakt, welche offenen Sammlungseintraege
/// hinzugefuegt und welche Belohnungen bereits angewendet wurden.
class HeroReisebericht {
  const HeroReisebericht({
    this.checkedIds = const <String>{},
    this.openEntries = const <String, List<ReiseberichtOpenItem>>{},
    this.wahlSeZuordnungen = const <String, String>{},
    this.appliedRewardIds = const <String>{},
  });

  /// IDs aller abgehakten Eintraege und Sub-Items.
  final Set<String> checkedIds;

  /// Dynamische Eintraege fuer collection_open: defId → [Items].
  final Map<String, List<ReiseberichtOpenItem>> openEntries;

  /// Benutzergewaehlte SE-Zuordnung fuer 'wahl'-Eintraege: entryId → Talentname.
  final Map<String, String> wahlSeZuordnungen;

  /// IDs fuer die Belohnungen bereits angewendet wurden (Idempotenz-Guard).
  final Set<String> appliedRewardIds;

  HeroReisebericht copyWith({
    Set<String>? checkedIds,
    Map<String, List<ReiseberichtOpenItem>>? openEntries,
    Map<String, String>? wahlSeZuordnungen,
    Set<String>? appliedRewardIds,
  }) {
    return HeroReisebericht(
      checkedIds: checkedIds ?? this.checkedIds,
      openEntries: openEntries ?? this.openEntries,
      wahlSeZuordnungen: wahlSeZuordnungen ?? this.wahlSeZuordnungen,
      appliedRewardIds: appliedRewardIds ?? this.appliedRewardIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'checkedIds': checkedIds.toList(growable: false),
      'openEntries': openEntries.map(
        (key, value) => MapEntry(
          key,
          value.map((item) => item.toJson()).toList(growable: false),
        ),
      ),
      'wahlSeZuordnungen': wahlSeZuordnungen,
      'appliedRewardIds': appliedRewardIds.toList(growable: false),
    };
  }

  static HeroReisebericht fromJson(Map<String, dynamic> json) {
    final rawChecked = (json['checkedIds'] as List?) ?? const <dynamic>[];
    final rawApplied = (json['appliedRewardIds'] as List?) ?? const <dynamic>[];
    final rawWahl =
        (json['wahlSeZuordnungen'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawOpen =
        (json['openEntries'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return HeroReisebericht(
      checkedIds: rawChecked.map((entry) => entry.toString()).toSet(),
      appliedRewardIds: rawApplied.map((entry) => entry.toString()).toSet(),
      wahlSeZuordnungen: rawWahl.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      openEntries: rawOpen.map((key, value) {
        final items = (value is List) ? value : const <dynamic>[];
        return MapEntry(
          key,
          items
              .whereType<Map>()
              .map(
                (entry) =>
                    ReiseberichtOpenItem.fromJson(entry.cast<String, dynamic>()),
              )
              .toList(growable: false),
        );
      }),
    );
  }
}

/// Einzelner dynamischer Eintrag in einer offenen Sammlung.
class ReiseberichtOpenItem {
  const ReiseberichtOpenItem({
    required this.name,
    this.klassifikation = '',
    this.ap = 0,
  });

  /// Anzeigename (z. B. Kulturname, Katastrophenbezeichnung).
  final String name;

  /// Klassifikations-ID (z. B. 'normal', 'exotisch', 'ausseraventurisch').
  final String klassifikation;

  /// Berechneter AP-Wert aus der Klassifikation.
  final int ap;

  ReiseberichtOpenItem copyWith({
    String? name,
    String? klassifikation,
    int? ap,
  }) {
    return ReiseberichtOpenItem(
      name: name ?? this.name,
      klassifikation: klassifikation ?? this.klassifikation,
      ap: ap ?? this.ap,
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'name': name};
    if (klassifikation.isNotEmpty) result['klassifikation'] = klassifikation;
    if (ap > 0) result['ap'] = ap;
    return result;
  }

  static ReiseberichtOpenItem fromJson(Map<String, dynamic> json) {
    return ReiseberichtOpenItem(
      name: (json['name'] as String?) ?? '',
      klassifikation: (json['klassifikation'] as String?) ?? '',
      ap: (json['ap'] as num?)?.toInt() ?? 0,
    );
  }
}
