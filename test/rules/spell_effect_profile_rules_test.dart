import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_profile_rules.dart';

SpellDef _zauber(String id) {
  return SpellDef.fromJson(<String, dynamic>{
    'id': id,
    'name': id,
    'tradition': 'Gildenmagie',
    'steigerung': 'C',
    'attributes': <String>['KL', 'IN', 'CH'],
    'active': true,
  });
}

SpellEffectProfile _profil(Map<String, dynamic> felder) {
  return SpellEffectProfile.fromJson(<String, dynamic>{
    'id': 'profil_x',
    'spellId': 'spell_x',
    'profilVersion': 1,
    'status': 'belegt',
    'beleg': <String, dynamic>{'buch': 'Liber Cantiones', 'seite': '1'},
    ...felder,
  });
}

RulesCatalog _katalog(List<SpellEffectProfile> profile) {
  return RulesCatalog(
    version: 'test',
    source: 'test',
    talents: const [],
    spells: [_zauber('spell_x'), _zauber('spell_y')],
    weapons: const [],
    spellEffects: profile,
  );
}

Set<SpellEffectBefundArt> _arten(List<SpellEffectProfile> profile) {
  return validiereSpellEffectProfile(
    _katalog(profile),
  ).map((befund) => befund.art).toSet();
}

void main() {
  group('validiereSpellEffectProfile', () {
    test('ein vollständiges belegtes Profil hat keinen Befund', () {
      expect(validiereSpellEffectProfile(_katalog([_profil({})])), isEmpty);
    });

    test('ohne Profile gibt es keinen Befund', () {
      expect(validiereSpellEffectProfile(_katalog(const [])), isEmpty);
    });

    test('unbekannter Zauber wird gemeldet', () {
      expect(
        _arten([_profil({'spellId': 'spell_gibt_es_nicht'})]),
        contains(SpellEffectBefundArt.zauberUnbekannt),
      );
    });

    test('fehlende und doppelte Profil-IDs werden gemeldet', () {
      expect(
        _arten([_profil({'id': ''})]),
        contains(SpellEffectBefundArt.profilIdFehlt),
      );
      expect(
        _arten([_profil({}), _profil({})]),
        contains(SpellEffectBefundArt.profilIdDoppelt),
      );
    });

    test('Quelle und Version sind Pflicht', () {
      expect(
        _arten([_profil({'beleg': <String, dynamic>{}})]),
        contains(SpellEffectBefundArt.quelleFehlt),
      );
      expect(
        _arten([_profil({'profilVersion': 0})]),
        contains(SpellEffectBefundArt.versionUngueltig),
      );
    });

    test('unbekannter Status wird gemeldet und behält den Rohwert', () {
      final profil = _profil({'status': 'zukunft'});
      expect(profil.status, SpellEffectStatus.unbekannt);
      expect(profil.toJson()['status'], 'zukunft');
      expect(_arten([profil]), contains(SpellEffectBefundArt.statusUnbekannt));
    });

    test('Bestandsprofil braucht eine bekannte Umsetzung', () {
      expect(
        _arten([_profil({'status': 'bestand'})]),
        contains(SpellEffectBefundArt.bestandOhneUmsetzung),
      );
      expect(
        _arten([
          _profil({
            'status': 'bestand',
            'legacyEffektId': activeSpellEffectArmatrutz,
          }),
        ]),
        isEmpty,
      );
      expect(
        _arten([
          _profil({'status': 'bestand', 'legacyEffektId': 'effect_spell_x'}),
        ]),
        contains(SpellEffectBefundArt.legacyEffektUnbekannt),
      );
    });

    test('Fulminictus gilt auch ohne Legacy-Effekt als Bestand', () {
      final katalog = RulesCatalog(
        version: 'test',
        source: 'test',
        talents: const [],
        spells: [_zauber(kFulminictusZauberId)],
        weapons: const [],
        spellEffects: [
          _profil({'spellId': kFulminictusZauberId, 'status': 'bestand'}),
        ],
      );
      expect(validiereSpellEffectProfile(katalog), isEmpty);
    });

    test('Legacy-Effekt ist nur bei Bestand erlaubt', () {
      expect(
        _arten([_profil({'legacyEffektId': activeSpellEffectAttributo})]),
        contains(SpellEffectBefundArt.legacyEffektOhneBestand),
      );
    });
  });

  group('istAutomatisiert', () {
    test('nur belegte und umgesetzte Profile', () {
      expect(istAutomatisiert(_profil({'status': 'belegt'})), isTrue);
      expect(istAutomatisiert(_profil({'status': 'bestand'})), isTrue);
    });

    test('manuelle und unbekannte Profile liefern nie Zahlen', () {
      expect(istAutomatisiert(_profil({'status': 'manuell'})), isFalse);
      expect(istAutomatisiert(_profil({'status': 'zukunft'})), isFalse);
      expect(istAutomatisiert(_profil({'status': ''})), isFalse);
    });
  });

  group('Abfragen', () {
    test('profileFuerZauber liefert nur Profile des Zaubers', () {
      final katalog = _katalog([
        _profil({'id': 'a', 'spellId': 'spell_x'}),
        _profil({'id': 'b', 'spellId': 'spell_y'}),
      ]);
      expect(profileFuerZauber(katalog, 'spell_x').map((p) => p.id), ['a']);
      expect(profileFuerZauber(katalog, 'spell_z'), isEmpty);
    });

    test('profilFuerLegacyEffekt ignoriert leere IDs', () {
      final katalog = _katalog([
        _profil({
          'status': 'bestand',
          'legacyEffektId': activeSpellEffectAxxeleratus,
        }),
      ]);
      expect(profilFuerLegacyEffekt(katalog, ''), isNull);
      expect(
        profilFuerLegacyEffekt(katalog, activeSpellEffectAxxeleratus)?.id,
        'profil_x',
      );
    });
  });
}
