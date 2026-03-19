import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

void main() {
  test('hero sheet roundtrip with expanded basis fields', () {
    final hero = HeroSheet(
      id: 'h1',
      name: 'Test',
      level: 3,
      rawStartAttributes: Attributes(
        mu: 11,
        kl: 11,
        inn: 11,
        ch: 11,
        ff: 11,
        ge: 11,
        ko: 11,
        kk: 11,
      ),
      attributes: Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
      background: HeroBackground(
        rasse: 'Mensch',
        kultur: 'Mittelreich',
        profession: 'Krieger',
        rasseModText: 'MU+1',
        kulturModText: 'KL+1',
        professionModText: 'LE+2',
        stand: 'frei',
        titel: 'Ritterin',
        familieHerkunftHintergrund: 'Text',
        sozialstatus: 8,
      ),
      appearance: HeroAppearance(
        geschlecht: 'w',
        alter: '23',
        groesse: '172 cm',
        gewicht: '65 kg',
        haarfarbe: 'braun',
        augenfarbe: 'gruen',
        aussehen: 'auffaellig',
      ),
      vorteileText: 'AE+2',
      nachteileText: 'MU-1',
      apTotal: 2000,
      apSpent: 1500,
      apAvailable: 500,
      resourceActivationConfig: const HeroResourceActivationConfig(
        magicEnabledOverride: false,
        divineEnabledOverride: true,
      ),
      magicLeadAttribute: 'KL',
      talents: <String, HeroTalentEntry>{
        'tal_schwerter': HeroTalentEntry(
          talentValue: 11,
          atValue: 8,
          paValue: 3,
          talentModifiers: <HeroTalentModifier>[
            HeroTalentModifier(
              modifier: 2,
              description: 'Meisterliche Haltung',
            ),
          ],
        ),
      },
      metaTalents: [
        HeroMetaTalent(
          id: 'meta_pflanzensuchen',
          name: 'Pflanzensuchen',
          componentTalentIds: <String>['tal_schwerter', 'tal_pflanzenkunde'],
          attributes: <String>['MU', 'IN', 'FF'],
          be: 'x2',
        ),
      ],
      spells: {
        'spell_axxeleratus': HeroSpellEntry(
          spellValue: 8,
          gifted: true,
          textOverrides: HeroSpellTextOverrides(
            wirkung: 'Eigenes Heldendetail',
            variants: <String>['Nur fuer diesen Helden'],
          ),
        ),
      },
      ritualCategories: <HeroRitualCategory>[
        HeroRitualCategory(
          id: 'ritual_cat_1',
          name: 'Flueche',
          knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
          ownKnowledge: HeroRitualKnowledge(
            name: 'Flueche',
            value: 5,
            learningComplexity: 'E',
          ),
          additionalFieldDefs: <HeroRitualFieldDef>[
            HeroRitualFieldDef(
              id: 'field_probe',
              label: 'Probe',
              type: HeroRitualFieldType.threeAttributes,
            ),
            HeroRitualFieldDef(
              id: 'field_ausloeser',
              label: 'Ausloeser',
              type: HeroRitualFieldType.text,
            ),
          ],
          rituals: <HeroRitualEntry>[
            HeroRitualEntry(
              name: 'Hexenfluch',
              wirkung: 'Verhaengt grosses Unheil.',
              kosten: '7 AsP',
              wirkungsdauer: '7 Tage',
              merkmale: 'Einfluss',
              zauberdauer: '30 Minuten',
              zielobjekt: 'Einzelperson',
              reichweite: '7 Schritt',
              technik: 'Blickkontakt',
              additionalFieldValues: <HeroRitualFieldValue>[
                HeroRitualFieldValue(
                  fieldDefId: 'field_probe',
                  attributeCodes: <String>['MU', 'CH', 'IN'],
                ),
                HeroRitualFieldValue(
                  fieldDefId: 'field_ausloeser',
                  textValue: 'Beim Vollmond',
                ),
              ],
            ),
          ],
        ),
      ],
      combatConfig: CombatConfig(
        mainWeapon: MainWeaponSlot(
          name: 'Kurzschwert',
          talentId: 'tal_schwerter',
          tpFlat: 2,
          wmAt: 1,
          wmPa: -1,
          iniMod: 0,
          beTalentMod: -2,
          isArtifact: true,
          artifactDescription: 'Gebundene Flammenklinge',
        ),
        offhandAssignment: OffhandAssignment(equipmentIndex: 0),
        offhandEquipment: <OffhandEquipmentEntry>[
          OffhandEquipmentEntry(
            name: 'Holzschild',
            type: OffhandEquipmentType.shield,
            atMod: -5,
            paMod: 7,
            iniMod: -3,
            isArtifact: true,
            artifactDescription: 'Schutzgeist im Schildbuckel',
          ),
        ],
        armor: ArmorConfig(
          pieces: <ArmorPiece>[
            ArmorPiece(
              name: 'Kettenhemd',
              isActive: true,
              rg1Active: true,
              rs: 3,
              be: 2,
              isArtifact: true,
              artifactDescription: 'Runenfutter gegen Stichwaffen',
            ),
          ],
          globalArmorTrainingLevel: 2,
        ),
        specialRules: CombatSpecialRules(
          kampfreflexe: true,
          ausweichenI: true,
          schildkampfI: true,
          activeCombatSpecialAbilityIds: ['ksf_hammerfaust'],
          gladiatorStyleTalent: 'raufen',
          activeManeuvers: ['Finte', 'Wuchtschlag'],
        ),
        manualMods: CombatManualMods(iniMod: 1, ausweichenMod: 2),
        waffenmeisterschaften: const <WaffenmeisterConfig>[
          WaffenmeisterConfig(
            talentId: 'tal_schwerter',
            weaponType: 'Kurzschwert',
            bonuses: <WaffenmeisterBonus>[
              WaffenmeisterBonus(
                type: WaffenmeisterBonusType.iniBonus,
                value: 1,
              ),
              WaffenmeisterBonus(
                type: WaffenmeisterBonusType.maneuverReduction,
                targetManeuver: 'man_finte',
                value: 2,
              ),
            ],
            requiredAttribute1: 'GE',
            requiredAttribute1Value: 16,
            requiredAttribute2: 'KK',
            requiredAttribute2Value: 16,
          ),
        ],
      ),
      hiddenTalentIds: ['tal_a', 'tal_a', ' ', 'tal_b'],
      talentSpecialAbilities: const <TalentSpecialAbility>[
        TalentSpecialAbility(name: 'Meisterhandwerk'),
        TalentSpecialAbility(name: 'Begabung'),
      ],
      notes: const <HeroNoteEntry>[
        HeroNoteEntry(
          title: 'Offene Schuld',
          description: 'Noch 20 Dukaten bei Jucho offen.',
        ),
      ],
      connections: const <HeroConnectionEntry>[
        HeroConnectionEntry(
          name: 'Jucho',
          ort: 'Punin',
          sozialstatus: '5',
          loyalitaet: 'schwankend',
          beschreibung: 'Informant aus dem Hafenviertel.',
        ),
      ],
      unknownModifierFragments: ['foo'],
    );

    final json = hero.toJson();
    final reloaded = HeroSheet.fromJson(json);

    expect(reloaded.background.rasse, 'Mensch');
    expect(reloaded.schemaVersion, 21);
    expect(reloaded.background.kultur, 'Mittelreich');
    expect(reloaded.background.profession, 'Krieger');
    expect(reloaded.apTotal, 2000);
    expect(reloaded.apAvailable, 500);
    expect(reloaded.resourceActivationConfig.magicEnabledOverride, isFalse);
    expect(reloaded.resourceActivationConfig.divineEnabledOverride, isTrue);
    expect(reloaded.magicLeadAttribute, 'KL');
    expect(reloaded.hiddenTalentIds, ['tal_a', 'tal_b']);
    expect(reloaded.talentSpecialAbilities.map((entry) => entry.name), [
      'Meisterhandwerk',
      'Begabung',
    ]);
    expect(reloaded.notes.single.title, 'Offene Schuld');
    expect(
      reloaded.notes.single.description,
      'Noch 20 Dukaten bei Jucho offen.',
    );
    expect(reloaded.connections.single.name, 'Jucho');
    expect(reloaded.connections.single.ort, 'Punin');
    expect(reloaded.connections.single.loyalitaet, 'schwankend');
    expect(reloaded.unknownModifierFragments, contains('foo'));
    expect(reloaded.metaTalents.single.name, 'Pflanzensuchen');
    expect(reloaded.metaTalents.single.componentTalentIds, <String>[
      'tal_schwerter',
      'tal_pflanzenkunde',
    ]);
    expect(reloaded.metaTalents.single.attributes, <String>['MU', 'IN', 'FF']);
    expect(reloaded.metaTalents.single.be, 'x2');
    expect(reloaded.rawStartAttributes.mu, 11);
    expect(reloaded.rawStartAttributes.kk, 11);
    expect(reloaded.startAttributes.mu, 12);
    expect(reloaded.startAttributes.kk, 12);
    expect(reloaded.talents['tal_schwerter']?.atValue, 8);
    expect(reloaded.talents['tal_schwerter']?.paValue, 3);
    expect(reloaded.talents['tal_schwerter']?.modifier, 2);
    expect(
      reloaded.talents['tal_schwerter']?.talentModifiers.single.description,
      'Meisterliche Haltung',
    );
    expect(
      reloaded.spells['spell_axxeleratus']?.textOverrides?.wirkung,
      'Eigenes Heldendetail',
    );
    expect(reloaded.spells['spell_axxeleratus']?.gifted, isTrue);
    expect(
      reloaded.spells['spell_axxeleratus']?.textOverrides?.variants,
      <String>['Nur fuer diesen Helden'],
    );
    expect(reloaded.ritualCategories.single.name, 'Flueche');
    expect(
      reloaded.ritualCategories.single.ownKnowledge?.learningComplexity,
      'E',
    );
    expect(reloaded.ritualCategories.single.additionalFieldDefs.length, 2);
    expect(reloaded.ritualCategories.single.rituals.single.name, 'Hexenfluch');
    expect(
      reloaded
          .ritualCategories
          .single
          .rituals
          .single
          .additionalFieldValues
          .first
          .attributeCodes,
      <String>['MU', 'CH', 'IN'],
    );
    expect(reloaded.combatConfig.mainWeapon.name, 'Kurzschwert');
    expect(reloaded.combatConfig.mainWeapon.isArtifact, isTrue);
    expect(
      reloaded.combatConfig.mainWeapon.artifactDescription,
      'Gebundene Flammenklinge',
    );
    expect(reloaded.combatConfig.weaponSlots.length, 1);
    expect(reloaded.combatConfig.selectedWeaponIndex, 0);
    expect(reloaded.combatConfig.offhandAssignment.equipmentIndex, 0);
    expect(
      reloaded.combatConfig.offhandEquipment.single.type,
      OffhandEquipmentType.shield,
    );
    expect(reloaded.combatConfig.offhandEquipment.single.isArtifact, isTrue);
    expect(
      reloaded.combatConfig.offhandEquipment.single.artifactDescription,
      'Schutzgeist im Schildbuckel',
    );
    expect(reloaded.combatConfig.armor.pieces.length, 1);
    expect(reloaded.combatConfig.armor.pieces.first.be, 2);
    expect(reloaded.combatConfig.armor.pieces.first.isArtifact, isTrue);
    expect(
      reloaded.combatConfig.armor.pieces.first.artifactDescription,
      'Runenfutter gegen Stichwaffen',
    );
    expect(reloaded.combatConfig.armor.globalArmorTrainingLevel, 2);
    expect(reloaded.combatConfig.specialRules.kampfreflexe, isTrue);
    expect(reloaded.combatConfig.specialRules.activeCombatSpecialAbilityIds, [
      'ksf_hammerfaust',
    ]);
    expect(reloaded.combatConfig.specialRules.gladiatorStyleTalent, 'raufen');
    expect(reloaded.combatConfig.specialRules.activeManeuvers, [
      'Finte',
      'Wuchtschlag',
    ]);
    expect(reloaded.combatConfig.waffenmeisterschaften, hasLength(1));
    expect(
      reloaded.combatConfig.waffenmeisterschaften.single.weaponType,
      'Kurzschwert',
    );
    expect(
      reloaded.combatConfig.waffenmeisterschaften.single.bonuses.first.type,
      WaffenmeisterBonusType.iniBonus,
    );
  });

  test('hero sheet backwards compatibility for missing new fields', () {
    final old = {
      'schemaVersion': 1,
      'id': 'old',
      'name': 'Alt',
      'level': 1,
      'attributes': {
        'mu': 8,
        'kl': 8,
        'inn': 8,
        'ch': 8,
        'ff': 8,
        'ge': 8,
        'ko': 8,
        'kk': 8,
      },
      'persistentMods': {},
      'bought': {},
      'talents': {
        'tal_schwerter': {'talentValue': 5},
      },
    };

    final loaded = HeroSheet.fromJson(old);
    expect(loaded.background.rasse, '');
    expect(loaded.apTotal, 0);
    expect(loaded.hiddenTalentIds, isEmpty);
    expect(loaded.talentSpecialAbilities, isEmpty);
    expect(loaded.unknownModifierFragments, isEmpty);
    expect(loaded.resourceActivationConfig.magicEnabledOverride, isNull);
    expect(loaded.resourceActivationConfig.divineEnabledOverride, isNull);
    expect(loaded.magicLeadAttribute, isEmpty);
    expect(loaded.metaTalents, isEmpty);
    expect(loaded.ritualCategories, isEmpty);
    expect(loaded.notes, isEmpty);
    expect(loaded.connections, isEmpty);
    expect(loaded.rawStartAttributes.mu, loaded.attributes.mu);
    expect(loaded.rawStartAttributes.kk, loaded.attributes.kk);
    expect(loaded.startAttributes.mu, loaded.attributes.mu);
    expect(loaded.startAttributes.kk, loaded.attributes.kk);
    expect(loaded.talents['tal_schwerter']?.atValue, 0);
    expect(loaded.talents['tal_schwerter']?.paValue, 0);
    expect(loaded.combatConfig.mainWeapon.name, isEmpty);
    expect(loaded.combatConfig.mainWeapon.isArtifact, isFalse);
    expect(loaded.combatConfig.mainWeapon.artifactDescription, isEmpty);
    expect(loaded.combatConfig.weaponSlots.length, 1);
    expect(loaded.combatConfig.offhandAssignment.isNone, isTrue);
    expect(loaded.combatConfig.offhandEquipment, isEmpty);
    expect(loaded.combatConfig.armor.pieces, isEmpty);
    expect(loaded.combatConfig.specialRules.activeManeuvers, isEmpty);
  });

  test('combat config roundtrip keeps weapon list and selected slot', () {
    const hero = HeroSheet(
      id: 'h2',
      name: 'Waffenliste',
      level: 1,
      attributes: Attributes(
        mu: 10,
        kl: 10,
        inn: 10,
        ch: 10,
        ff: 10,
        ge: 10,
        ko: 10,
        kk: 10,
      ),
      combatConfig: CombatConfig(
        weapons: <MainWeaponSlot>[
          MainWeaponSlot(
            name: 'Dolch',
            isOneHanded: true,
            isArtifact: true,
            artifactDescription: 'Runen auf der Klinge',
          ),
          MainWeaponSlot(name: 'Bidenhaender', isOneHanded: false, wmAt: 2),
        ],
        selectedWeaponIndex: 1,
      ),
    );

    final reloaded = HeroSheet.fromJson(hero.toJson());
    expect(reloaded.combatConfig.weaponSlots.length, 2);
    expect(reloaded.combatConfig.selectedWeaponIndex, 1);
    expect(reloaded.combatConfig.mainWeapon.name, 'Bidenhaender');
    expect(reloaded.combatConfig.weaponSlots.first.isArtifact, isTrue);
    expect(
      reloaded.combatConfig.weaponSlots.first.artifactDescription,
      'Runen auf der Klinge',
    );
    expect(reloaded.combatConfig.selectedWeapon.isOneHanded, isFalse);
  });

  test('combat config roundtrip keeps ranged weapon profile data', () {
    const hero = HeroSheet(
      id: 'h4',
      name: 'Fernkampf',
      level: 1,
      attributes: Attributes(
        mu: 10,
        kl: 10,
        inn: 10,
        ch: 10,
        ff: 10,
        ge: 10,
        ko: 10,
        kk: 10,
      ),
      combatConfig: CombatConfig(
        weapons: <MainWeaponSlot>[
          MainWeaponSlot(
            name: 'Kurzbogen',
            talentId: 'tal_bogen',
            combatType: WeaponCombatType.ranged,
            weaponType: 'Kurzbogen',
            wmAt: 2,
            rangedProfile: RangedWeaponProfile(
              reloadTime: 3,
              distanceBands: <RangedDistanceBand>[
                RangedDistanceBand(label: 'Sehr nah', tpMod: 2),
                RangedDistanceBand(label: 'Nah', tpMod: 1),
                RangedDistanceBand(label: 'Mittel', tpMod: 0),
                RangedDistanceBand(label: 'Weit', tpMod: -1),
                RangedDistanceBand(label: 'Extrem', tpMod: -2),
              ],
              projectiles: <RangedProjectile>[
                RangedProjectile(
                  name: 'Jagdspitze',
                  count: 12,
                  tpMod: 1,
                  iniMod: -1,
                  atMod: 2,
                  description: 'Breite Pfeilspitze fuer Wild.',
                ),
              ],
              selectedDistanceIndex: 3,
              selectedProjectileIndex: 0,
            ),
          ),
        ],
        selectedWeaponIndex: 0,
      ),
    );

    final reloaded = HeroSheet.fromJson(hero.toJson());
    final weapon = reloaded.combatConfig.selectedWeapon;
    expect(weapon.combatType, WeaponCombatType.ranged);
    expect(weapon.wmAt, 2);
    expect(weapon.rangedProfile.reloadTime, 3);
    expect(weapon.rangedProfile.selectedDistanceBand.label, 'Weit');
    expect(weapon.rangedProfile.selectedProjectileOrNull?.name, 'Jagdspitze');
    expect(weapon.rangedProfile.selectedProjectileOrNull?.count, 12);
  });

  test('legacy ranged modifiers migrate from fk fields to at fields', () {
    final legacy = {
      'schemaVersion': 12,
      'id': 'legacy-ranged',
      'name': 'Altbogen',
      'level': 1,
      'attributes': {
        'mu': 10,
        'kl': 10,
        'inn': 10,
        'ch': 10,
        'ff': 10,
        'ge': 10,
        'ko': 10,
        'kk': 10,
      },
      'combatConfig': {
        'mainWeapon': {
          'name': 'Kurzbogen',
          'talentId': 'tal_bogen',
          'combatType': 'ranged',
          'weaponType': 'Kurzbogen',
          'wmFk': 3,
          'rangedProfile': {
            'projectiles': [
              {
                'name': 'Jagdspitze',
                'count': 12,
                'tpMod': 1,
                'iniMod': -1,
                'fkMod': 2,
              },
            ],
          },
        },
        'manualMods': {'fkMod': 4},
      },
      'talents': <String, dynamic>{},
    };

    final reloaded = HeroSheet.fromJson(legacy);
    final weapon = reloaded.combatConfig.selectedWeapon;

    expect(reloaded.schemaVersion, 12);
    expect(weapon.wmAt, 3);
    expect(weapon.rangedProfile.projectiles.single.atMod, 2);
    expect(reloaded.combatConfig.manualMods.atMod, 4);
  });

  test(
    'hero sheet falls back to start attributes when raw start is missing',
    () {
      final old = {
        'schemaVersion': 7,
        'id': 'legacy-start',
        'name': 'Altstart',
        'level': 1,
        'attributes': {
          'mu': 13,
          'kl': 13,
          'inn': 13,
          'ch': 13,
          'ff': 13,
          'ge': 13,
          'ko': 13,
          'kk': 13,
        },
        'startAttributes': {
          'mu': 10,
          'kl': 11,
          'inn': 12,
          'ch': 13,
          'ff': 14,
          'ge': 15,
          'ko': 16,
          'kk': 17,
        },
      };

      final loaded = HeroSheet.fromJson(old);
      expect(loaded.rawStartAttributes.mu, 10);
      expect(loaded.rawStartAttributes.kk, 17);
      expect(loaded.startAttributes.mu, 10);
      expect(loaded.startAttributes.kk, 17);
    },
  );

  test('combat config roundtrip keeps selectedWeaponIndex -1', () {
    const hero = HeroSheet(
      id: 'h3',
      name: 'Keine aktive Waffe',
      level: 1,
      attributes: Attributes(
        mu: 10,
        kl: 10,
        inn: 10,
        ch: 10,
        ff: 10,
        ge: 10,
        ko: 10,
        kk: 10,
      ),
      combatConfig: CombatConfig(
        weapons: <MainWeaponSlot>[
          MainWeaponSlot(
            name: 'Dolch',
            talentId: 'tal_nah',
            weaponType: 'Dolch',
          ),
        ],
        selectedWeaponIndex: -1,
      ),
    );

    final reloaded = HeroSheet.fromJson(hero.toJson());
    expect(reloaded.combatConfig.selectedWeaponIndex, -1);
    expect(reloaded.combatConfig.hasSelectedWeapon, isFalse);
    expect(reloaded.combatConfig.selectedWeaponOrNull, isNull);
  });

  test('talent entry roundtrip keeps gifted flag', () {
    const entry = HeroTalentEntry(
      talentValue: 8,
      atValue: 5,
      paValue: 3,
      gifted: true,
    );

    final reloaded = HeroTalentEntry.fromJson(entry.toJson());
    expect(reloaded.gifted, isTrue);
    expect(reloaded.talentValue, 8);
    expect(reloaded.atValue, 5);
    expect(reloaded.paValue, 3);
  });

  test('meta talent roundtrip keeps components, attributes and be rule', () {
    const metaTalent = HeroMetaTalent(
      id: 'meta_1',
      name: 'Pflanzensuchen',
      componentTalentIds: <String>['tal_sinne', 'tal_pflanzen', 'tal_wildnis'],
      attributes: <String>['MU', 'IN', 'FF'],
      be: 'x2',
    );

    final reloaded = HeroMetaTalent.fromJson(metaTalent.toJson());
    expect(reloaded.id, 'meta_1');
    expect(reloaded.name, 'Pflanzensuchen');
    expect(reloaded.componentTalentIds, <String>[
      'tal_sinne',
      'tal_pflanzen',
      'tal_wildnis',
    ]);
    expect(reloaded.attributes, <String>['MU', 'IN', 'FF']);
    expect(reloaded.be, 'x2');
  });

  test(
    'legacy armor fields are ignored and load as empty armor piece list',
    () {
      final legacy = {
        'schemaVersion': 1,
        'id': 'legacy_armor',
        'name': 'Alt',
        'level': 1,
        'attributes': {
          'mu': 8,
          'kl': 8,
          'inn': 8,
          'ch': 8,
          'ff': 8,
          'ge': 8,
          'ko': 8,
          'kk': 8,
        },
        'combatConfig': {
          'armor': {
            'rsTotal': 5,
            'beTotalRaw': 4,
            'armorTrainingLevel': 3,
            'rgIActive': true,
          },
        },
      };

      final loaded = HeroSheet.fromJson(legacy);
      expect(loaded.combatConfig.armor.pieces, isEmpty);
      expect(loaded.combatConfig.armor.globalArmorTrainingLevel, 0);
    },
  );

  test('schemaVersion ist 21 nach toJson (v21-Default)', () {
    const hero = HeroSheet(
      id: 'version-check',
      name: 'Versionstest',
      level: 1,
      attributes: Attributes(
        mu: 10,
        kl: 10,
        inn: 10,
        ch: 10,
        ff: 10,
        ge: 10,
        ko: 10,
        kk: 10,
      ),
    );
    final json = hero.toJson();
    expect(json['schemaVersion'], 21);
    expect(HeroSheet.fromJson(json).schemaVersion, 21);
  });

  test('legacy talentSpecialAbilities string migrates into structured list', () {
    final loaded = HeroSheet.fromJson({
      'schemaVersion': 20,
      'id': 'legacy-sf',
      'name': 'Alt-SF',
      'level': 1,
      'attributes': {
        'mu': 10,
        'kl': 10,
        'inn': 10,
        'ch': 10,
        'ff': 10,
        'ge': 10,
        'ko': 10,
        'kk': 10,
      },
      'talentSpecialAbilities': 'Regeneration I, Regeneration II',
    });

    expect(loaded.talentSpecialAbilities.map((entry) => entry.name), [
      'Regeneration I',
      'Regeneration II',
    ]);
  });

  test('v15 Hero-JSON liefert korrekte Standardwerte fuer neue Inventarfelder', () {
    final v15Json = {
      'schemaVersion': 15,
      'id': 'v15-hero',
      'name': 'Altgeruest',
      'level': 1,
      'attributes': {
        'mu': 10, 'kl': 10, 'inn': 10, 'ch': 10,
        'ff': 10, 'ge': 10, 'ko': 10, 'kk': 10,
      },
      'inventoryEntries': [
        {
          'gegenstand': 'Schwert',
          'gewicht': '1500',
          'anzahl': '1',
        },
      ],
    };

    final loaded = HeroSheet.fromJson(v15Json);
    expect(loaded.inventoryEntries.length, 1);

    final entry = loaded.inventoryEntries.first;
    expect(entry.gegenstand, 'Schwert');
    expect(entry.itemType, InventoryItemType.sonstiges);
    expect(entry.source, InventoryItemSource.manuell);
    expect(entry.sourceRef, isNull);
    expect(entry.istAusgeruestet, isFalse);
    expect(entry.modifiers, isEmpty);
    expect(entry.gewichtGramm, 0);
    expect(entry.wertSilber, 0);
    expect(entry.herkunft, '');
    // Alte String-Felder bleiben unveraendert
    expect(entry.gewicht, '1500');
  });

  test('Inventar-Eintrag mit Modifikatoren wird korrekt im HeroSheet gespeichert', () {
    final hero = HeroSheet(
      id: 'inv-mod',
      name: 'Modtest',
      level: 1,
      attributes: const Attributes(
        mu: 10, kl: 10, inn: 10, ch: 10,
        ff: 10, ge: 10, ko: 10, kk: 10,
      ),
      inventoryEntries: const [
        HeroInventoryEntry(
          gegenstand: 'Jaegerstiefel',
          itemType: InventoryItemType.ausruestung,
          source: InventoryItemSource.manuell,
          istAusgeruestet: true,
          gewichtGramm: 800,
          wertSilber: 15,
          herkunft: 'Marktplatz',
          modifiers: [
            InventoryItemModifier(
              kind: InventoryModifierKind.stat,
              targetId: 'gs',
              wert: 2,
            ),
          ],
        ),
      ],
    );

    final reloaded = HeroSheet.fromJson(hero.toJson());
    expect(reloaded.inventoryEntries.length, 1);
    final entry = reloaded.inventoryEntries.first;
    expect(entry.gegenstand, 'Jaegerstiefel');
    expect(entry.itemType, InventoryItemType.ausruestung);
    expect(entry.istAusgeruestet, isTrue);
    expect(entry.gewichtGramm, 800);
    expect(entry.wertSilber, 15);
    expect(entry.herkunft, 'Marktplatz');
    expect(entry.modifiers.length, 1);
    expect(entry.modifiers.first.targetId, 'gs');
    expect(entry.modifiers.first.wert, 2);
  });

  test('legacy offhand entries migrate into referenced offhand equipment', () {
    final loaded = HeroSheet.fromJson({
      'schemaVersion': 14,
      'id': 'legacy_offhand',
      'name': 'Alt',
      'level': 1,
      'attributes': {
        'mu': 8,
        'kl': 8,
        'inn': 8,
        'ch': 8,
        'ff': 8,
        'ge': 8,
        'ko': 8,
        'kk': 8,
      },
      'combatConfig': {
        'mainWeapon': {'name': 'Kurzschwert'},
        'offhand': {
          'mode': 'shield',
          'name': 'Holzschild',
          'atMod': -1,
          'paMod': 2,
          'iniMod': -2,
        },
      },
    });

    expect(loaded.combatConfig.offhandAssignment.equipmentIndex, 0);
    expect(loaded.combatConfig.offhandEquipment.single.name, 'Holzschild');
    expect(
      loaded.combatConfig.offhandEquipment.single.type,
      OffhandEquipmentType.shield,
    );
    expect(loaded.combatConfig.offhandEquipment.single.paMod, 2);
  });
}
