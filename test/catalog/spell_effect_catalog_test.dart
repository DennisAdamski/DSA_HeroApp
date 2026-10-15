import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_profile_rules.dart';

import '../test_support/real_catalog.dart';
import 'catalog_reference_names.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('spell_effects.json (Rohdatei)', () {
    final rohProfile = ladeKatalogDatei('spell_effects.json');
    final zauberIds = <String>{
      for (final zauber in ladeKatalogDatei('magie.json')) '${zauber['id']}',
    };

    test('jedes Profil zeigt auf einen existierenden Zauber', () {
      for (final profil in rohProfile) {
        expect(
          zauberIds,
          contains(profil['spellId']),
          reason: 'Profil ${profil['id']}',
        );
      }
    });

    test('Profil-IDs sind eindeutig und gesetzt', () {
      final ids = rohProfile.map((profil) => '${profil['id']}').toList();
      expect(ids.every((id) => id.isNotEmpty && id != 'null'), isTrue);
      expect(ids.toSet().length, ids.length);
    });

    test('Wirkungs- und Variantentexte werden nicht kopiert', () {
      for (final profil in rohProfile) {
        expect(profil.containsKey('wirkung'), isFalse);
        expect(profil.containsKey('variants'), isFalse);
      }
    });

    test('Startliste ist vollständig vorhanden', () {
      final spellIds = rohProfile.map((profil) => profil['spellId']).toSet();
      expect(
        spellIds,
        containsAll(<String>[
          'spell_axxeleratus_blitzgeschwind',
          'spell_attributo',
          'spell_armatrutz',
          kFulminictusZauberId,
          'spell_falkenauge_meisterschuss',
          'spell_adlerauge_luchsenohr',
          'spell_psychostabilis',
          'spell_blitz_dich_find',
          'spell_plumbumbarum_schwerer_arm',
          'spell_aengste_lindern',
        ]),
      );
    });
  });

  group('spell_effects im echten Katalog', () {
    late RulesCatalog katalog;

    setUpAll(() async {
      katalog = (await ladeEchtenRegelkatalog()).catalog;
    });

    test('Profile werden aus dem Manifest geladen', () {
      expect(katalog.spellEffects, hasLength(14));
    });

    test('die Profilprüfung findet keinen Mangel', () {
      expect(validiereSpellEffectProfile(katalog), isEmpty);
    });

    test('die drei Bestandseffekte sind über ihre Legacy-ID auffindbar', () {
      final erwartet = <String, String>{
        activeSpellEffectAxxeleratus: 'spell_axxeleratus_blitzgeschwind',
        activeSpellEffectAttributo: 'spell_attributo',
        activeSpellEffectArmatrutz: 'spell_armatrutz',
      };
      erwartet.forEach((legacyId, spellId) {
        final profil = profilFuerLegacyEffekt(katalog, legacyId);
        expect(profil, isNotNull, reason: legacyId);
        expect(profil!.spellId, spellId);
        expect(profil.status, SpellEffectStatus.bestand);
      });
    });

    test('Bestandsprofile sind genau die vier umgesetzten Zauber', () {
      final bestand = katalog.spellEffects
          .where((profil) => profil.status == SpellEffectStatus.bestand)
          .map((profil) => profil.spellId)
          .toSet();
      expect(bestand, <String>{
        'spell_axxeleratus_blitzgeschwind',
        'spell_attributo',
        'spell_armatrutz',
        kFulminictusZauberId,
      });
    });

    test('toJson/fromJson erhält jedes Profil', () {
      final erneut = RulesCatalog.fromJson(katalog.toJson());
      expect(
        erneut.spellEffects.map((profil) => profil.toJson()).toList(),
        katalog.spellEffects.map((profil) => profil.toJson()).toList(),
      );
    });
  });
}
