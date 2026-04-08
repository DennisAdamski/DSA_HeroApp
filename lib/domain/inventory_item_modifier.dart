/// Art eines Inventar-Modifikators: Stat, Attribut, Talent oder Talentgruppe.
enum InventoryModifierKind { stat, attribut, talent, talentgruppe }

/// Kategorie eines Inventar-Eintrags.
enum InventoryItemType { ausruestung, verbrauchsgegenstand, wertvolles, sonstiges }

/// Ursprung eines Inventar-Eintrags.
///
/// Verlinkte Eintraege (nicht [manuell]) werden automatisch aus dem Kampf-Tab
/// synchronisiert und koennen nicht manuell geloescht werden. Die Quelle
/// [abenteuer] bleibt dagegen editierbar und wird ausschliesslich vom
/// Abenteuer-Abschluss verwendet.
enum InventoryItemSource {
  manuell,
  waffe,
  ruestung,
  geschoss,
  nebenhand,
  abenteuer,
}

/// Gibt an, ob der Ursprung aus dem Kampf-Tab stammt und daher technisch
/// verknuepft behandelt werden muss.
bool isCombatLinkedInventorySource(InventoryItemSource source) {
  return switch (source) {
    InventoryItemSource.waffe ||
    InventoryItemSource.ruestung ||
    InventoryItemSource.geschoss ||
    InventoryItemSource.nebenhand => true,
    InventoryItemSource.manuell || InventoryItemSource.abenteuer => false,
  };
}

/// Ein einzelner Modifikator an einem Inventar-Item, der greift, wenn das Item
/// als ausgeruest markiert ist.
///
/// Analog zu [HeroTalentModifier], aber mit typisiertem Ziel:
/// - [InventoryModifierKind.stat]: [targetId] ist ein Feldname aus
///   [StatModifiers] (z. B. `'gs'`, `'lep'`, `'at'`).
/// - [InventoryModifierKind.attribut]: [targetId] ist ein Attribut-Key
///   (`'mu'`, `'kl'`, `'inn'`, `'ch'`, `'ff'`, `'ge'`, `'ko'`, `'kk'`).
/// - [InventoryModifierKind.talent]: [targetId] ist eine Talent-ID.
/// - [InventoryModifierKind.talentgruppe]: [targetId] ist ein Gruppenname
///   (z. B. `'Körperliche Talente'`); der Bonus gilt fuer alle Talente
///   dieser Gruppe.
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

  /// Liefert eine Kopie mit gezielt ersetzten Modifikatorfeldern.
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

  /// Serialisiert den Modifikator fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'targetId': targetId,
      'wert': wert,
      'beschreibung': beschreibung,
    };
  }

  /// Laedt einen Inventar-Modifikator tolerant gegenueber fehlenden Feldern.
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
