import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_laden.dart';

/// Ladebindung erlaubt geänderte Dauer, aber keine andere Waffe oder Munition.
String gefechtsLadeprofilKey(MainWeaponSlot waffe) {
  final json = waffe.toJson();
  final ranged = Map<String, dynamic>.from(json['rangedProfile'] as Map);
  ranged.remove('reloadTime');
  json['rangedProfile'] = ranged;
  return jsonEncode(json);
}

/// Unbekannte/geänderte Profile erhalten keinen Ladezustand aus einer anderen Waffe.
bool? gefechtsLadezustand(Gefechtszustand s, MainWeaponSlot? waffe) {
  if (waffe == null || waffe.id.isEmpty) return null;
  final stand = s.ladestaende[waffe.id];
  if (stand == null || stand.waffenprofilKey != gefechtsLadeprofilKey(waffe)) {
    return null;
  }
  return stand.geladen;
}

/// Speichert ausschließlich den explizit erfragten Anfangszustand dieser Waffe.
Gefechtszustand bestaetigeGefechtsLadung(
  Gefechtszustand s,
  MainWeaponSlot waffe,
  bool geladen,
) {
  final g = waffe.rangedProfile.selectedProjectileOrNull;
  if (waffe.id.isEmpty || g == null || g.id.isEmpty) {
    throw StateError(
      'Stabile Waffen-/Geschoss-ID und Geschossprofil erforderlich.',
    );
  }
  return s.copyWith(
    ladestaende: {
      ...s.ladestaende,
      waffe.id: Gefechtsladestand(
        waffenprofilKey: gefechtsLadeprofilKey(waffe),
        geschossId: g.id,
        geladen: geladen,
      ),
    },
  );
}
