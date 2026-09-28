import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';

/// Ein Held im heutigen Format und derselbe Held, wie ihn eine gedachte
/// neuere App-Version mit zusaetzlichen verschachtelten Feldern schreibt.
///
/// [basis] ist die Fixture samt Beispielinhalten an den Stellen, die sie
/// selbst nicht belegt (siehe [mitZukunftsfeldern]); [json] traegt zusaetzlich
/// an jeder verschachtelten Ebene ein Feld `zukunftsfeld`. [pfade] nennt genau
/// diese Stellen im Format von `jsonUnterschiede`.
typedef Zukunftsheld = ({
  Map<String, dynamic> basis,
  Map<String, dynamic> json,
  List<String> pfade,
});

/// Name des Feldes, das die gedachte neuere Version schreibt.
const String zukunftsfeld = 'zukunftsfeld';

/// Baut aus dem Helden-JSON [heldJson] einen [Zukunftsheld].
///
/// Erwartet den Aufbau von f01: eine nicht gewaehlte Fernkampfwaffe an
/// Position 1 mit Geschoss, ein Ruestungsstueck, ein Nebenhand-Teil, einen
/// manuellen und einen mit dieser Waffe verknuepften Inventareintrag. Die
/// gewaehlte Waffe bleibt unberuehrt, weil `mainWeapon` nur sie spiegelt.
///
/// Was f01 nicht belegt, ergaenzt die Basis im heutigen Format: einen
/// Inventar-Modifikator am manuellen Eintrag, eine Waffenmeisterschaft mit
/// Bonus, einen Talentmodifikator, ein Meta-Talent, einen Zauber mit
/// Text-Overrides, eine Ritualkategorie mit Zusatzfeld und Ritual, eine
/// magische Sonderfertigkeit, Personen, Notiz, SE und Beute im laufenden
/// Abenteuer, einen Kontakt, einen Begleiter mit Angriff, Bewegung, SF,
/// Ruestung und Ritualkategorie, eine Gruppe und einen offenen
/// Reiseberichtseintrag.
Zukunftsheld mitZukunftsfeldern(Map<String, dynamic> heldJson) {
  final basis = _tiefeKopie(heldJson);
  final pfade = <String>[
    ..._ausruestung(basis),
    ..._kampfEinstellungen(basis),
    ..._talenteUndMagie(basis),
    ..._begleiterAbenteuerNotizen(basis),
  ];
  return _mitFeldern(basis, pfade);
}

/// ID des Zaubers, den die Basis ergaenzt.
const String zukunftsZauber = 'spell_armatrutz';

/// Talent, dessen Eintrag die Basis um einen Modifikator ergaenzt.
const String _zukunftsTalent = 'tal_klettern';

/// Pfade der zehn Ausruestungsmodelle (Teilstand ARCH-03 vom 28.09.2026).
List<String> _ausruestung(Map<String, dynamic> basis) {
  final eintraege = basis['inventoryEntries'] as List<dynamic>;
  final manuell = eintraege.indexWhere(
    (entry) => (entry as Map)['source'] == 'manuell',
  );
  _pruefe(manuell >= 0, 'manueller Inventareintrag');
  (eintraege[manuell] as Map)['modifiers'] = <Object?>[
    <String, dynamic>{
      'kind': 'stat',
      'targetId': 'gs',
      'wert': 1,
      'beschreibung': 'Leichtes Gepäck',
    },
  ];

  final kampf = basis['combatConfig'] as Map<String, dynamic>;
  _pruefe(kampf['selectedWeaponIndex'] != 1, 'Waffe 1 nicht gewählt');
  final waffen = kampf['weapons'] as List<dynamic>;
  _pruefe(waffen.length > 1, 'zweite Waffe');
  final waffe = waffen[1] as Map<String, dynamic>;
  final profil = waffe['rangedProfile'] as Map<String, dynamic>;
  _pruefe((profil['projectiles'] as List).isNotEmpty, 'Geschoss an Waffe 1');
  final ruestung = kampf['armor'] as Map<String, dynamic>;
  _pruefe((ruestung['pieces'] as List).isNotEmpty, 'Rüstungsstück');
  _pruefe((kampf['offhandEquipment'] as List).isNotEmpty, 'Nebenhand-Teil');
  final waffenVerweis = 'w:${waffe['name']}';
  final verknuepft = eintraege.indexWhere(
    (entry) => (entry as Map)['sourceRef'] == waffenVerweis,
  );
  _pruefe(verknuepft >= 0, 'Inventareintrag zu Waffe 1');

  return <String>[
    'combatConfig',
    'combatConfig/weapons/1',
    'combatConfig/weapons/1/rangedProfile',
    'combatConfig/weapons/1/rangedProfile/distanceBands/0',
    'combatConfig/weapons/1/rangedProfile/projectiles/0',
    'combatConfig/armor',
    'combatConfig/armor/pieces/0',
    'combatConfig/offhandEquipment/0',
    'inventoryEntries/$manuell',
    'inventoryEntries/$manuell/modifiers/0',
    'inventoryEntries/$verknuepft',
  ];
}

