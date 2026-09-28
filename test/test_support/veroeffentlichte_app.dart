import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
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
/// nach ihr dazukamen, bleiben damit stehen — fuer die hier geprueften
/// Modelle spielt das keine Rolle.
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
    _behalteIn(kampf['offhandAssignment'], OffhandAssignment.jsonSchluessel);
    _behalteIn(kampf['specialRules'], CombatSpecialRules.jsonSchluessel);
    _behalteIn(kampf['manualMods'], CombatManualMods.jsonSchluessel);
    for (final meister in _maps(kampf['waffenmeisterschaften'])) {
      _behalte(meister, WaffenmeisterConfig.jsonSchluessel);
      for (final bonus in _maps(meister['bonuses'])) {
        _behalte(bonus, WaffenmeisterBonus.jsonSchluessel);
      }
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
  _talenteUndMagie(json);
  _begleiterAbenteuerNotizen(json);
  return json;
}

// Begleiter, Abenteuer, Notizen, Kontakte, Gruppen und Reisebericht.
void _begleiterAbenteuerNotizen(Map<String, dynamic> json) {
  for (final notiz in _maps(json['notes'])) {
    _behalte(notiz, HeroNoteEntry.jsonSchluessel);
  }
  for (final abenteuer in _maps(json['adventures'])) {
    _behalte(abenteuer, HeroAdventureEntry.jsonSchluessel);
    for (final notiz in _maps(abenteuer['notes'])) {
      _behalte(notiz, HeroNoteEntry.jsonSchluessel);
    }
    for (final person in _maps(abenteuer['people'])) {
      _behalte(person, HeroAdventurePersonEntry.jsonSchluessel);
    }
    for (final datum in const <String>[
      'startWorldDate',
      'startAventurianDate',
      'endWorldDate',
      'endAventurianDate',
      'currentAventurianDate',
    ]) {
      _behalteIn(abenteuer[datum], HeroAdventureDateValue.jsonSchluessel);
    }
    for (final se in _maps(abenteuer['seRewards'])) {
      _behalte(se, HeroAdventureSeReward.jsonSchluessel);
    }
    for (final beute in _maps(abenteuer['lootRewards'])) {
      _behalte(beute, HeroAdventureLootEntry.jsonSchluessel);
      for (final modifikator in _maps(beute['modifiers'])) {
        _behalte(modifikator, InventoryItemModifier.jsonSchluessel);
      }
    }
  }
  for (final kontakt in _maps(json['connections'])) {
    _behalte(kontakt, HeroConnectionEntry.jsonSchluessel);
  }
  for (final begleiter in _maps(json['companions'])) {
    _behalte(begleiter, HeroCompanion.jsonSchluessel);
    for (final tempo in _maps(begleiter['geschwindigkeiten'])) {
      _behalte(tempo, HeroCompanionSpeed.jsonSchluessel);
    }
    for (final angriff in _maps(begleiter['angriffe'])) {
      _behalte(angriff, HeroCompanionAttack.jsonSchluessel);
    }
    for (final sf in _maps(begleiter['sonderfertigkeiten'])) {
      _behalte(sf, HeroCompanionSonderfertigkeit.jsonSchluessel);
    }
    for (final stueck in _maps(begleiter['ruestungsTeile'])) {
      _behalteOhneId(stueck, ArmorPiece.jsonSchluessel);
    }
    for (final kategorie in _maps(begleiter['ritualCategories'])) {
      _behalte(kategorie, HeroRitualCategory.jsonSchluessel);
      _behalteIn(kategorie['ownKnowledge'], HeroRitualKnowledge.jsonSchluessel);
    }
  }
  for (final gruppe in _maps(json['gruppen'])) {
    _behalte(gruppe, HeroGruppenMitgliedschaft.jsonSchluessel);
  }
  final reise = json['reisebericht'];
  if (reise is Map<String, dynamic>) {
    _behalte(reise, HeroReisebericht.jsonSchluessel);
    for (final liste
        in (reise['openEntries'] as Map?)?.values ?? const <Object?>[]) {
      for (final eintrag in _maps(liste)) {
        _behalte(eintrag, ReiseberichtOpenItem.jsonSchluessel);
      }
    }
  }
}

// Talente, Zauber, Rituale, Sprachen und benannte Modifikatoren.
void _talenteUndMagie(Map<String, dynamic> json) {
  for (final talent in _werte(json['talents'])) {
    _behalte(talent, HeroTalentEntry.jsonSchluessel);
    for (final mod in _maps(talent['talentModifiers'])) {
      _behalte(mod, HeroTalentModifier.jsonSchluessel);
    }
  }
  for (final meta in _maps(json['metaTalents'])) {
    _behalte(meta, HeroMetaTalent.jsonSchluessel);
  }
  for (final sf in _maps(json['talentSpecialAbilities'])) {
    _behalte(sf, TalentSpecialAbility.jsonSchluessel);
  }
  for (final zauber in _werte(json['spells'])) {
    _behalte(zauber, HeroSpellEntry.jsonSchluessel);
    _behalteIn(zauber['textOverrides'], HeroSpellTextOverrides.jsonSchluessel);
  }
  for (final kategorie in _maps(json['ritualCategories'])) {
    _behalte(kategorie, HeroRitualCategory.jsonSchluessel);
    _behalteIn(kategorie['ownKnowledge'], HeroRitualKnowledge.jsonSchluessel);
    for (final feld in _maps(kategorie['additionalFieldDefs'])) {
      _behalte(feld, HeroRitualFieldDef.jsonSchluessel);
    }
    for (final ritual in _maps(kategorie['rituals'])) {
      _behalte(ritual, HeroRitualEntry.jsonSchluessel);
      for (final wert in _maps(ritual['additionalFieldValues'])) {
        _behalte(wert, HeroRitualFieldValue.jsonSchluessel);
      }
    }
  }
  for (final sf in _maps(json['magicSpecialAbilities'])) {
    _behalte(sf, MagicSpecialAbility.jsonSchluessel);
  }
  for (final sprache in _werte(json['sprachen'])) {
    _behalte(sprache, HeroLanguageEntry.jsonSchluessel);
  }
  for (final schrift in _werte(json['schriften'])) {
    _behalte(schrift, HeroScriptEntry.jsonSchluessel);
  }
  for (final schluessel in const <String>[
    'statModifiers',
    'attributeModifiers',
  ]) {
    for (final liste
        in (json[schluessel] as Map?)?.values ?? const <Object?>[]) {
      for (final mod in _maps(liste)) {
        _behalte(mod, HeroTalentModifier.jsonSchluessel);
      }
    }
  }
}

// Alle Map-Werte einer JSON-Map (etwa `talents` nach ID).
Iterable<Map<String, dynamic>> _werte(Object? map) {
  if (map is! Map) return const <Map<String, dynamic>>[];
  return map.values.whereType<Map<String, dynamic>>();
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

// Wie [_behalte] fuer einen JSON-Wert, der eine Map sein kann.
void _behalteIn(Object? json, Set<String> bekannt) {
  if (json is Map<String, dynamic>) _behalte(json, bekannt);
}

// Entfernt alle Schluessel ausserhalb von [bekannt].
void _behalte(Map<String, dynamic> json, Set<String> bekannt) {
  json.removeWhere((key, _) => !bekannt.contains(key));
}

// Wie [_behalte], zusaetzlich ohne Slot-ID.
void _behalteOhneId(Map<String, dynamic> json, Set<String> bekannt) {
  _behalte(json, bekannt.difference(const {'id'}));
}
