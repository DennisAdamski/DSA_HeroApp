import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';

void main() {
  group('HeroLanguageEntry', () {
    test('Roundtrip bleibt identisch', () {
      const entry = HeroLanguageEntry(wert: 12, modifier: 2);
      final reloaded = HeroLanguageEntry.fromJson(entry.toJson());
      expect(reloaded.wert, 12);
      expect(reloaded.modifier, 2);
    });

    test('fromJson mit fehlenden Feldern liefert Standardwerte', () {
      final entry = HeroLanguageEntry.fromJson(const <String, dynamic>{});
      expect(entry.wert, 0);
      expect(entry.modifier, 0);
    });

    test('copyWith ersetzt nur angegebene Felder', () {
      const original = HeroLanguageEntry(wert: 5, modifier: 1);
      final updated = original.copyWith(wert: 10);
      expect(updated.wert, 10);
      expect(updated.modifier, 1);
    });
  });

  group('HeroScriptEntry', () {
    test('Roundtrip bleibt identisch', () {
      const entry = HeroScriptEntry(wert: 8, modifier: -1);
      final reloaded = HeroScriptEntry.fromJson(entry.toJson());
      expect(reloaded.wert, 8);
      expect(reloaded.modifier, -1);
    });

    test('fromJson mit fehlenden Feldern liefert Standardwerte', () {
      final entry = HeroScriptEntry.fromJson(const <String, dynamic>{});
      expect(entry.wert, 0);
      expect(entry.modifier, 0);
    });

    test('copyWith ersetzt nur angegebene Felder', () {
      const original = HeroScriptEntry(wert: 7, modifier: 0);
      final updated = original.copyWith(modifier: 3);
      expect(updated.wert, 7);
      expect(updated.modifier, 3);
    });
  });

  group('HeroSheet mit sprachen/schriften', () {
    test('Roundtrip persistiert sprachen, schriften und muttersprache', () {
      const attrs = Attributes(
      mu: 8, kl: 8, inn: 8, ch: 8, ff: 8, ge: 8, ko: 8, kk: 8,
    );
      final hero = HeroSheet(
        id: 'test-id',
        name: 'Testhold',
        level: 1,
        attributes: attrs,
        sprachen: const {
          'spr_garethi': HeroLanguageEntry(wert: 18),
          'spr_tulamidya': HeroLanguageEntry(wert: 8, modifier: 1),
        },
        schriften: const {
          'sch_kusliker_zeichen': HeroScriptEntry(wert: 10),
        },
        muttersprache: 'spr_garethi',
      );

      final json = hero.toJson();
      final reloaded = HeroSheet.fromJson(json);

      expect(reloaded.sprachen.length, 2);
      expect(reloaded.sprachen['spr_garethi']?.wert, 18);
      expect(reloaded.sprachen['spr_tulamidya']?.wert, 8);
      expect(reloaded.sprachen['spr_tulamidya']?.modifier, 1);
      expect(reloaded.schriften.length, 1);
      expect(reloaded.schriften['sch_kusliker_zeichen']?.wert, 10);
      expect(reloaded.muttersprache, 'spr_garethi');
    });

    test('Altes JSON ohne sprachen/schriften liefert leere Maps', () {
      final json = <String, dynamic>{
        'id': 'legacy-id',
        'name': 'Altenheld',
        'schemaVersion': 16,
        'attributes': <String, dynamic>{},
      };

      final hero = HeroSheet.fromJson(json);
      expect(hero.sprachen, isEmpty);
      expect(hero.schriften, isEmpty);
      expect(hero.muttersprache, '');
    });

    test('schemaVersion ist 19', () {
      const attrs = Attributes(
      mu: 8, kl: 8, inn: 8, ch: 8, ff: 8, ge: 8, ko: 8, kk: 8,
    );
      final hero = HeroSheet(
        id: 'v19-id',
        name: 'NeuerHeld',
        level: 1,
        attributes: attrs,
      );
      expect(hero.schemaVersion, 19);
    });
  });
}