/// Pfade der Kampfeinstellungen neben der Ausruestung.
List<String> _kampfEinstellungen(Map<String, dynamic> basis) {
  final kampf = basis['combatConfig'] as Map<String, dynamic>;
  _pruefe(kampf['offhandAssignment'] is Map, 'Nebenhand-Auswahl');
  _pruefe(kampf['specialRules'] is Map, 'Kampf-Sonderfertigkeiten');
  _pruefe(kampf['manualMods'] is Map, 'manuelle Kampfmodifikatoren');
  _pruefe(
    (kampf['waffenmeisterschaften'] as List).isEmpty,
    'keine Waffenmeisterschaft',
  );
  kampf['waffenmeisterschaften'] = <Object?>[
    const WaffenmeisterConfig(
      talentId: 'tal_schwerter',
      weaponType: 'Langschwert',
      bonuses: <WaffenmeisterBonus>[
        WaffenmeisterBonus(type: WaffenmeisterBonusType.iniBonus, value: 1),
      ],
    ).toJson(),
  ];
  return const <String>[
    'combatConfig/offhandAssignment',
    'combatConfig/specialRules',
    'combatConfig/manualMods',
    'combatConfig/waffenmeisterschaften/0',
    'combatConfig/waffenmeisterschaften/0/bonuses/0',
  ];
}

