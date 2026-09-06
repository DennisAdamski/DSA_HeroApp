/// Zielart eines geplanten oder übernommenen Steigerungsschritts.
enum AdvancementKind {
  attribute,
  talent,
  spell,
  generalAbility,
  magicAbility,
  karmalAbility,
  combatAbility,
  boughtStat,
  language,
  script,
}

/// Unveränderlicher Steigerungsbefehl und historischer Erwerbsnachweis.
///
/// Kosten stammen aus dem bestätigten Dialog, einschließlich Hausregeln.
/// `-1` als Ausgangswert bedeutet Aktivierung. Erwerbsoptionen dokumentieren
/// unter anderem Varianten, Repräsentationen und bestätigte Meisterentscheide.
class HeroAdvancementEntry {
  /// Übernimmt die Erwerbsentscheidung und schützt ihre Optionen vor Mutation.
  HeroAdvancementEntry({
    required this.id,
    required this.sessionId,
    required this.createdAt,
    required this.kind,
    required this.targetId,
    required this.label,
    this.fromValue,
    this.toValue,
    required this.apCost,
    this.seSpent = 0,
    Map<String, String> options = const {},
  }) : options = Map<String, String>.unmodifiable(options);

  final String id;
  final String sessionId;
  final DateTime createdAt;
  final AdvancementKind kind;
  final String targetId;
  final String label;
  final int? fromValue;
  final int? toValue;
  final int apCost;
  final int seSpent;
  final Map<String, String> options;

  /// Serialisiert den vollständigen Erwerbsnachweis für Export und Persistenz.
  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'kind': kind.name,
    'targetId': targetId,
    'label': label,
    if (fromValue != null) 'fromValue': fromValue,
    if (toValue != null) 'toValue': toValue,
    'apCost': apCost,
    'seSpent': seSpent,
    'options': options,
  };

  /// Lädt einen Erwerbsnachweis, ohne fehlende Historie zu erfinden.
  static HeroAdvancementEntry fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as Map?) ?? const {};
    return HeroAdvancementEntry(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      kind: AdvancementKind.values.byName(json['kind'] as String),
      targetId: json['targetId'] as String,
      label: json['label'] as String? ?? '',
      fromValue: (json['fromValue'] as num?)?.toInt(),
      toValue: (json['toValue'] as num?)?.toInt(),
      apCost: (json['apCost'] as num?)?.toInt() ?? 0,
      seSpent: (json['seSpent'] as num?)?.toInt() ?? 0,
      options: rawOptions.map((key, value) => MapEntry('$key', '$value')),
    );
  }
}
