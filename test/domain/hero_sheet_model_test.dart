import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

void main() {
  test('hero sheet roundtrip with expanded basis fields', () {
    const hero = HeroSheet(
      id: 'h1',
      name: 'Test',
      level: 3,
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
      rasse: 'Mensch',
      kultur: 'Mittelreich',
      profession: 'Krieger',
      rasseModText: 'MU+1',
      kulturModText: 'KL+1',
      professionModText: 'LE+2',
      geschlecht: 'w',
      alter: '23',
      groesse: '172 cm',
      gewicht: '65 kg',
      haarfarbe: 'braun',
      augenfarbe: 'gruen',
      aussehen: 'auffaellig',
      stand: 'frei',
      titel: 'Ritterin',
      familieHerkunftHintergrund: 'Text',
      sozialstatus: 8,
      vorteileText: 'AE+2',
      nachteileText: 'MU-1',
      apTotal: 2000,
      apSpent: 1500,
      apAvailable: 500,
      talents: {
        'tal_schwerter': HeroTalentEntry(
          talentValue: 11,
          atValue: 8,
          paValue: 3,
        ),
      },
      spells: {
        'spell_axxeleratus': HeroSpellEntry(
          spellValue: 8,
          textOverrides: HeroSpellTextOverrides(
            wirkung: 'Eigenes Heldendetail',
            variants: <String>['Nur fuer diesen Helden'],
          ),
        ),
      },
      combatConfig: CombatConfig(
        mainWeapon: MainWeaponSlot(
          name: 'Kurzschwert',
          talentId: 'tal_schwerter',
          tpFlat: 2,
          wmAt: 1,
          wmPa: -1,
          iniMod: 0,
          beTalentMod: -2,
        ),
        offhand: OffhandSlot(
          mode: OffhandMode.shield,
          name: 'Holzschild',
          atMod: -5,
          paMod: 7,
          iniMod: -3,
        ),
        armor: ArmorConfig(
          pieces: <ArmorPiece>[
            ArmorPiece(
              name: 'Kettenhemd',
              isActive: true,
              rg1Active: true,
              rs: 3,
              be: 2,
            ),
          ],
          globalArmorTrainingLevel: 2,
        ),
        specialRules: CombatSpecialRules(
          kampfreflexe: true,
          ausweichenI: true,
          schildkampfI: true,
          activeManeuvers: ['Finte', 'Wuchtschlag'],
        ),
        manualMods: CombatManualMods(iniMod: 1, ausweichenMod: 2),
      ),
      hiddenTalentIds: ['tal_a', 'tal_a', ' ', 'tal_b'],
      talentSpecialAbilities: 'Meisterhandwerk, Begabung',
      unknownModifierFragments: ['foo'],
    );

    final json = hero.toJson();
    final reloaded = HeroSheet.fromJson(json);

    expect(reloaded.rasse, 'Mensch');
    expect(reloaded.schemaVersion, 6);
    expect(reloaded.kultur, 'Mittelreich');
    expect(reloaded.profession, 'Krieger');
    expect(reloaded.apTotal, 2000);
    expect(reloaded.apAvailable, 500);
    expect(reloaded.hiddenTalentIds, ['tal_a', 'tal_b']);
    expect(reloaded.talentSpecialAbilities, 'Meisterhandwerk, Begabung');
    expect(reloaded.unknownModifierFragments, contains('foo'));
    expect(reloaded.startAttributes.mu, 12);
    expect(reloaded.startAttributes.kk, 12);
    expect(reloaded.talents['tal_schwerter']?.atValue, 8);
    expect(reloaded.talents['tal_schwerter']?.paValue, 3);
    expect(
      reloaded.spells['spell_axxeleratus']?.textOverrides?.wirkung,
      'Eigenes Heldendetail',
    );
    expect(
      reloaded.spells['spell_axxeleratus']?.textOverrides?.variants,
      <String>['Nur fuer diesen Helden'],
    );
    expect(reloaded.combatConfig.mainWeapon.name, 'Kurzschwert');
    expect(reloaded.combatConfig.weaponSlots.length, 1);
    expect(reloaded.combatConfig.selectedWeaponIndex, 0);
    expect(reloaded.combatConfig.offhand.mode, OffhandMode.shield);
    expect(reloaded.combatConfig.armor.pieces.length, 1);
    expect(reloaded.combatConfig.armor.pieces.first.be, 2);
    expect(reloaded.combatConfig.armor.globalArmorTrainingLevel, 2);
    expect(reloaded.combatConfig.specialRules.kampfreflexe, isTrue);
    expect(reloaded.combatConfig.specialRules.activeManeuvers, [
      'Finte',
      'Wuchtschlag',
    ]);
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
    expect(loaded.rasse, '');
    expect(loaded.apTotal, 0);
    expect(loaded.hiddenTalentIds, isEmpty);
    expect(loaded.talentSpecialAbilities, '');
    expect(loaded.unknownModifierFragments, isEmpty);
    expect(loaded.startAttributes.mu, loaded.attributes.mu);
    expect(loaded.startAttributes.kk, loaded.attributes.kk);
    expect(loaded.talents['tal_schwerter']?.atValue, 0);
    expect(loaded.talents['tal_schwerter']?.paValue, 0);
    expect(loaded.combatConfig.mainWeapon.name, isEmpty);
    expect(loaded.combatConfig.weaponSlots.length, 1);
    expect(loaded.combatConfig.offhand.mode, OffhandMode.none);
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
          MainWeaponSlot(name: 'Dolch', isOneHanded: true),
          MainWeaponSlot(name: 'Bidenhaender', isOneHanded: false, wmAt: 2),
        ],
        selectedWeaponIndex: 1,
      ),
    );

    final reloaded = HeroSheet.fromJson(hero.toJson());
    expect(reloaded.combatConfig.weaponSlots.length, 2);
    expect(reloaded.combatConfig.selectedWeaponIndex, 1);
    expect(reloaded.combatConfig.mainWeapon.name, 'Bidenhaender');
    expect(reloaded.combatConfig.selectedWeapon.isOneHanded, isFalse);
  });

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
}
