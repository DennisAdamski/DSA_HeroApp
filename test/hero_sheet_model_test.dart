import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

void main() {
  test('hero sheet roundtrip with expanded basis fields', () {
    const hero = HeroSheet(
      id: 'h1',
      name: 'Test',
      level: 3,
      attributes: Attributes(mu: 12, kl: 12, inn: 12, ch: 12, ff: 12, ge: 12, ko: 12, kk: 12),
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
      unknownModifierFragments: ['foo'],
    );

    final json = hero.toJson();
    final reloaded = HeroSheet.fromJson(json);

    expect(reloaded.rasse, 'Mensch');
    expect(reloaded.kultur, 'Mittelreich');
    expect(reloaded.profession, 'Krieger');
    expect(reloaded.apTotal, 2000);
    expect(reloaded.apAvailable, 500);
    expect(reloaded.unknownModifierFragments, contains('foo'));
    expect(reloaded.startAttributes.mu, 12);
    expect(reloaded.startAttributes.kk, 12);
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
    };

    final loaded = HeroSheet.fromJson(old);
    expect(loaded.rasse, '');
    expect(loaded.apTotal, 0);
    expect(loaded.unknownModifierFragments, isEmpty);
    expect(loaded.startAttributes.mu, loaded.attributes.mu);
    expect(loaded.startAttributes.kk, loaded.attributes.kk);
  });
}
