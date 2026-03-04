import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_mode.dart';

/// Konfiguriert das Nebenhand-Objekt des Helden (Schild, Parierwaffe oder Linkhand).
///
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
class OffhandSlot {
  const OffhandSlot({
    this.mode = OffhandMode.none,
    this.name = '',
    this.atMod = 0,
    this.paMod = 0,
    this.iniMod = 0,
  });

  /// Art des Nebenhand-Objekts.
  final OffhandMode mode;

  /// Anzeigename des Nebenhand-Objekts.
  final String name;

  /// Attacke-Modifikator durch das Nebenhand-Objekt.
  final int atMod;

  /// Parade-Modifikator durch das Nebenhand-Objekt.
  final int paMod;

  /// Initiative-Modifikator durch das Nebenhand-Objekt.
  final int iniMod;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  OffhandSlot copyWith({
    OffhandMode? mode,
    String? name,
    int? atMod,
    int? paMod,
    int? iniMod,
  }) {
    return OffhandSlot(
      mode: mode ?? this.mode,
      name: name ?? this.name,
      atMod: atMod ?? this.atMod,
      paMod: paMod ?? this.paMod,
      iniMod: iniMod ?? this.iniMod,
    );
  }

  /// Serialisiert den Slot zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'mode': offhandModeToJson(mode),
      'name': name,
      'atMod': atMod,
      'paMod': paMod,
      'iniMod': iniMod,
    };
  }

  /// Deserialisiert einen [OffhandSlot] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwerte werden gesetzt).
  static OffhandSlot fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return OffhandSlot(
      mode: offhandModeFromJson((json['mode'] as String?) ?? 'none'),
      name: (json['name'] as String?) ?? '',
      atMod: getInt('atMod'),
      paMod: getInt('paMod'),
      iniMod: getInt('iniMod'),
    );
  }
}