/// Bearbeitet in [held] je Modell an einem Zukunftspfad ein bekanntes Feld,
/// wie es die Editoren tun: per `copyWith` auf der vorhandenen Instanz.
///
/// Ergaenzt die Ausruestungsaenderungen der Ablauftests um die uebrigen
/// Modelle. Die Aenderungen sind so gewaehlt, dass kein Regelabgleich sie
/// wieder zuruecknimmt.
HeroSheet bearbeiteVerschachtelteModelle(HeroSheet held) {
  final kampf = held.combatConfig;
  final meister = kampf.waffenmeisterschaften.single;
  final talent = held.talents[_zukunftsTalent]!;
  final kategorie = held.ritualCategories.single;
  final ritual = kategorie.rituals.single;
  final sprache = held.sprachen.entries.first;
  final schrift = held.schriften.entries.first;
  final basiswert = held.statModifiers.entries.first;
  final eigenschaft = held.attributeModifiers.entries.first;
  final abenteuer = held.adventures.first;
  final begleiter = held.companions.single;
  final offen = held.reisebericht.openEntries[_zukunftsReise]!.single;
  return held.copyWith(
    notes: <HeroNoteEntry>[
      held.notes.first.copyWith(description: 'Schuldet 10 Dukaten.'),
      ...held.notes.skip(1),
    ],
    adventures: <HeroAdventureEntry>[
      abenteuer.copyWith(
        summary: 'In Gareth angekommen.',
        notes: <HeroNoteEntry>[
          abenteuer.notes.single.copyWith(title: 'Fährte'),
        ],
        people: <HeroAdventurePersonEntry>[
          abenteuer.people.single.copyWith(description: 'Händler'),
        ],
        currentAventurianDate: abenteuer.currentAventurianDate.copyWith(
          day: '19',
        ),
        seRewards: <HeroAdventureSeReward>[
          abenteuer.seRewards.single.copyWith(count: 2),
        ],
        lootRewards: <HeroAdventureLootEntry>[
          abenteuer.lootRewards.single.copyWith(quantity: '2'),
        ],
      ),
      ...held.adventures.skip(1),
    ],
    connections: <HeroConnectionEntry>[
      held.connections.single.copyWith(ort: 'Punin'),
    ],
    companions: <HeroCompanion>[
      begleiter.copyWith(
        name: 'Krähe',
        geschwindigkeiten: <HeroCompanionSpeed>[
          begleiter.geschwindigkeiten.single.copyWith(wert: 14),
        ],
        angriffe: <HeroCompanionAttack>[
          begleiter.angriffe.single.copyWith(at: 11),
        ],
        sonderfertigkeiten: <HeroCompanionSonderfertigkeit>[
          begleiter.sonderfertigkeiten.single.copyWith(beschreibung: 'Neu'),
        ],
      ),
    ],
    gruppen: <HeroGruppenMitgliedschaft>[
      held.gruppen.single.copyWith(gruppenName: 'Sichelträger'),
    ],
    reisebericht: held.reisebericht.copyWith(
      openEntries: <String, List<ReiseberichtOpenItem>>{
        _zukunftsReise: <ReiseberichtOpenItem>[offen.copyWith(ap: 15)],
      },
    ),
    talents: <String, HeroTalentEntry>{
      ...held.talents,
      _zukunftsTalent: talent.copyWith(
        talentValue: (talent.talentValue ?? 0) + 1,
        talentModifiers: <HeroTalentModifier>[
          talent.talentModifiers.single.copyWith(modifier: 2),
        ],
      ),
    },
    metaTalents: <HeroMetaTalent>[
      held.metaTalents.single.copyWith(name: 'Kräuter suchen'),
    ],
    talentSpecialAbilities: <TalentSpecialAbility>[
      held.talentSpecialAbilities.first.copyWith(note: 'Garetien'),
      ...held.talentSpecialAbilities.skip(1),
    ],
    spells: <String, HeroSpellEntry>{
      ...held.spells,
      zukunftsZauber: held.spells[zukunftsZauber]!.copyWith(modifier: 1),
    },
    ritualCategories: <HeroRitualCategory>[
      kategorie.copyWith(
        ownKnowledge: kategorie.ownKnowledge!.copyWith(value: 6),
        additionalFieldDefs: <HeroRitualFieldDef>[
          kategorie.additionalFieldDefs.single.copyWith(label: 'Probe (KO)'),
        ],
        rituals: <HeroRitualEntry>[
          ritual.copyWith(
            kosten: '8 AsP',
            additionalFieldValues: <HeroRitualFieldValue>[
              ritual.additionalFieldValues.single.copyWith(
                textValue: 'MU/KO/KO',
              ),
            ],
          ),
        ],
      ),
    ],
    magicSpecialAbilities: <MagicSpecialAbility>[
      held.magicSpecialAbilities.single.copyWith(beschreibung: 'Neu'),
    ],
    sprachen: <String, HeroLanguageEntry>{
      ...held.sprachen,
      sprache.key: sprache.value.copyWith(modifier: 1),
    },
    schriften: <String, HeroScriptEntry>{
      ...held.schriften,
      schrift.key: schrift.value.copyWith(modifier: 1),
    },
    statModifiers: <String, List<HeroTalentModifier>>{
      ...held.statModifiers,
      basiswert.key: <HeroTalentModifier>[
        basiswert.value.first.copyWith(
          modifier: basiswert.value.first.modifier + 1,
        ),
        ...basiswert.value.skip(1),
      ],
    },
    attributeModifiers: <String, List<HeroTalentModifier>>{
      ...held.attributeModifiers,
      eigenschaft.key: <HeroTalentModifier>[
        eigenschaft.value.first.copyWith(
          modifier: eigenschaft.value.first.modifier + 1,
        ),
        ...eigenschaft.value.skip(1),
      ],
    },
    combatConfig: kampf.copyWith(
      offhandAssignment: kampf.offhandAssignment.copyWith(
        weaponIndex: -1,
        equipmentIndex: 0,
      ),
      specialRules: kampf.specialRules.copyWith(flink: true),
      manualMods: kampf.manualMods.copyWith(iniWurf: 4),
      waffenmeisterschaften: <WaffenmeisterConfig>[
        meister.copyWith(
          styleName: 'Garether Schule',
          bonuses: <WaffenmeisterBonus>[
            meister.bonuses.single.copyWith(value: 2),
          ],
        ),
      ],
    ),
  );
}

