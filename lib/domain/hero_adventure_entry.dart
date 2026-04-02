import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';

/// Zieltyp einer Abenteuer-Sondererfahrung.
enum HeroAdventureSeTargetType {
  /// Sondererfahrung fuer ein Talent.
  talent,

  /// Sondererfahrung fuer einen kaufbaren Grundwert.
  grundwert,

  /// Sondererfahrung fuer eine Eigenschaft.
  eigenschaft,
}

/// Strukturierte SE-Zeile eines Abenteuers.
class HeroAdventureSeReward {
  /// Erzeugt eine persistierbare Abenteuer-SE-Zeile.
  const HeroAdventureSeReward({
    this.targetType = HeroAdventureSeTargetType.talent,
    this.targetId = '',
    this.targetLabel = '',
    this.count = 1,
  });

  /// Typ des Zielwerts.
  final HeroAdventureSeTargetType targetType;

  /// Persistierter Zielschluessel, z. B. Talent-ID oder Wertcode.
  final String targetId;

  /// Anzeigename des Zielwerts zum stabilen Anzeigen ohne Katalogzugriff.
  final String targetLabel;

  /// Anzahl der SE fuer das Ziel.
  final int count;

  /// Gibt an, ob die Zeile fachlich belegt ist.
  bool get hasContent {
    return targetId.trim().isNotEmpty && count > 0;
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroAdventureSeReward copyWith({
    HeroAdventureSeTargetType? targetType,
    String? targetId,
    String? targetLabel,
    int? count,
  }) {
    return HeroAdventureSeReward(
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      targetLabel: targetLabel ?? this.targetLabel,
      count: _normalizeCount(count ?? this.count),
    );
  }

  /// Serialisiert die Zeile fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'targetType': targetType.name,
      'targetId': targetId,
      'targetLabel': targetLabel,
      'count': count,
    };
  }

  /// Laedt eine SE-Zeile tolerant gegenueber fehlenden Feldern.
  static HeroAdventureSeReward fromJson(Map<String, dynamic> json) {
    return HeroAdventureSeReward(
      targetType: _parseAdventureSeTargetType(json['targetType']),
      targetId: (json['targetId'] as String?) ?? '',
      targetLabel: (json['targetLabel'] as String?) ?? '',
      count: _normalizeCount((json['count'] as num?)?.toInt() ?? 1),
    );
  }
}

/// Manuell gepflegter Abenteuer-Eintrag eines Helden.
class HeroAdventureEntry {
  /// Erzeugt ein persistierbares Abenteuer mit stabiler ID.
  const HeroAdventureEntry({
    required this.id,
    this.title = '',
    this.summary = '',
    this.notes = const <HeroNoteEntry>[],
    this.apReward = 0,
    this.seRewards = const <HeroAdventureSeReward>[],
    this.rewardsApplied = false,
  });

  /// Stabile ID des Abenteuers.
  final String id;

  /// Anzeigename des Abenteuers.
  final String title;

  /// Kurze Zusammenfassung oder Etappenbeschreibung.
  final String summary;

  /// Abenteuerbezogene Detailnotizen.
  final List<HeroNoteEntry> notes;

  /// AP-Belohnung fuer das Abenteuer.
  final int apReward;

  /// Strukturierte SE-Belohnungen des Abenteuers.
  final List<HeroAdventureSeReward> seRewards;

  /// Kennzeichnet, ob die Belohnungen bereits auf den Helden angewendet wurden.
  final bool rewardsApplied;

  /// Gibt an, ob das Abenteuer fachlich gefuellt ist.
  bool get hasContent {
    if (rewardsApplied || apReward > 0) {
      return true;
    }
    if (title.trim().isNotEmpty || summary.trim().isNotEmpty) {
      return true;
    }
    if (seRewards.any((entry) => entry.hasContent)) {
      return true;
    }
    return notes.any((entry) => _hasAdventureNoteContent(entry));
  }

  /// Gibt an, ob das Abenteuer eine anwendbare Belohnung besitzt.
  bool get hasRewards {
    return apReward > 0 || seRewards.any((entry) => entry.hasContent);
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroAdventureEntry copyWith({
    String? id,
    String? title,
    String? summary,
    List<HeroNoteEntry>? notes,
    int? apReward,
    List<HeroAdventureSeReward>? seRewards,
    bool? rewardsApplied,
  }) {
    return HeroAdventureEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      notes: notes ?? this.notes,
      apReward: _normalizeReward(apReward ?? this.apReward),
      seRewards: seRewards ?? this.seRewards,
      rewardsApplied: rewardsApplied ?? this.rewardsApplied,
    );
  }

  /// Serialisiert das Abenteuer fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'summary': summary,
      'notes': notes.map((entry) => entry.toJson()).toList(growable: false),
      'apReward': apReward,
      'seRewards': seRewards
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'rewardsApplied': rewardsApplied,
    };
  }

  /// Laedt ein Abenteuer tolerant gegenueber fehlenden Feldern.
  static HeroAdventureEntry fromJson(Map<String, dynamic> json) {
    final rawNotes = (json['notes'] as List?) ?? const <dynamic>[];
    final rawSeRewards = (json['seRewards'] as List?) ?? const <dynamic>[];

    return HeroAdventureEntry(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      notes: rawNotes
          .whereType<Map>()
          .map((entry) => HeroNoteEntry.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      apReward: _normalizeReward((json['apReward'] as num?)?.toInt() ?? 0),
      seRewards: rawSeRewards
          .whereType<Map>()
          .map(
            (entry) =>
                HeroAdventureSeReward.fromJson(entry.cast<String, dynamic>()),
          )
          .where((entry) => entry.hasContent)
          .toList(growable: false),
      rewardsApplied: json['rewardsApplied'] as bool? ?? false,
    );
  }
}

HeroAdventureSeTargetType _parseAdventureSeTargetType(dynamic raw) {
  return switch ((raw as String?)?.trim().toLowerCase()) {
    'grundwert' => HeroAdventureSeTargetType.grundwert,
    'eigenschaft' => HeroAdventureSeTargetType.eigenschaft,
    _ => HeroAdventureSeTargetType.talent,
  };
}

bool _hasAdventureNoteContent(HeroNoteEntry entry) {
  return entry.title.trim().isNotEmpty || entry.description.trim().isNotEmpty;
}

int _normalizeCount(int value) {
  return value < 0 ? 0 : value;
}

int _normalizeReward(int value) {
  return value < 0 ? 0 : value;
}
