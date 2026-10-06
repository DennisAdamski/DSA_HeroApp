import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_se_pools.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Nachbildung aelterer App-Versionen fuer Tests zum Mischbetrieb.
///
/// Hauptsaechlich `main` im Stand `7f0f830` (PR #195, 27.09.2026), der
/// letzte Stand ohne Schutz unbekannter Felder. Seit PR #199–#201
/// (28./29.09.2026) bewahrt die Web-Produktion unbekannte Felder, seit PR #221
/// (06.10.2026) kennt sie `instanzId` und `menge`. Laut Nutzer laeuft seit dem
/// 06.10.2026 keine aeltere Version mehr; die Nachbildungen sichern, dass
/// zurueckgeschriebene Altdaten trotzdem verlustfrei gelesen werden.

/// Was die veroeffentlichte App von [heldJson] uebrig laesst, wenn sie den
/// Helden laedt und wieder speichert.
///
/// Sie kennt weder Slot-IDs noch `slotRef` noch strukturierte Vor- und
/// Nachteile (`vorteilEintraege`/`nachteilEintraege`) und bewahrt keine unbekannten
/// Felder, weder oben noch verschachtelt. Nachgebildet mit den
/// Schluesselsaetzen dieser Version ohne `id` und `slotRef`; Felder, die erst
/// nach ihr dazukamen, bleiben damit stehen — fuer die hier geprueften
/// Modelle spielt das keine Rolle.
Map<String, dynamic> wieVeroeffentlichteApp(Map<String, dynamic> heldJson) {
  final json = jsonDecode(jsonEncode(heldJson)) as Map<String, dynamic>;
  // Strukturierte Vor-/Nachteile (ARCH-02) kennt sie nicht; sie bearbeitet
  // nur `vorteileText`/`nachteileText`.
  _behalte(
    json,
    HeroSheet.jsonSchluessel.difference(const {
      'vorteilEintraege',
      'nachteilEintraege',
    }),
  );
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
  _grundwerteAvatarVerlauf(json);
  _aufzaehlungen(json);
  return json;
}

// Unbekannte Aufzaehlungswerte kennt sie nicht; sie schreibt den Ersatz.
void _aufzaehlungen(Map<String, dynamic> json) {
  for (final eintrag in _maps(json['inventoryEntries'])) {
    _ersatz(eintrag, 'itemType', _namen(InventoryItemType.values), 'sonstiges');
    _ersatz(eintrag, 'source', _namen(InventoryItemSource.values), 'manuell');
    _ersatz(eintrag, 'traegerTyp', _namen(InventoryTraeger.values), 'held');
    for (final modifikator in _maps(eintrag['modifiers'])) {
      _ersatz(
        modifikator,
        'kind',
        _namen(InventoryModifierKind.values),
        'stat',
      );
    }
  }
  final kampf = json['combatConfig'];
  if (kampf is Map<String, dynamic>) {
    for (final waffe in <Object?>[
      kampf['mainWeapon'],
      ...(kampf['weapons'] as List? ?? const <Object?>[]),
    ].whereType<Map<String, dynamic>>()) {
      _ersatz(waffe, 'combatType', const <String>{
        'melee',
        'ranged',
        'nahkampf',
        'fernkampf',
      }, 'melee');
    }
    for (final teil in _maps(kampf['offhandEquipment'])) {
      _ersatz(teil, 'type', const <String>{
        'shield',
        'parryWeapon',
      }, 'parryWeapon');
      _ersatz(teil, 'shieldSize', _namen(ShieldSize.values), 'small');
    }
    for (final meister in _maps(kampf['waffenmeisterschaften'])) {
      for (final bonus in _maps(meister['bonuses'])) {
        _ersatz(
          bonus,
          'type',
          _namen(WaffenmeisterBonusType.values),
          'customAdvantage',
        );
      }
    }
  }
  for (final kategorie in <Map<String, dynamic>>[
    ..._maps(json['ritualCategories']),
    for (final begleiter in _maps(json['companions']))
      ..._maps(begleiter['ritualCategories']),
  ]) {
    _ersatz(kategorie, 'knowledgeMode', const <String>{
      'ownKnowledge',
      'derivedTalents',
    }, 'ownKnowledge');
    for (final feld in _maps(kategorie['additionalFieldDefs'])) {
      _ersatz(feld, 'type', const <String>{'text', 'threeAttributes'}, 'text');
    }
  }
  for (final begleiter in _maps(json['companions'])) {
    _ersatz(
      begleiter,
      'typ',
      _namen(BegleiterTyp.values),
      'sonstigerBegleiter',
    );
  }
  for (final abenteuer in _maps(json['adventures'])) {
    _ersatz(abenteuer, 'status', const <String>{
      'current',
      'completed',
    }, 'current');
    for (final se in _maps(abenteuer['seRewards'])) {
      _ersatz(se, 'targetType', const <String>{
        'talent',
        'grundwert',
        'eigenschaft',
      }, 'talent');
    }
    for (final beute in _maps(abenteuer['lootRewards'])) {
      _ersatz(beute, 'itemType', _namen(InventoryItemType.values), 'sonstiges');
    }
  }
  final geburtsdatum = json['geburtsdatum'];
  if (geburtsdatum is Map<String, dynamic>) {
    _ersatz(geburtsdatum, 'month', <String>{
      '',
      for (final monat in aventurianMonths) monat.value,
    }, '');
  }
}