/// Pfade der Talente, Zauber, Rituale, Sprachen und benannten Modifikatoren.
List<String> _talenteUndMagie(Map<String, dynamic> basis) {
  final talente = basis['talents'] as Map<String, dynamic>;
  _pruefe(talente.containsKey(_zukunftsTalent), 'Talent $_zukunftsTalent');
  talente[_zukunftsTalent] =
      HeroTalentEntry.fromJson(
            (talente[_zukunftsTalent] as Map).cast<String, dynamic>(),
          )
          .copyWith(
            talentModifiers: <HeroTalentModifier>[
              HeroTalentModifier(modifier: 1, description: 'Kletterhaken'),
            ],
          )
          .toJson();
  _pruefe((basis['metaTalents'] as List).isEmpty, 'keine Meta-Talente');
  basis['metaTalents'] = <Object?>[
    const HeroMetaTalent(
      id: 'meta_kraeutersuchen',
      name: 'Kräutersuchen',
      componentTalentIds: <String>[_zukunftsTalent],
      attributes: <String>['MU', 'IN', 'FF'],
    ).toJson(),
  ];
  _pruefe(
    (basis['talentSpecialAbilities'] as List).isNotEmpty,
    'Talent-Sonderfertigkeit',
  );
  _pruefe((basis['spells'] as Map).isEmpty, 'keine Zauber');
  basis['spells'] = <String, dynamic>{
    zukunftsZauber: const HeroSpellEntry(
      spellValue: 4,
      textOverrides: HeroSpellTextOverrides(wirkung: 'Eigene Wirkung'),
    ).toJson(),
  };
  _pruefe((basis['ritualCategories'] as List).isEmpty, 'keine Rituale');
  basis['ritualCategories'] = <Object?>[
    const HeroRitualCategory(
      id: 'ritcat-zukunft',
      name: 'Geodische Rituale',
      knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
      ownKnowledge: HeroRitualKnowledge(name: 'Geodische Rituale', value: 5),
      additionalFieldDefs: <HeroRitualFieldDef>[
        HeroRitualFieldDef(
          id: 'probe',
          label: 'Probe',
          type: HeroRitualFieldType.text,
        ),
      ],
      rituals: <HeroRitualEntry>[
        HeroRitualEntry(
          name: 'Kraft des Erzes',
          wirkung: 'Erdkraft bündeln',
          kosten: '7 AsP',
          additionalFieldValues: <HeroRitualFieldValue>[
            HeroRitualFieldValue(fieldDefId: 'probe', textValue: 'MU/IN/KO'),
          ],
        ),
      ],
    ).toJson(),
  ];
  _pruefe((basis['magicSpecialAbilities'] as List).isEmpty, 'keine Magie-SF');
  basis['magicSpecialAbilities'] = <Object?>[
    const MagicSpecialAbility(name: 'Gefäß der Sterne').toJson(),
  ];
  final sprache = (basis['sprachen'] as Map).keys.first;
  final schrift = (basis['schriften'] as Map).keys.first;
  final basiswert = (basis['statModifiers'] as Map).keys.first;
  final eigenschaft = (basis['attributeModifiers'] as Map).keys.first;
  return <String>[
    'talents/$_zukunftsTalent',
    'talents/$_zukunftsTalent/talentModifiers/0',
    'metaTalents/0',
    'talentSpecialAbilities/0',
    'spells/$zukunftsZauber',
    'spells/$zukunftsZauber/textOverrides',
    'ritualCategories/0',
    'ritualCategories/0/ownKnowledge',
    'ritualCategories/0/additionalFieldDefs/0',
    'ritualCategories/0/rituals/0',
    'ritualCategories/0/rituals/0/additionalFieldValues/0',
    'magicSpecialAbilities/0',
    'sprachen/$sprache',
    'schriften/$schrift',
    'statModifiers/$basiswert/0',
    'attributeModifiers/$eigenschaft/0',
  ];
}

/// Schluessel des offenen Reiseberichtseintrags, den die Basis ergaenzt.
const String _zukunftsReise = 'rb_kulturen';

