import 'package:dsa_heldenverwaltung/domain/combat_config/armor_piece.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_entry.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Kampfwerte eines abgelegten Gegenstands (ARCH-03, Entscheidung vom
/// 06.10.2026).
///
/// Wird ein Gegenstand im Kampfbereich nur abgelegt, verlässt sein Slot die
/// Kampfkonfiguration, das Exemplar bleibt als unverknüpfter
/// Inventareintrag. Dieser merkt sich hier den Slot, damit „In Kampfbereich
/// übernehmen“ ihn mit denselben Werten zurückholt. Genau eines der vier
/// Felder ist belegt. Die Slots tragen ihre eigenen unbekannten Felder.
class AbgelegterKampfgegenstand {
  /// Erstellt die gemerkten Kampfwerte; belegt wird genau ein Slot.
  const AbgelegterKampfgegenstand({
    this.waffe,
    this.geschoss,
    this.ruestungsteil,
    this.nebenhandteil,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Abgelegte Waffe.
  final MainWeaponSlot? waffe;

  /// Abgelegtes Geschoss; zurück kommt es an eine wählbare Fernkampfwaffe.
  final RangedProjectile? geschoss;

  /// Abgelegtes Rüstungsteil.
  final ArmorPiece? ruestungsteil;

  /// Abgelegtes Schild oder abgelegte Parierwaffe.
  final OffhandEquipmentEntry? nebenhandteil;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'waffe',
    'geschoss',
    'ruestungsteil',
    'nebenhandteil',
  };

  /// Ob diese Version einen der Slots kennt und zurückholen kann.
  bool get hatKampfwerte =>
      waffe != null ||
      geschoss != null ||
      ruestungsteil != null ||
      nebenhandteil != null;

  /// Gibt eine Kopie mit selektiv überschriebenen Feldern zurück.
  AbgelegterKampfgegenstand copyWith({
    MainWeaponSlot? waffe,
    RangedProjectile? geschoss,
    ArmorPiece? ruestungsteil,
    OffhandEquipmentEntry? nebenhandteil,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return AbgelegterKampfgegenstand(
      waffe: waffe ?? this.waffe,
      geschoss: geschoss ?? this.geschoss,
      ruestungsteil: ruestungsteil ?? this.ruestungsteil,
      nebenhandteil: nebenhandteil ?? this.nebenhandteil,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert nur die belegten Slots.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      if (waffe != null) 'waffe': waffe!.toJson(),
      if (geschoss != null) 'geschoss': geschoss!.toJson(),
      if (ruestungsteil != null) 'ruestungsteil': ruestungsteil!.toJson(),
      if (nebenhandteil != null) 'nebenhandteil': nebenhandteil!.toJson(),
    }, unbekannteFelder);
  }

  /// Liest die gemerkten Kampfwerte tolerant aus JSON.
  static AbgelegterKampfgegenstand fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? map(String key) {
      final roh = json[key];
      return roh is Map ? roh.cast<String, dynamic>() : null;
    }

    final waffe = map('waffe');
    final geschoss = map('geschoss');
    final ruestungsteil = map('ruestungsteil');
    final nebenhandteil = map('nebenhandteil');
    return AbgelegterKampfgegenstand(
      waffe: waffe == null ? null : MainWeaponSlot.fromJson(waffe),
      geschoss: geschoss == null ? null : RangedProjectile.fromJson(geschoss),
      ruestungsteil: ruestungsteil == null
          ? null
          : ArmorPiece.fromJson(ruestungsteil),
      nebenhandteil: nebenhandteil == null
          ? null
          : OffhandEquipmentEntry.fromJson(nebenhandteil),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