// Namen aller Werte einer Aufzaehlung.
Set<String> _namen(List<Enum> werte) {
  return <String>{for (final wert in werte) wert.name};
}

// Setzt [schluessel] auf [ersatz], wenn der Wert nicht in [bekannt] steht.
void _ersatz(
  Map<String, dynamic> json,
  String schluessel,
  Set<String> bekannt,
  String ersatz,
) {
  final wert = json[schluessel];
  if (wert != null && !bekannt.contains(wert)) {
    json[schluessel] = ersatz;
  }
}

// Eigenschaften, Grundwerte, SE-Pools, Ressourcenschalter, Bilder, Verlauf.
void _grundwerteAvatarVerlauf(Map<String, dynamic> json) {
  for (final schluessel in const <String>[
    'attributes',
    'rawStartAttributes',
    'startAttributes',
    'epicAttributeMaxBonus',
    'epicMainAttributes',
  ]) {
    _behalteIn(json[schluessel], Attributes.jsonSchluessel);
  }
  _behalteIn(json['persistentMods'], StatModifiers.jsonSchluessel);
  _behalteIn(json['bought'], BoughtStats.jsonSchluessel);
  _behalteIn(json['attributeSePool'], HeroAttributeSePool.jsonSchluessel);
  _behalteIn(json['statSePool'], HeroStatSePool.jsonSchluessel);
  _behalteIn(
    json['resourceActivationConfig'],
    HeroResourceActivationConfig.jsonSchluessel,
  );
  _behalteIn(json['geburtsdatum'], AventurianDate.jsonSchluessel);
  for (final bild in _maps(json['avatarGallery'])) {
    _behalte(bild, AvatarGalleryEntry.jsonSchluessel);
    final gesicht = bild['gesicht'];
    if (gesicht is Map<String, dynamic>) {
      _behalte(gesicht, AvatarGesichtsbefund.jsonSchluessel);
      _behalteIn(gesicht['g'], AvatarGesichtsrahmen.jsonSchluessel);
    }
  }
  _behalteIn(json['avatarSnapshot'], AvatarSnapshot.jsonSchluessel);
  for (final eintrag in _maps(json['advancementHistory'])) {
    _behalte(eintrag, HeroAdvancementEntry.jsonSchluessel);
  }
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

/// Was die veroeffentlichte App von [zustandJson] uebrig laesst, wenn sie den
/// Laufzeitzustand laedt und wieder speichert: alles Unbekannte faellt weg.
Map<String, dynamic> zustandWieVeroeffentlichteApp(
  Map<String, dynamic> zustandJson,
) {
  final json = jsonDecode(jsonEncode(zustandJson)) as Map<String, dynamic>;
  _behalte(json, HeroState.jsonSchluessel);
  _behalteIn(json['tempMods'], StatModifiers.jsonSchluessel);
  _behalteIn(json['tempAttributeMods'], AttributeModifiers.jsonSchluessel);
  final effekte = json['activeSpellEffects'];
  if (effekte is Map<String, dynamic>) {
    _behalte(effekte, ActiveSpellEffectsState.jsonSchluessel);
    for (final detail in _werte(effekte['effectDetails'])) {
      _behalte(detail, ActiveSpellEffectDetail.jsonSchluessel);
      final dauer = detail['duration'];
      if (dauer is Map<String, dynamic>) {
        _behalte(dauer, SpellDuration.jsonSchluessel);
        _ersatz(dauer, 'unit', _namen(SpellDurationUnit.values), 'kampfrunden');
      }
    }
  }
  final wunden = json['wpiZustand'];
  if (wunden is Map<String, dynamic>) {
    _behalte(wunden, WundZustand.jsonSchluessel);
    for (final zonen in const <String>[
      'wundenProZone',
      'unterdrueckteWundenProZone',
    ]) {
      _behalteIn(wunden[zonen], _namen(WundZone.values));
    }
  }
  for (final eintrag in _maps(json['diceLog'])) {
    _behalte(eintrag, DiceLogEntry.jsonSchluessel);
    _ersatz(eintrag, 'type', _namen(ProbeType.values), 'attribute');
    _ersatz(
      eintrag,
      'automaticOutcome',
      _namen(AutomaticOutcome.values),
      'none',
    );
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

/// Was eine Version vom 29.09. bis 05.10.2026 aus [heldJson] macht, wenn der
/// Nutzer dort die Anzahl des Inventareintrags [index] auf [anzahl] setzt.
///
/// Sie bewahrt `menge` als unbekanntes Feld, kennt es aber nicht und
/// schreibt nur `anzahl` (ARCH-03). Danach passen beide nicht mehr zusammen.
Map<String, dynamic> anzahlWieVersionOhneMenge(
  Map<String, dynamic> heldJson,
  int index,
  String anzahl,
) {
  final json = jsonDecode(jsonEncode(heldJson)) as Map<String, dynamic>;
  final eintraege = json['inventoryEntries'] as List;
  (eintraege[index] as Map<String, dynamic>)['anzahl'] = anzahl;
  return json;
}
