import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_style.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
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
  String familieHerkunftHintergrund = '',
  String stand = '',
  String titel = '',
  int sozialstatus = 0,
  String vorteileText = '',
  String nachteileText = '',
  CombatConfig combatConfig = const CombatConfig(),
  Map<String, HeroSpellEntry> spells = const <String, HeroSpellEntry>{},
  List<String> representationen = const <String>[],
  List<HeroInventoryEntry> inventoryEntries = const <HeroInventoryEntry>[],
}) {
  return HeroSheet(
    id: 'test-id',
    name: 'Testheld',
    level: 1,
    attributes: const Attributes(
      mu: 11,
      kl: 11,
      inn: 11,
      ch: 11,
      ff: 11,
      ge: 11,
      ko: 11,
      kk: 11,
    ),
    background: HeroBackground(
      rasse: rasse,
      kultur: kultur,
      profession: profession,
      familieHerkunftHintergrund: familieHerkunftHintergrund,
      stand: stand,
      titel: titel,
      sozialstatus: sozialstatus,
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
    vorteileText: vorteileText,
    nachteileText: nachteileText,
    combatConfig: combatConfig,
    spells: spells,
    representationen: representationen,
    inventoryEntries: inventoryEntries,
  );
}

void main() {
  group('buildAvatarPrompt', () {
    test('enthaelt Rasse und Geschlecht', () {
      final hero = _makeHero(rasse: 'Halbelfe', geschlecht: 'weiblich');
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(prompt, contains('half-elf'));
      expect(prompt, contains('female'));
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

    test('parst lokalisierte Alters-, Groessen- und Gewichtsangaben', () {
      final hero = _makeHero(
        alter: '19 J. 27. Travia 1003 BF',
        groesse: '1,74',
        gewicht: '54 Stein',
      );
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(prompt, contains('young adult'));
      expect(prompt, contains('slender build'));
    });

    test('enthaelt Status- und Persoenlichkeitshinweise aus Whitelist', () {
      final hero = _makeHero(
        sozialstatus: 9,
        vorteileText: 'Herausragendes Aussehen, Flink, Guter Ruf 2',
        nachteileText: 'Arroganz 9, Eitelkeit 6, Prinzipientreue 10',
      );
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(prompt, contains('high-status, refined presentation'));
      expect(prompt, contains('striking beauty'));
      expect(prompt, contains('proud, self-assured bearing'));
      expect(prompt, contains('disciplined, composed presence'));
    });

    test('enthaelt ikonische Ausruestung ohne Duplikate', () {
      final hero = _makeHero(
        combatConfig: const CombatConfig(
          weapons: <MainWeaponSlot>[
            MainWeaponSlot(name: 'Amazonenzahn', weaponType: 'Amazonensaebel'),
          ],
          selectedWeaponIndex: 0,
          offhandEquipment: <OffhandEquipmentEntry>[
            OffhandEquipmentEntry(name: 'Kriegsfaecher'),
          ],
        ),
        inventoryEntries: const <HeroInventoryEntry>[
          HeroInventoryEntry(gegenstand: 'Kriegsfaecher'),
          HeroInventoryEntry(gegenstand: 'Kampfhandschuhe aus Pantherpranken'),
        ],
      );
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(prompt, contains('an ornate curved saber with a fang-like blade'));
      expect(prompt, contains('a bladed war fan'));
      expect('a bladed war fan'.allMatches(prompt).length, 1);
      expect(prompt, isNot(contains('panther-claw gauntlets')));
    });

    test('enthaelt subtilen Magiehinweis bei Axxeleratus', () {
      final hero = _makeHero(
        representationen: const <String>['Mag'],
        spells: const <String, HeroSpellEntry>{
          'spell_axxeleratus_blitzgeschwind': HeroSpellEntry(spellValue: 12),
        },
      );
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(
        prompt,
        contains(
          'subtle impression of supernatural speed and controlled motion',
        ),
      );
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

    test('ignoriert unbrauchbare Formatangaben ohne Artefakte', () {
      final hero = _makeHero(
        alter: 'jung',
        groesse: 'sehr gross',
        gewicht: 'federleicht',
      );
      final prompt = buildAvatarPrompt(
        hero: hero,
        style: AvatarStyle.fantasyIllustration,
      );

      expect(prompt, isNot(contains('build')));
      expect(prompt, isNot(contains('young adult')));
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

    test('Halbelf wird vor Elf-Fallback erkannt', () {
      expect(mapRaceToVisualDescription('Halbelfe'), contains('half-elf'));
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
