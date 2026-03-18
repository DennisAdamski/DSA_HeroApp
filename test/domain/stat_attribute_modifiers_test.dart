import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

const _defaultAttributes = Attributes(
  mu: 10, kl: 10, inn: 10, ch: 10, ff: 10, ge: 10, ko: 10, kk: 10,
);

void main() {
  group('HeroSheet statModifiers/attributeModifiers Serialisierung', () {
    test('roundtrip toJson/fromJson', () {
      final hero = HeroSheet(
        id: 'test',
        name: 'Test',
        level: 1,
        attributes: _defaultAttributes,
        statModifiers: {
          'lep': [
            HeroTalentModifier(modifier: 2, description: 'Artefakt'),
            HeroTalentModifier(modifier: 1, description: 'Segen'),
          ],
        },
        attributeModifiers: {
          'mu': [
            HeroTalentModifier(modifier: 1, description: 'Amulett'),
          ],
        },
      );

      final json = hero.toJson();
      final loaded = HeroSheet.fromJson(json);

      expect(loaded.statModifiers['lep'], hasLength(2));
      expect(loaded.statModifiers['lep']![0].modifier, 2);
      expect(loaded.statModifiers['lep']![0].description, 'Artefakt');
      expect(loaded.statModifiers['lep']![1].modifier, 1);

      expect(loaded.attributeModifiers['mu'], hasLength(1));
      expect(loaded.attributeModifiers['mu']![0].modifier, 1);
      expect(loaded.attributeModifiers['mu']![0].description, 'Amulett');
    });

    test('leere Maps werden korrekt geladen', () {
      final hero = HeroSheet(
        id: 'test',
        name: 'Test',
        level: 1,
        attributes: _defaultAttributes,
      );

      final json = hero.toJson();
      final loaded = HeroSheet.fromJson(json);

      expect(loaded.statModifiers, isEmpty);
      expect(loaded.attributeModifiers, isEmpty);
    });

    test('Migration: persistentMods werden zu statModifiers migriert', () {
      // Simuliert altes JSON ohne statModifiers aber mit persistentMods.
      final json = <String, dynamic>{
        'id': 'test',
        'name': 'Test',
        'level': 1,
        'attributes': {
          'mu': 10, 'kl': 10, 'inn': 10, 'ch': 10,
          'ff': 10, 'ge': 10, 'ko': 10, 'kk': 10,
        },
        'persistentMods': {
          'lep': 3,
          'mr': -1,
          'au': 0,
        },
      };

      final loaded = HeroSheet.fromJson(json);

      expect(loaded.statModifiers['lep'], hasLength(1));
      expect(loaded.statModifiers['lep']![0].modifier, 3);
      expect(loaded.statModifiers['lep']![0].description, 'Manuell');

      expect(loaded.statModifiers['mr'], hasLength(1));
      expect(loaded.statModifiers['mr']![0].modifier, -1);

      // au=0 sollte nicht migriert werden.
      expect(loaded.statModifiers.containsKey('au'), isFalse);
    });

    test('Migration findet nicht statt wenn statModifiers bereits vorhanden', () {
      final json = <String, dynamic>{
        'id': 'test',
        'name': 'Test',
        'level': 1,
        'attributes': {
          'mu': 10, 'kl': 10, 'inn': 10, 'ch': 10,
          'ff': 10, 'ge': 10, 'ko': 10, 'kk': 10,
        },
        'persistentMods': {
          'lep': 99,
        },
        'statModifiers': {
          'lep': [
            {'modifier': 5, 'description': 'Eigener Mod'},
          ],
        },
      };

      final loaded = HeroSheet.fromJson(json);

      // Bestehende statModifiers behalten, persistentMods nicht migrieren.
      expect(loaded.statModifiers['lep'], hasLength(1));
      expect(loaded.statModifiers['lep']![0].modifier, 5);
      expect(loaded.statModifiers['lep']![0].description, 'Eigener Mod');
    });
  });
}
