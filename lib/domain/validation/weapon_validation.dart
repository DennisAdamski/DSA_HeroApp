import 'package:dsa_heldenverwaltung/domain/combat_config.dart';

/// Validiert einen Waffen-Slot fuer den Waffen-Editor.
///
/// Gibt eine Liste von Fehlermeldungen zurueck. Eine leere Liste bedeutet,
/// dass der Slot gespeichert werden kann.
List<String> validateWeaponSlot(MainWeaponSlot slot) {
  final errors = <String>[];

  if (slot.name.trim().isEmpty) {
    errors.add('Name ist erforderlich.');
  }
  if (slot.talentId.trim().isEmpty) {
    errors.add('Waffentalent ist erforderlich.');
  }
  if (slot.weaponType.trim().isEmpty) {
    errors.add('Waffenart ist erforderlich.');
  }
  if (slot.tpDiceCount < 1) {
    errors.add('Die Anzahl der TP-Wuerfel muss mindestens 1 sein.');
  }
  if (slot.kkThreshold < 1) {
    errors.add('Die KK-Schwelle muss mindestens 1 sein.');
  }
  final rangedProfile = slot.rangedProfile;
  if (rangedProfile.reloadTime < 0) {
    errors.add('Die Ladezeit darf nicht negativ sein.');
  }
  if (rangedProfile.distanceBands.length != 5) {
    errors.add('Fernkampfwaffen benoetigen genau fuenf Distanzstufen.');
  }

  for (final projectile in rangedProfile.projectiles) {
    if (projectile.count < 0) {
      errors.add('Geschossbestaende duerfen nicht negativ sein.');
      break;
    }
  }

  return errors;
}
