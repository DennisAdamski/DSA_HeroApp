import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';

/// Aggregiertes Ergebnis aller aktiven Inventar-Modifikatoren.
class InventoryModifierAggregation {
  const InventoryModifierAggregation({
    this.statMods = const StatModifiers(),
    this.attributeMods = const AttributeModifiers(),
    this.talentMods = const <String, int>{},
  });

  /// Aggregierte Stat-Modifikatoren (GS, LeP, AT, PA, usw.).
  final StatModifiers statMods;

  /// Aggregierte Eigenschafts-Modifikatoren (MU, KL, IN, usw.).
  final AttributeModifiers attributeMods;

  /// Aggregierte Talentboni je Talent-ID.
  final Map<String, int> talentMods;
}

/// Aggregiert alle Modifikatoren ausgeruesteter Inventar-Items.
///
/// Nur Eintraege mit [HeroInventoryEntry.istAusgeruestet] == true und
/// [InventoryItemType.ausruestung] werden beruecksichtigt.
///
/// [InventoryModifierKind.stat] → [InventoryModifierAggregation.statMods]
/// [InventoryModifierKind.attribut] → [InventoryModifierAggregation.attributeMods]
/// [InventoryModifierKind.talent] → [InventoryModifierAggregation.talentMods]
InventoryModifierAggregation aggregateInventoryModifiers(
  List<HeroInventoryEntry> entries,
) {
  var statMods = const StatModifiers();
  var attributeMods = const AttributeModifiers();
  final talentMods = <String, int>{};

  for (final entry in entries) {
    if (!entry.istAusgeruestet) continue;
    if (entry.itemType != InventoryItemType.ausruestung) continue;

    for (final mod in entry.modifiers) {
      switch (mod.kind) {
        case InventoryModifierKind.stat:
          statMods = _applyStatMod(statMods, mod.targetId, mod.wert);
        case InventoryModifierKind.attribut:
          attributeMods = _applyAttributeMod(
            attributeMods,
            mod.targetId,
            mod.wert,
          );
        case InventoryModifierKind.talent:
          talentMods[mod.targetId] =
              (talentMods[mod.targetId] ?? 0) + mod.wert;
      }
    }
  }

  return InventoryModifierAggregation(
    statMods: statMods,
    attributeMods: attributeMods,
    talentMods: Map<String, int>.unmodifiable(talentMods),
  );
}

// ---------------------------------------------------------------------------
// Hilfsfunktionen
// ---------------------------------------------------------------------------

/// Wendet einen einzelnen Stat-Modifikator anhand des Feldnamens an.
///
/// Unbekannte Feldnamen werden ignoriert.
StatModifiers _applyStatMod(StatModifiers base, String field, int value) {
  switch (field) {
    case 'lep':
      return base.copyWith(lep: base.lep + value);
    case 'au':
      return base.copyWith(au: base.au + value);
    case 'asp':
      return base.copyWith(asp: base.asp + value);
    case 'kap':
      return base.copyWith(kap: base.kap + value);
    case 'mr':
      return base.copyWith(mr: base.mr + value);
    case 'iniBase':
      return base.copyWith(iniBase: base.iniBase + value);
    case 'at':
      return base.copyWith(at: base.at + value);
    case 'pa':
      return base.copyWith(pa: base.pa + value);
    case 'fk':
      return base.copyWith(fk: base.fk + value);
    case 'gs':
      return base.copyWith(gs: base.gs + value);
    case 'ausweichen':
      return base.copyWith(ausweichen: base.ausweichen + value);
    case 'rs':
      return base.copyWith(rs: base.rs + value);
    default:
      return base;
  }
}

/// Wendet einen einzelnen Eigenschafts-Modifikator anhand des Schluessel-Names an.
///
/// Unbekannte Schluessel werden ignoriert.
AttributeModifiers _applyAttributeMod(
  AttributeModifiers base,
  String field,
  int value,
) {
  switch (field) {
    case 'mu':
      return base.copyWith(mu: base.mu + value);
    case 'kl':
      return base.copyWith(kl: base.kl + value);
    case 'inn':
      return base.copyWith(inn: base.inn + value);
    case 'ch':
      return base.copyWith(ch: base.ch + value);
    case 'ff':
      return base.copyWith(ff: base.ff + value);
    case 'ge':
      return base.copyWith(ge: base.ge + value);
    case 'ko':
      return base.copyWith(ko: base.ko + value);
    case 'kk':
      return base.copyWith(kk: base.kk + value);
    default:
      return base;
  }
}
