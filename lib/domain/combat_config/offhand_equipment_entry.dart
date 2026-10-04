import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_type.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/shield_size.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Beschreibt ein Schild oder eine Parierwaffe im Kampf-Inventar.
class OffhandEquipmentEntry {
  const OffhandEquipmentEntry({
    this.id = '',
    this.name = '',
    this.type = OffhandEquipmentType.parryWeapon,
    this.breakFactor = 0,
    this.shieldSize = ShieldSize.small,
    this.iniMod = 0,
    this.atMod = 0,
    this.paMod = 0,
    this.isArtifact = false,
    this.artifactDescription = '',
    this.isGeweiht = false,
    this.geweihtDescription = '',
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  });

  /// Stabile Kennung des Nebenhand-Teils (siehe `CombatConfig.withStableIds`).
  final String id;

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

  /// Schild: AT-Modifikator der Hauptwaffe; Parierwaffe: deren eigener Angriff.
  final int atMod;

  /// PA-Modifikator des Eintrags.
  final int paMod;

  /// Kennzeichnet Schild oder Parierwaffe als Artefakt.
  final bool isArtifact;

  /// Freitext-Beschreibung fuer das Artefakt.
  final String artifactDescription;

  /// Kennzeichnet Schild oder Parierwaffe als geweiht.
  final bool isGeweiht;

  /// Freitext-Beschreibung fuer den geweihten Gegenstand.
  final String geweihtDescription;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzaehlungswerte einer neueren App-Version (JSON-Schluessel
  /// -> Rohwert). Die Felder tragen den Ersatzwert, mit dem Regeln rechnen;
  /// geschrieben wird der Rohwert, bis jemand das Feld auf einen anderen Wert
  /// setzt (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'name',
    'type',
    'breakFactor',
    'shieldSize',
    'iniMod',
    'atMod',
    'paMod',
    'isArtifact',
    'artifactDescription',
    'isGeweiht',
    'geweihtDescription',
  };

  /// Gibt an, ob der Eintrag ein Schild ist.
  bool get isShield => type == OffhandEquipmentType.shield;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  OffhandEquipmentEntry copyWith({
    String? id,
    String? name,
    OffhandEquipmentType? type,
    int? breakFactor,
    ShieldSize? shieldSize,
    int? iniMod,
    int? atMod,
    int? paMod,
    bool? isArtifact,
    String? artifactDescription,
    bool? isGeweiht,
    String? geweihtDescription,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
  }) {
    return OffhandEquipmentEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      breakFactor: breakFactor ?? this.breakFactor,
      shieldSize: shieldSize ?? this.shieldSize,
      iniMod: iniMod ?? this.iniMod,
      atMod: atMod ?? this.atMod,
      paMod: paMod ?? this.paMod,
      isArtifact: isArtifact ?? this.isArtifact,
      artifactDescription: artifactDescription ?? this.artifactDescription,
      isGeweiht: isGeweiht ?? this.isGeweiht,
      geweihtDescription: geweihtDescription ?? this.geweihtDescription,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'type': type != null && type != this.type,
            'shieldSize': shieldSize != null && shieldSize != this.shieldSize,
          }),
    );
  }

  /// Serialisiert den Eintrag zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'type': offhandEquipmentTypeToJson(type),
        'breakFactor': breakFactor,
        'shieldSize': shieldSizeToJson(shieldSize),
        'iniMod': iniMod,
        'atMod': atMod,
        'paMod': paMod,
        'isArtifact': isArtifact,
        'artifactDescription': artifactDescription,
        'isGeweiht': isGeweiht,
        'geweihtDescription': geweihtDescription,
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Deserialisiert einen Eintrag aus einem JSON-Map.
  static OffhandEquipmentEntry fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return OffhandEquipmentEntry(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      type: leseEnumWert(
        json['type'],
        'type',
        erkenne: offhandEquipmentTypeErkennen,
        ersatz: OffhandEquipmentType.parryWeapon,
        unbekannt: enumRoh,
      ),
      breakFactor: getInt('breakFactor'),
      shieldSize: leseEnumWert(
        json['shieldSize'],
        'shieldSize',
        erkenne: shieldSizeErkennen,
        ersatz: ShieldSize.small,
        unbekannt: enumRoh,
      ),
      iniMod: getInt('iniMod'),
      atMod: getInt('atMod'),
      paMod: getInt('paMod'),
      isArtifact: (json['isArtifact'] as bool?) ?? false,
      artifactDescription: (json['artifactDescription'] as String?) ?? '',
      isGeweiht: (json['isGeweiht'] as bool?) ?? false,
      geweihtDescription: (json['geweihtDescription'] as String?) ?? '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }
}
