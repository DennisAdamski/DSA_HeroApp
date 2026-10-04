import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

import 'kampf_aenderung_rules.dart';
import 'string_normalize.dart';

/// Bekannte Schusswaffen benötigen beide Hände; Arsenal (MCP 70) erlaubt Balestrina.
/// Waffenart bleibt bei umbenannten Slots stabil. Unbekannte und Wurfwaffen
/// verwenden ihre gespeicherte Belegung, ohne persistierte Daten zu verändern.
bool gefechtsWaffeEinhaendig(MainWeaponSlot waffe) {
  final typ = normalizeCombatToken(waffe.weaponType);
  if (typ == 'balestrina') return true;
  final talent = normalizeCombatToken(waffe.talentId);
  const schusstalente = {'talboegen', 'talbogen', 'talarmbrust'};
  final schusswaffe =
      schusstalente.contains(talent) ||
      typ.contains('bogen') ||
      typ.contains('armbrust') ||
      typ == 'eisenwalder' ||
      typ == 'ballaester' ||
      typ == 'balestra' ||
      typ.startsWith('arbal');
  return schusswaffe ? false : waffe.isOneHanded;
}

/// Anzeigename der beiden tatsächlich belegten Hände.
String gefechtsHandbelegung(CombatConfig c) {
  final haupt = c.selectedWeaponOrNull;
  if (haupt != null && !gefechtsWaffeEinhaendig(haupt)) {
    return '${haupt.name} · beide Hände';
  }
  return '${haupt?.name ?? 'Leer'} · ${gefechtsNebenhandname(c)}';
}

/// Benennt Waffen, Schilde und Parierwaffen über die vorhandene Zuordnung.
String gefechtsNebenhandname(CombatConfig c) {
  final n = c.offhandAssignment;
  if (n.usesWeapon) return c.weaponSlots[n.weaponIndex].name;
  if (n.usesEquipment) return c.offhandEquipment[n.equipmentIndex].name;
  return 'Leer';
}

/// Prüft Belegung vor der Normalisierung und schreibt nur gegen frische Daten.
CombatConfig mitGefechtsHandbelegung(
  CombatConfig c,
  GefechtsHand hand, {
  MainWeaponSlot? waffe,
  OffhandEquipmentEntry? teil,
  int? index,
}) {
  if (waffe != null && teil != null) throw StateError('Nur ein Teil pro Hand.');
  MainWeaponSlot? frisch;
  if (waffe != null) {
    frisch = c.weaponSlots
        .where(
          (w) => waffe.id.isNotEmpty
              ? w.id == waffe.id
              : stableContentHash(w.toJson()) ==
                    stableContentHash(waffe.toJson()),
        )
        .firstOrNull;
    if (frisch == null) {
      throw StateError('Zielwaffe entfernt; Auswahl erneut bestätigen.');
    }
    _pruefeBekannteFelder(
      frisch.toJson(),
      waffe.toJson(),
      MainWeaponSlot.jsonSchluessel,
    );
  }
  if (teil != null) {
    final aktuell = c.offhandEquipment
        .where(
          (t) => teil.id.isNotEmpty
              ? t.id == teil.id
              : stableContentHash(t.toJson()) ==
                    stableContentHash(teil.toJson()),
        )
        .firstOrNull;
    if (aktuell == null) {
      throw StateError('Nebenhandteil entfernt; Auswahl erneut bestätigen.');
    }
    _pruefeBekannteFelder(
      aktuell.toJson(),
      teil.toJson(),
      OffhandEquipmentEntry.jsonSchluessel,
    );
  }
  final neben = c.offhandAssignment;
  final haupt = c.selectedWeaponOrNull;
  if (hand == GefechtsHand.haupthand) {
    if (teil != null) {
      throw StateError('Schilde und Parierwaffen gehören in die Nebenhand.');
    }
    if (frisch != null &&
        neben.usesWeapon &&
        c.weaponSlots[neben.weaponIndex] == frisch) {
      throw StateError('Diese Waffe liegt bereits in der Nebenhand.');
    }
    if (frisch != null && !gefechtsWaffeEinhaendig(frisch) && !neben.isNone) {
      throw StateError(
        'Zweihändige Waffe benötigt beide Hände; Nebenhand zuerst wegstecken.',
      );
    }
    return mitAktiverWaffe(c, waffe, index: index);
  }
  if (waffe != null || teil != null) {
    if (haupt != null && !gefechtsWaffeEinhaendig(haupt)) {
      throw StateError('Hauptwaffe belegt beide Hände.');
    }
    if (frisch != null && frisch == haupt) {
      throw StateError('Diese Waffe liegt bereits in der Haupthand.');
    }
    if (frisch != null && !gefechtsWaffeEinhaendig(frisch)) {
      throw StateError('Nebenhandwaffe muss einhändig geführt werden.');
    }
  }
  return mitNebenhand(
    c,
    waffe: waffe,
    waffenIndex: index,
    teil: teil,
    teilIndex: index,
  );
}

// Neue unbekannte Felder dürfen eine unveränderte bekannte Auswahl nicht verlieren lassen.
void _pruefeBekannteFelder(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
  Set<String> keys,
) {
  final aktuell = {for (final k in keys) k: a[k]};
  final angezeigt = {for (final k in keys) k: b[k]};
  if (stableContentHash(aktuell) != stableContentHash(angezeigt)) {
    throw StateError(
      'Ausrüstung inzwischen geändert; Auswahl erneut bestätigen.',
    );
  }
}