/// Pfade von Begleitern, Abenteuern, Notizen, Kontakten, Gruppen und
/// Reisebericht.
List<String> _begleiterAbenteuerNotizen(Map<String, dynamic> basis) {
  _pruefe((basis['notes'] as List).isNotEmpty, 'Notiz');
  final abenteuer = (basis['adventures'] as List).first as Map<String, dynamic>;
  abenteuer
    ..['notes'] = <Object?>[
      const HeroNoteEntry(title: 'Spur', description: 'Nach Norden').toJson(),
    ]
    ..['people'] = <Object?>[
      const HeroAdventurePersonEntry(
        id: 'person-1',
        name: 'Answin',
        description: 'Gläubiger',
      ).toJson(),
    ]
    ..['seRewards'] = <Object?>[
      const HeroAdventureSeReward(
        targetId: 'tal_klettern',
        targetLabel: 'Klettern',
      ).toJson(),
    ]
    ..['lootRewards'] = <Object?>[
      const HeroAdventureLootEntry(
        id: 'beute-1',
        name: 'Silberkette',
        modifiers: <InventoryItemModifier>[
          InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'mr',
            wert: 1,
          ),
        ],
      ).toJson(),
    ];
  _pruefe((basis['connections'] as List).isEmpty, 'keine Kontakte');
  basis['connections'] = <Object?>[
    const HeroConnectionEntry(name: 'Answin', ort: 'Gareth').toJson(),
  ];
  _pruefe((basis['companions'] as List).isEmpty, 'keine Begleiter');
  basis['companions'] = <Object?>[
    const HeroCompanion(
      id: 'begleiter-1',
      name: 'Rabe',
      typ: BegleiterTyp.vertrauter,
      mu: 12,
      geschwindigkeiten: <HeroCompanionSpeed>[
        HeroCompanionSpeed(art: 'Fliegen', wert: 12),
      ],
      angriffe: <HeroCompanionAttack>[
        HeroCompanionAttack(id: 'angriff-1', name: 'Schnabel', at: 10),
      ],
      sonderfertigkeiten: <HeroCompanionSonderfertigkeit>[
        HeroCompanionSonderfertigkeit(name: 'Ausweichen I'),
      ],
      ruestungsTeile: <ArmorPiece>[ArmorPiece(name: 'Halsband', rs: 1)],
      ritualCategories: <HeroRitualCategory>[
        HeroRitualCategory(
          id: 'vertrautenmagie',
          name: 'Vertrautenmagie',
          knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
          ownKnowledge: HeroRitualKnowledge(name: 'Vertrautenmagie'),
        ),
      ],
    ).toJson(),
  ];
  _pruefe((basis['gruppen'] as List).isEmpty, 'keine Gruppen');
  basis['gruppen'] = <Object?>[
    const HeroGruppenMitgliedschaft(
      gruppenCode: 'gruppe-1',
      gruppenName: 'Die Sichelträger',
    ).toJson(),
  ];
  final reise = basis['reisebericht'] as Map<String, dynamic>;
  _pruefe((reise['openEntries'] as Map).isEmpty, 'kein offener Eintrag');
  reise['openEntries'] = <String, dynamic>{
    _zukunftsReise: <Object?>[
      const ReiseberichtOpenItem(
        name: 'Thorwal',
        klassifikation: 'normal',
        ap: 10,
      ).toJson(),
    ],
  };
  return const <String>[
    'notes/0',
    'adventures/0',
    'adventures/0/notes/0',
    'adventures/0/people/0',
    'adventures/0/startWorldDate',
    'adventures/0/startAventurianDate',
    'adventures/0/endWorldDate',
    'adventures/0/endAventurianDate',
    'adventures/0/currentAventurianDate',
    'adventures/0/seRewards/0',
    'adventures/0/lootRewards/0',
    'adventures/0/lootRewards/0/modifiers/0',
    'connections/0',
    'companions/0',
    'companions/0/geschwindigkeiten/0',
    'companions/0/angriffe/0',
    'companions/0/sonderfertigkeiten/0',
    'companions/0/ruestungsTeile/0',
    'companions/0/ritualCategories/0',
    'companions/0/ritualCategories/0/ownKnowledge',
    'gruppen/0',
    'reisebericht',
    'reisebericht/openEntries/$_zukunftsReise/0',
  ];
}

// Setzt an jedem Pfad ein Zukunftsfeld und liefert den fertigen Helden.
Zukunftsheld _mitFeldern(Map<String, dynamic> basis, List<String> pfade) {
  final json = _tiefeKopie(basis);
  for (final pfad in pfade) {
    final ziel = wertAn(json, pfad);
    _pruefe(ziel is Map, 'Objekt an $pfad');
    (ziel as Map)[zukunftsfeld] = <String, dynamic>{
      'ebene': pfad,
      'liste': <Object?>[1, 'zwei', null],
    };
  }
  return (
    basis: basis,
    json: json,
    pfade: <String>[for (final pfad in pfade) '$pfad/$zukunftsfeld'],
  );
}

/// Liefert den Wert an [pfad] (`a/0/b`) in [json] oder `null`.
Object? wertAn(Object? json, String pfad) {
  Object? aktuell = json;
  for (final segment in pfad.split('/')) {
    if (aktuell is Map) {
      aktuell = aktuell[segment];
    } else if (aktuell is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= aktuell.length) return null;
      aktuell = aktuell[index];
    } else {
      return null;
    }
  }
  return aktuell;
}

// Tiefe Kopie ueber JSON, damit Tests die Fixture nicht veraendern.
Map<String, dynamic> _tiefeKopie(Map<String, dynamic> json) {
  return jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
}

// Bricht mit klarer Meldung ab, wenn die Fixture nicht passt.
void _pruefe(bool bedingung, String erwartet) {
  if (!bedingung) {
    throw StateError('Fixture passt nicht zu mitZukunftsfeldern: $erwartet');
  }
}
