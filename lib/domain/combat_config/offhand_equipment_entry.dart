import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_type.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/shield_size.dart';

/// Beschreibt ein Schild oder eine Parierwaffe im Kampf-Inventar.
class OffhandEquipmentEntry {
  const OffhandEquipmentEntry({
    this.name = '',
    this.type = OffhandEquipmentType.parryWeapon,
    this.breakFactor = 0,
    this.shieldSize = ShieldSize.small,
    this.iniMod = 0,
    this.atMod = 0,
    this.paMod = 0,
    this.isArtifact = false,
    this.artifactDescription = '',
  });

  /// Anzeigename des Eintrags.
  final String name;

  /// Typ des Nebenhand-Equipments.
  final OffhandEquipmentType type;

  /// Bruchfaktor des Eintrags.
  final int breakFactor;

  /// Groesse eines Schilds.
  final ShieldSize shieldSize;

  /// INI-Modifikator auf die Hauptwaffe.
  final int iniMod;

  /// AT-Modifikator auf die Hauptwaffe.
  final int atMod;

  /// PA-Modifikator des Eintrags.
  final int paMod;

  /// Kennzeichnet Schild oder Parierwaffe als Artefakt.
  final bool isArtifact;

  /// Freitext-Beschreibung fuer das Artefakt.
  final String artifactDescription;

  /// Gibt an, ob der Eintrag ein Schild ist.
  bool get isShield => type == OffhandEquipmentType.shield;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  OffhandEquipmentEntry copyWith({
    String? name,
    OffhandEquipmentType? type,
    int? breakFactor,
    ShieldSize? shieldSize,
    int? iniMod,
    int? atMod,
    int? paMod,
    bool? isArtifact,
    String? artifactDescription,
  }) {
    return OffhandEquipmentEntry(
      name: name ?? this.name,
      type: type ?? this.type,
      breakFactor: breakFactor ?? this.breakFactor,
      shieldSize: shieldSize ?? this.shieldSize,
      iniMod: iniMod ?? this.iniMod,
      atMod: atMod ?? this.atMod,
      paMod: paMod ?? this.paMod,
      isArtifact: isArtifact ?? this.isArtifact,
      artifactDescription: artifactDescription ?? this.artifactDescription,
    );
  }

  /// Serialisiert den Eintrag zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': offhandEquipmentTypeToJson(type),
      'breakFactor': breakFactor,
      'shieldSize': shieldSizeToJson(shieldSize),
      'iniMod': iniMod,
      'atMod': atMod,
      'paMod': paMod,
      'isArtifact': isArtifact,
      'artifactDescription': artifactDescription,
    };
  }

  /// Deserialisiert einen Eintrag aus einem JSON-Map.
  static OffhandEquipmentEntry fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return OffhandEquipmentEntry(
      name: (json['name'] as String?) ?? '',
      type: offhandEquipmentTypeFromJson((json['type'] as String?) ?? ''),
      breakFactor: getInt('breakFactor'),
      shieldSize: shieldSizeFromJson((json['shieldSize'] as String?) ?? ''),
      iniMod: getInt('iniMod'),
      atMod: getInt('atMod'),
      paMod: getInt('paMod'),
      isArtifact: (json['isArtifact'] as bool?) ?? false,
      artifactDescription: (json['artifactDescription'] as String?) ?? '',
    );
  }
}
