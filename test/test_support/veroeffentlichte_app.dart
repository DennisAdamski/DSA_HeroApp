import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Nachbildung der bereits veroeffentlichten App-Version (`main`, Stand
/// `7f0f830`) fuer Tests zum Mischbetrieb.
///
/// Sie laesst sich nicht mehr aendern; das Datenformat dieser Version muss
/// deshalb so gewaehlt sein, dass sie damit vertraeglich arbeitet.

/// Was die veroeffentlichte App von [heldJson] uebrig laesst, wenn sie den
/// Helden laedt und wieder speichert.
///
/// Sie kennt weder Slot-IDs noch `slotRef` und bewahrt keine unbekannten
/// Felder, weder oben noch verschachtelt. Nachgebildet mit den
/// Schluesselsaetzen dieser Version ohne `id` und `slotRef`; Felder, die erst
/// nach ihr dazukamen, bleiben damit stehen — fuer die Ausruestung spielt
/// das keine Rolle.
Map<String, dynamic> wieVeroeffentlichteApp(Map<String, dynamic> heldJson) {
  final json = jsonDecode(jsonEncode(heldJson)) as Map<String, dynamic>;
  _behalte(json, HeroSheet.jsonSchluessel);
  final kampf = json['combatConfig'] as Map<String, dynamic>?;
  if (kampf != null) {
    _behalte(kampf, CombatConfig.jsonSchluessel);
    final waffen = <Object?>[
      kampf['mainWeapon'],
      ...(kampf['weapons'] as List? ?? const <Object?>[]),
    ];
    for (final waffe in waffen.whereType<Map<String, dynamic>>()) {
      _behalteOhneId(waffe, MainWeaponSlot.jsonSchluessel);
      final profil = waffe['rangedProfile'] as Map<String, dynamic>?;
      if (profil == null) continue;
      _behalte(profil, RangedWeaponProfile.jsonSchluessel);
      for (final stufe in _maps(profil['distanceBands'])) {
        _behalte(stufe, RangedDistanceBand.jsonSchluessel);
      }
      for (final geschoss in _maps(profil['projectiles'])) {
        _behalteOhneId(geschoss, RangedProjectile.jsonSchluessel);
      }
    }
    final ruestung = kampf['armor'] as Map<String, dynamic>?;
    if (ruestung != null) {
      _behalte(ruestung, ArmorConfig.jsonSchluessel);
      for (final stueck in _maps(ruestung['pieces'])) {
        _behalteOhneId(stueck, ArmorPiece.jsonSchluessel);
      }
    }
    for (final teil in _maps(kampf['offhandEquipment'])) {
      _behalteOhneId(teil, OffhandEquipmentEntry.jsonSchluessel);
    }
  }
  for (final eintrag in _maps(json['inventoryEntries'])) {
    _behalte(
      eintrag,
      HeroInventoryEntry.jsonSchluessel.difference(const {'slotRef'}),
    );
    for (final modifikator in _maps(eintrag['modifiers'])) {
      _behalte(modifikator, InventoryItemModifier.jsonSchluessel);
    }
  }
  return json;
}

/// Namenszuordnung aus dem Abgleich der veroeffentlichten App, auf JSON.
///
/// Liefert je erwartetem Slot — Waffen samt Geschossen, Ruestung,
/// Nebenhand, in dieser Reihenfolge — den Index des Inventareintrags, den
/// sie ihm zuordnet, oder `null`. Ein Slot ohne Treffer bekaeme dort einen
/// leeren neuen Eintrag, ein Eintrag ohne Slot fiele samt Daten weg.
List<int?> zuordnungWieVeroeffentlichteApp(Map<String, dynamic> heldJson) {
  final eintraege = _maps(heldJson['inventoryEntries']).toList();
  final offen = <int>[
    for (var i = 0; i < eintraege.length; i++)
      if (eintraege[i]['sourceRef'] != null &&
          _verknuepfteQuellen.contains(eintraege[i]['source']))
        i,
  ];
  return <int?>[
    for (final ref in _erwarteteNamensverweise(heldJson))
      _nimmErsten(offen, (index) => eintraege[index]['sourceRef'] == ref),
  ];
}

// Quellen, die die veroeffentlichte App als verknuepft behandelt.
const Set<String> _verknuepfteQuellen = <String>{
  'waffe',
  'geschoss',
  'ruestung',
  'nebenhand',
};

// Erwartete Namensverweise in Slot-Reihenfolge, wie `buildExpectedLinked-
// Entries` der veroeffentlichten App sie bildet.
List<String> _erwarteteNamensverweise(Map<String, dynamic> heldJson) {
  final kampf = heldJson['combatConfig'] as Map<String, dynamic>;
  final waffen = _maps(kampf['weapons']).toList();
  if (waffen.isEmpty) {
    waffen.add(kampf['mainWeapon'] as Map<String, dynamic>);
  }
  final refs = <String>[];
  for (final waffe in waffen) {
    final name = '${waffe['name'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    refs.add('w:$name');
    if (waffe['combatType'] != 'ranged') continue;
    final profil = waffe['rangedProfile'] as Map<String, dynamic>;
    for (final geschoss in _maps(profil['projectiles'])) {
      final geschossName = '${geschoss['name'] ?? ''}'.trim();
      if (geschossName.isNotEmpty) refs.add('w:$name|p:$geschossName');
    }
  }
  final ruestung = kampf['armor'] as Map<String, dynamic>;
  for (final stueck in _maps(ruestung['pieces'])) {
    final name = '${stueck['name'] ?? ''}'.trim();
    if (name.isNotEmpty) refs.add('a:$name');
  }
  for (final teil in _maps(kampf['offhandEquipment'])) {
    final name = '${teil['name'] ?? ''}'.trim();
    if (name.isNotEmpty) refs.add('oh:$name');
  }
  return refs;
}

// Entnimmt den ersten Index aus [offen], der [passt].
int? _nimmErsten(List<int> offen, bool Function(int index) passt) {
  final position = offen.indexWhere(passt);
  if (position < 0) return null;
  return offen.removeAt(position);
}

// Alle Maps einer JSON-Liste.
Iterable<Map<String, dynamic>> _maps(Object? liste) {
  if (liste is! List) return const <Map<String, dynamic>>[];
  return liste.whereType<Map<String, dynamic>>();
}

// Entfernt alle Schluessel ausserhalb von [bekannt].
void _behalte(Map<String, dynamic> json, Set<String> bekannt) {
  json.removeWhere((key, _) => !bekannt.contains(key));
}

// Wie [_behalte], zusaetzlich ohne Slot-ID.
void _behalteOhneId(Map<String, dynamic> json, Set<String> bekannt) {
  _behalte(json, bekannt.difference(const {'id'}));
}
