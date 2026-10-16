import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_laden.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_slot_instanz_rules.dart';

/// Ladebindung erlaubt geänderte Dauer, aber keine andere Waffe oder Munition.
String gefechtsLadeprofilKey(MainWeaponSlot waffe) {
  final json = ohneInstanzverweise(waffe.toJson());
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

/// Führt einen bekannten Ladezustand über eine reine Bestandsänderung mit.
///
/// Der Profilschlüssel enthält den Geschossbestand; ohne Übertrag wäre eine
/// geladene Waffe nach dem Aufheben von Geschossen wieder „unbekannt“.
/// Ändert sich mehr als der Bestand, bleibt der Ladezustand unbekannt.
Gefechtszustand uebertrageGefechtsLadestand(
  Gefechtszustand s, {
  required MainWeaponSlot vorher,
  required MainWeaponSlot nachher,
}) {
  final stand = s.ladestaende[vorher.id];
  if (stand == null ||
      vorher.id != nachher.id ||
      stand.waffenprofilKey != gefechtsLadeprofilKey(vorher) ||
      _ohneBestand(vorher) != _ohneBestand(nachher)) {
    return s;
  }
  return bestaetigeGefechtsLadung(s, nachher, stand.geladen);
}

String _ohneBestand(MainWeaponSlot waffe) {
  final profil = waffe.rangedProfile;
  return gefechtsLadeprofilKey(
    waffe.copyWith(
      rangedProfile: profil.copyWith(
        projectiles: [for (final g in profil.projectiles) g.copyWith(count: 0)],
      ),
    ),
  );
}
