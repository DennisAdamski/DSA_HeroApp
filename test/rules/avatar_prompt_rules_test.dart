import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_style.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_prompt_rules.dart';
import 'package:flutter_test/flutter_test.dart';

HeroSheet _makeHero({
  String rasse = '',
  String kultur = '',
  String profession = '',
  String geschlecht = '',
  String alter = '',
  String groesse = '',
  String gewicht = '',
  String haarfarbe = '',
  String augenfarbe = '',
  String aussehen = '',
}) {
  return HeroSheet(
    id: 'test-id',
    name: 'Testheld',
    level: 1,
    attributes: const Attributes(
      mu: 11, kl: 11, inn: 11, ch: 11, ff: 11, ge: 11, ko: 11, kk: 11,
    ),
    background: HeroBackground(
      rasse: rasse,
      kultur: kultur,
      profession: profession,
    ),
    appearance: HeroAppearance(
      geschlecht: geschlecht,
      alter: alter,
      groesse: groesse,
      gewicht: gewicht,
      haarfarbe: haarfarbe,
      augenfarbe: augenfarbe,
      aussehen: aussehen,
    ),
  );
}

void main() {
  group('buildAvatarPrompt', () {
    test('enthaelt Rasse und Geschlecht', () {
      final hero = _makeHero(rasse: 'Elf', geschlecht: 'maennlich');
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(prompt, contains('elf'));
      expect(prompt, contains('male'));
    });

    test('enthaelt Haarfarbe und Augenfarbe', () {
      final hero = _makeHero(haarfarbe: 'rot', augenfarbe: 'gruen');
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.watercolor,
      );

      expect(prompt, contains('rot hair'));
      expect(prompt, contains('gruen eyes'));
    });

    test('enthaelt Zusatzbeschreibung', () {
      final hero = _makeHero();
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.penAndInk,
        additionalDescription: 'Narbe ueber dem linken Auge',
      );

      expect(prompt, contains('Narbe ueber dem linken Auge'));
    });

    test('enthaelt Stil-Fragment', () {
      final hero = _makeHero();
      for (final style in AvatarStyle.values) {
        final prompt = buildAvatarPrompt(hero: hero, style: style);
        expect(prompt, contains(style.promptFragment));
      }
    });

    test('enthaelt Koerperbau aus Groesse und Gewicht', () {
      final hero = _makeHero(groesse: '195', gewicht: '70');
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(prompt, contains('very tall'));
      expect(prompt, contains('slender build'));
    });

    test('enthaelt negative Guidance', () {
      final hero = _makeHero();
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(prompt, contains('No text'));
      expect(prompt, contains('no watermark'));
    });

    test('funktioniert mit komplett leerem Held', () {
      final hero = _makeHero();
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(prompt, isNotEmpty);
      expect(prompt, contains('portrait'));
    });
  });

  group('mapRaceToVisualDescription', () {
    test('Elf wird erkannt', () {
      expect(mapRaceToVisualDescription('Elf'), contains('elf'));
      expect(mapRaceToVisualDescription('Waldelf'), contains('elf'));
    });

    test('Zwerg wird erkannt', () {
      expect(mapRaceToVisualDescription('Zwerg'), contains('dwarf'));
    });

    test('Achaz wird erkannt', () {
      expect(mapRaceToVisualDescription('Achaz'), contains('reptilian'));
    });

    test('Mensch als Fallback', () {
      expect(mapRaceToVisualDescription('Mensch'), contains('human'));
    });

    test('leerer String liefert leeren String', () {
      expect(mapRaceToVisualDescription(''), isEmpty);
    });
  });

  group('mapGenderToDescription', () {
    test('weiblich wird erkannt', () {
      expect(mapGenderToDescription('weiblich'), 'female');
      expect(mapGenderToDescription('w'), 'female');
    });

    test('maennlich wird erkannt', () {
      expect(mapGenderToDescription('maennlich'), 'male');
      expect(mapGenderToDescription('m'), 'male');
    });

    test('leerer String liefert leeren String', () {
      expect(mapGenderToDescription(''), isEmpty);
    });
  });
}

