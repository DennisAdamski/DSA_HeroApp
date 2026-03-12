/// Art eines Inventar-Modifikators: Stat, Attribut oder Talent.
enum InventoryModifierKind { stat, attribut, talent }

/// Kategorie eines Inventar-Eintrags.
enum InventoryItemType { ausruestung, verbrauchsgegenstand, wertvolles, sonstiges }

/// Ursprung eines Inventar-Eintrags.
///
/// Verlinkte Eintraege (nicht [manuell]) werden automatisch aus dem Kampf-Tab
/// synchronisiert und koennen nicht manuell geloescht werden.
enum InventoryItemSource { manuell, waffe, ruestung, geschoss, nebenhand }

/// Ein einzelner Modifikator an einem Inventar-Item, der greift, wenn das Item
/// als ausgeruest markiert ist.
///
/// Analog zu [HeroTalentModifier], aber mit typisiertem Ziel:
/// - [InventoryModifierKind.stat]: [targetId] ist ein Feldname aus
///   [StatModifiers] (z. B. `'gs'`, `'lep'`, `'at'`).
/// - [InventoryModifierKind.attribut]: [targetId] ist ein Attribut-Key
///   (`'mu'`, `'kl'`, `'inn'`, `'ch'`, `'ff'`, `'ge'`, `'ko'`, `'kk'`).
/// - [InventoryModifierKind.talent]: [targetId] ist eine Talent-ID.
class InventoryItemModifier {
  const InventoryItemModifier({
    required this.kind,
    required this.targetId,
    required this.wert,
    this.beschreibung = '',
  });

  final InventoryModifierKind kind;

  /// Ziel des Modifikators: Stat-Feldname, Attribut-Key oder Talent-ID.
  final String targetId;

  final int wert;

  /// Freitext-Quelle (max. 60 Zeichen). Wird beim Serialisieren nicht gekuerzt.
  final String beschreibung;

  InventoryItemModifier copyWith({
    InventoryModifierKind? kind,
    String? targetId,
    int? wert,
    String? beschreibung,
  }) {
    return InventoryItemModifier(
      kind: kind ?? this.kind,
      targetId: targetId ?? this.targetId,
      wert: wert ?? this.wert,
      beschreibung: beschreibung ?? this.beschreibung,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'targetId': targetId,
      'wert': wert,
      'beschreibung': beschreibung,
    };
  }

  static InventoryItemModifier fromJson(Map<String, dynamic> json) {
    final kindStr = (json['kind'] as String?) ?? 'stat';
    final kind = InventoryModifierKind.values.firstWhere(
      (e) => e.name == kindStr,
      orElse: () => InventoryModifierKind.stat,
    );
    return InventoryItemModifier(
      kind: kind,
      targetId: (json['targetId'] as String?) ?? '',
      wert: (json['wert'] as num?)?.toInt() ?? 0,
      beschreibung: (json['beschreibung'] as String?) ?? '',
    );
  }
}
