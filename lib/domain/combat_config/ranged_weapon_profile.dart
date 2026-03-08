import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_distance_band.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';

/// Zusatzprofil fuer Fernkampfwaffen mit Distanzstufen und Geschossen.
class RangedWeaponProfile {
  const RangedWeaponProfile({
    this.reloadTime = 0,
    this.distanceBands = const <RangedDistanceBand>[
      RangedDistanceBand(label: 'Distanz 1'),
      RangedDistanceBand(label: 'Distanz 2'),
      RangedDistanceBand(label: 'Distanz 3'),
      RangedDistanceBand(label: 'Distanz 4'),
      RangedDistanceBand(label: 'Distanz 5'),
    ],
    this.projectiles = const <RangedProjectile>[],
    this.selectedDistanceIndex = 0,
    this.selectedProjectileIndex = -1,
  });

  /// Feste Ladezeit der Fernkampfwaffe.
  final int reloadTime;

  /// Genau fuenf Distanzstufen der Waffe.
  final List<RangedDistanceBand> distanceBands;

  /// Verfuegbare Geschosstypen der Waffe.
  final List<RangedProjectile> projectiles;

  /// Persistierte aktive Distanzstufe.
  final int selectedDistanceIndex;

  /// Persistiertes aktives Geschoss; -1 bedeutet keines.
  final int selectedProjectileIndex;

  /// Gibt die aktive Distanzstufe tolerant zurueck.
  RangedDistanceBand get selectedDistanceBand {
    final bands = _normalizeDistanceBands(distanceBands);
    final index = _normalizeDistanceIndex(selectedDistanceIndex);
    return bands[index];
  }

  /// Gibt das aktive Geschoss oder `null` zurueck.
  RangedProjectile? get selectedProjectileOrNull {
    final normalizedProjectiles = _normalizeProjectiles(projectiles);
    final index = _normalizeProjectileIndex(
      selectedProjectileIndex,
      normalizedProjectiles.length,
    );
    if (index < 0) {
      return null;
    }
    return normalizedProjectiles[index];
  }

  /// Gibt an, ob mindestens ein Geschoss hinterlegt ist.
  bool get hasProjectiles => _normalizeProjectiles(projectiles).isNotEmpty;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  RangedWeaponProfile copyWith({
    int? reloadTime,
    List<RangedDistanceBand>? distanceBands,
    List<RangedProjectile>? projectiles,
    int? selectedDistanceIndex,
    int? selectedProjectileIndex,
  }) {
    final nextBands = _normalizeDistanceBands(
      distanceBands ?? this.distanceBands,
    );
    final nextProjectiles = _normalizeProjectiles(
      projectiles ?? this.projectiles,
    );
    return RangedWeaponProfile(
      reloadTime: reloadTime ?? this.reloadTime,
      distanceBands: nextBands,
      projectiles: nextProjectiles,
      selectedDistanceIndex: _normalizeDistanceIndex(
        selectedDistanceIndex ?? this.selectedDistanceIndex,
      ),
      selectedProjectileIndex: _normalizeProjectileIndex(
        selectedProjectileIndex ?? this.selectedProjectileIndex,
        nextProjectiles.length,
      ),
    );
  }

  /// Serialisiert das Fernkampfprofil fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    final normalizedBands = _normalizeDistanceBands(distanceBands);
    final normalizedProjectiles = _normalizeProjectiles(projectiles);
    return {
      'reloadTime': reloadTime,
      'distanceBands': normalizedBands
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'projectiles': normalizedProjectiles
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'selectedDistanceIndex': _normalizeDistanceIndex(selectedDistanceIndex),
      'selectedProjectileIndex': _normalizeProjectileIndex(
        selectedProjectileIndex,
        normalizedProjectiles.length,
      ),
    };
  }

  /// Liest ein Fernkampfprofil tolerant aus JSON.
  static RangedWeaponProfile fromJson(Map<String, dynamic> json) {
    final rawBands = (json['distanceBands'] as List?) ?? const <dynamic>[];
    final rawProjectiles = (json['projectiles'] as List?) ?? const <dynamic>[];
    return RangedWeaponProfile(
      reloadTime: (json['reloadTime'] as num?)?.toInt() ?? 0,
      distanceBands: _normalizeDistanceBands(
        rawBands
            .whereType<Map>()
            .map(
              (entry) =>
                  RangedDistanceBand.fromJson(entry.cast<String, dynamic>()),
            )
            .toList(growable: false),
      ),
      projectiles: _normalizeProjectiles(
        rawProjectiles
            .whereType<Map>()
            .map(
              (entry) =>
                  RangedProjectile.fromJson(entry.cast<String, dynamic>()),
            )
            .toList(growable: false),
      ),
      selectedDistanceIndex:
          (json['selectedDistanceIndex'] as num?)?.toInt() ?? 0,
      selectedProjectileIndex:
          (json['selectedProjectileIndex'] as num?)?.toInt() ?? -1,
    );
  }
}

List<RangedDistanceBand> _normalizeDistanceBands(
  List<RangedDistanceBand> values,
) {
  final normalized = List<RangedDistanceBand>.from(values, growable: true);
  while (normalized.length < 5) {
    final nextIndex = normalized.length + 1;
    normalized.add(RangedDistanceBand(label: 'Distanz $nextIndex'));
  }
  if (normalized.length > 5) {
    normalized.removeRange(5, normalized.length);
  }
  return List<RangedDistanceBand>.unmodifiable(normalized);
}

List<RangedProjectile> _normalizeProjectiles(List<RangedProjectile> values) {
  final normalized = <RangedProjectile>[];
  for (final value in values) {
    normalized.add(
      value.copyWith(
        name: value.name.trim(),
        description: value.description.trim(),
        count: value.count < 0 ? 0 : value.count,
      ),
    );
  }
  return List<RangedProjectile>.unmodifiable(normalized);
}

int _normalizeDistanceIndex(int value) {
  if (value < 0) {
    return 0;
  }
  if (value > 4) {
    return 4;
  }
  return value;
}

int _normalizeProjectileIndex(int value, int length) {
  if (length <= 0) {
    return -1;
  }
  if (value < 0) {
    return -1;
  }
  if (value >= length) {
    return length - 1;
  }
  return value;
}
