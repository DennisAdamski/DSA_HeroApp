import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_source_breakdown.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

HeroSheet _held(HeroBackground background, {List<HeroMerkmal>? vorteile}) {
  return HeroSheet(
    id: 'h',
    name: 'Held',
    level: 1,
    attributes: const Attributes.zero(),
    background: background,
    vorteilEintraege: vorteile ?? const <HeroMerkmal>[],
  );
}

HeroBackground _mitEintraegen(
  HeroBackground basis,
  HeroHerkunft herkunft,
  List<HeroHerkunftsModifikator> eintraege,
) {
  final container = basis.herkunftsModifikatoren!;
  return basis.copyWith(
    herkunftsModifikatoren: switch (herkunft) {
      HeroHerkunft.rasse => container.copyWith(rasse: eintraege),
      HeroHerkunft.kultur => container.copyWith(kultur: eintraege),
      HeroHerkunft.profession => container.copyWith(profession: eintraege),
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('strukturierte Liste führt', () {
    test('Liste führt und nullsummierte AsP aktivieren weiterhin', () {
      var background = herkunftZumSpeichern(
        const HeroBackground(
          rasseModText: 'MU+1',
          professionModText: 'ASP+1, ASP-1',
        ),
      );
      final container = background.herkunftsModifikatoren!;
      background = background.copyWith(
        herkunftsModifikatoren: container.copyWith(
          rasse: [container.rasse.single.copyWith(betrag: 3)],
        ),
      );
      final hero = _held(background);
      final mods = parseModifierTextsForHero(hero, catalog: null);
      expect(mods.attributeMods.mu, 3);
      expect(mods.startAttributeMods.mu, 3);
      expect(mods.statMods.asp, 0);
      expect(hasAutomaticMagicActivation(hero, catalog: null), isTrue);
      expect(hasAutomaticDivineActivation(hero, catalog: null), isFalse);
    });

    test('geaendertes Ziel führt, der veraltete Text zaehlt nicht', () {
      var background = herkunftZumSpeichern(
        const HeroBackground(kulturModText: 'KL+2'),
      );
      final eintrag = background.herkunftsModifikatoren!.kultur.single;
      background = _mitEintraegen(background, HeroHerkunft.kultur, [
        eintrag.copyWith(ziel: 'KK'),
      ]);
      final mods = parseModifierTextsForHero(_held(background), catalog: null);
      expect(mods.attributeMods.kl, 0);
      expect(mods.attributeMods.kk, 2);
      expect(mods.startAttributeMods.kk, 2);
    });

    test('Aktivierung folgt den Codes, nicht der Summe', () {
      for (final text in <String>['ASP+0', 'AE-2', 'ASP+1, AE-1']) {
        final hero = _held(
          herkunftZumSpeichern(HeroBackground(professionModText: text)),
        );
        expect(
          hasAutomaticMagicActivation(hero, catalog: null),
          isTrue,
          reason: text,
        );
        expect(hasAutomaticDivineActivation(hero, catalog: null), isFalse);
      }
      for (final text in <String>['KAP+0', 'KE-3', 'KAP+2, KE-2']) {
        final hero = _held(
          herkunftZumSpeichern(HeroBackground(kulturModText: text)),
        );
        expect(
          hasAutomaticDivineActivation(hero, catalog: null),
          isTrue,
          reason: text,
        );
        expect(hasAutomaticMagicActivation(hero, catalog: null), isFalse);
      }
    });

    test('alle Aliase wirken wie im Textweg', () {
      const text = 'AE+1, KE+2, LE+3, AW+1, AU+4, MR-1, INI+1, GS+1';
      final strukturiert = _held(
        herkunftZumSpeichern(const HeroBackground(rasseModText: text)),
      );
      final alsText = _held(const HeroBackground(rasseModText: text));
      final a = parseModifierTextsForHero(strukturiert, catalog: null);
      final b = parseModifierTextsForHero(alsText, catalog: null);
      expect(a.statMods.toJson(), b.statMods.toJson());
      expect(a.statMods.asp, 1);
      expect(a.statMods.kap, 2);
      expect(a.statMods.lep, 3);
      expect(a.statMods.ausweichen, 1);
    });

    test('Quellenaufschluesselung nimmt dieselbe Auswertung', () {
      var background = herkunftZumSpeichern(
        const HeroBackground(
          rasseModText: 'MU+1',
          kulturModText: 'LEP+2',
          professionModText: 'KK+1',
        ),
      );
      final rasse = background.herkunftsModifikatoren!.rasse.single;
      background = _mitEintraegen(background, HeroHerkunft.rasse, [
        rasse.copyWith(betrag: 4),
      ]);
      final breakdown = computeModifierSourceBreakdown(
        _held(background),
        catalog: null,
      );
      expect(breakdown.rasseAttributeMods.mu, 4);
      expect(breakdown.kulturStatMods.lep, 2);
      expect(breakdown.professionAttributeMods.kk, 1);
    });
  });

  group('Fallbacks und Doppelwirkung', () {
    test('unbekannte Art wirkt genau einmal über den Text', () {
      final container = HeroHerkunftsModifikatoren.fromJson(<String, Object?>{
        'formatVersion': 1,
        'rasse': <Object?>[
          <String, Object?>{
            'id': 'a',
            'art': 'zukunft',
            'ziel': 'MU',
            'betrag': 9,
            'text': 'KL+2',
          },
        ],
        'kultur': <Object?>[],
        'profession': <Object?>[],
      });
      final mods = parseModifierTextsForHero(
        _held(HeroBackground(herkunftsModifikatoren: container)),
        catalog: null,
      );
      expect(mods.attributeMods.kl, 2);
      expect(mods.attributeMods.mu, 0);
      expect(mods.startAttributeMods.kl, 2);
    });

    test('unbrauchbares Ziel faellt einmal auf den Text zurück', () {
      final container = HeroHerkunftsModifikatoren(
        rasse: [
          const HeroHerkunftsModifikator(
            id: 'a',
            art: HeroHerkunftsModifikatorArt.eigenschaft,
            ziel: 'ZZ',
            betrag: 7,
            text: 'MU+2',
          ),
          const HeroHerkunftsModifikator(
            id: 'b',
            art: HeroHerkunftsModifikatorArt.basiswert,
            ziel: 'ZZ',
            betrag: 7,
            text: 'Hausnotiz',
          ),
        ],
      );
      final hero = _held(HeroBackground(herkunftsModifikatoren: container));
      final mods = parseModifierTextsForHero(hero, catalog: null);
      expect(mods.attributeMods.mu, 2);
      expect(mods.unknownFragments, ['Hausnotiz']);
    });

    test('unbekannte Fragmente erscheinen einmal und in Quellreihenfolge', () {
      final hero = _held(
        herkunftZumSpeichern(
          const HeroBackground(
            rasseModText: 'Rassenmerkmal, MU+1',
            kulturModText: 'Rassenmerkmal, Kulturmerkmal',
          ),
        ),
      );
      final mods = parseModifierTextsForHero(hero, catalog: null);
      expect(mods.unknownFragments, ['Rassenmerkmal', 'Kulturmerkmal']);
    });

    test('benannte Vorteile in der Herkunft wirken und aktivieren nicht', () {
      final hero = _held(
        herkunftZumSpeichern(
          const HeroBackground(rasseModText: 'Astralmacht 2, Flink'),
        ),
      );
      final mods = parseModifierTextsForHero(hero, catalog: null);
      expect(mods.statMods.asp, 0);
      expect(mods.hasFlinkFromVorteile, isFalse);
      expect(mods.unknownFragments, ['Astralmacht 2', 'Flink']);
      expect(hasAutomaticMagicActivation(hero, catalog: null), isFalse);
    });

    test('reine Merkmalsherkunft ändert keine Wirkung', () {
      const ohne = HeroMerkmal(katalogId: '', text: 'LEP+2');
      final mit = ohne.copyWith(herkunft: HeroHerkunft.rasse);
      final a = parseModifierTextsForHero(
        _held(const HeroBackground(), vorteile: [ohne]),
        catalog: null,
      );
      final b = parseModifierTextsForHero(
        _held(const HeroBackground(), vorteile: [mit]),
        catalog: null,
      );
      expect(a.statMods.toJson(), b.statMods.toJson());
      expect(b.statMods.lep, 2);
      expect(b.startAttributeMods.toJson(), a.startAttributeMods.toJson());
    });

    test('unbekannte Containerversion rechnet über die drei Texte', () {
      final roh = HeroHerkunftsModifikatoren.fromJson(<String, Object?>{
        'formatVersion': 900,
      });
      final hero = _held(
        HeroBackground(
          rasseModText: 'MU+1',
          professionModText: 'ASP+2',
          herkunftsModifikatoren: roh,
        ),
      );
      final mods = parseModifierTextsForHero(hero, catalog: null);
      expect(mods.attributeMods.mu, 1);
      expect(mods.statMods.asp, 2);
      expect(hasAutomaticMagicActivation(hero, catalog: null), isTrue);
      expect(werteHerkunftAus(hero.background).brauchtPruefung, isFalse);
    });

    test(
      'nicht verstandene Gruppe rechnet über ihren Text, andere strukturiert',
      () {
        final container = HeroHerkunftsModifikatoren.fromJson(<String, Object?>{
          'formatVersion': 1,
          'rasse': 'unlesbar',
          'kultur': <Object?>[
            <String, Object?>{
              'id': 'k',
              'art': 'eigenschaft',
              'ziel': 'KL',
              'betrag': 2,
            },
          ],
          'profession': <Object?>[],
        });
        final hero = _held(
          HeroBackground(
            rasseModText: 'MU+1',
            kulturModText: 'KL+9',
            herkunftsModifikatoren: container,
          ),
        );
        final auswertung = werteHerkunftAus(hero.background);
        final mods = parseModifierTextsForHero(hero, catalog: null);
        expect(mods.attributeMods.mu, 1);
        expect(mods.attributeMods.kl, 2);
        expect(auswertung.fuer(HeroHerkunft.rasse).brauchtPruefung, isTrue);
        expect(auswertung.fuer(HeroHerkunft.kultur).brauchtPruefung, isFalse);
      },
    );

    test('nicht verstandener Eintrag wirkt über sein Textfeld', () {
      final container = HeroHerkunftsModifikatoren.fromJson(<String, Object?>{
        'formatVersion': 1,
        'rasse': <Object?>[
          <String, Object?>{
            'id': 'a',
            'art': 'frei',
            'betrag': 1.5,
            'text': 'MU+2',
          },
          'kein Objekt',
        ],
        'kultur': <Object?>[],
        'profession': <Object?>[],
      });
      final auswertung = werteHerkunftAus(
        HeroBackground(herkunftsModifikatoren: container),
      );
      expect(
        auswertung.fuer(HeroHerkunft.rasse).modifikatoren.attributeMods.mu,
        2,
      );
      expect(auswertung.brauchtPruefung, isTrue);
    });
  });

  group('Bestandsfixtures vor und nach der Migration', () {
    late EchterKatalog katalog;

    setUpAll(() async {
      katalog = await ladeEchtenRegelkatalog();
    });

    Map<String, Object?> projektion(
      Bestandsheld held, {
      required bool migriert,
    }) {
      final bundle = ladeBestandsheld(held);
      final hero = migriert
          ? bundle.hero.copyWith(
              background: herkunftZumSpeichern(bundle.hero.background),
            )
          : bundle.hero;
      final snapshot = buildHeroComputedSnapshot(
        hero: hero,
        state: bundle.state,
        catalog: katalog.catalog,
        epicAdvantagesActive: katalog.epicAdvantagesActive,
      );
      final parsed = parseModifierTextsForHero(hero, catalog: katalog.catalog);
      final quellen = computeModifierSourceBreakdown(
        hero,
        catalog: katalog.catalog,
      );
      final basis = snapshot.derivedStats;
      return <String, Object?>{
        'eigenschaften': snapshot.effectiveAttributes.toJson(),
        'startwerte': computeHeroEffectiveStartAttributes(
          hero,
          catalog: katalog.catalog,
        ).toJson(),
        'maxima': snapshot.attributeMaximums.toJson(),
        'maxLep': basis.maxLep,
        'maxAu': basis.maxAu,
        'maxAsp': basis.maxAsp,
        'maxKap': basis.maxKap,
        'mr': basis.mr,
        'iniBase': basis.iniBase,
        'gs': basis.gs,
        'ausweichen': basis.ausweichen,
        'magie': snapshot.resourceActivation.magic.isEnabled,
        'karma': snapshot.resourceActivation.divine.isEnabled,
        'autoMagie': hasAutomaticMagicActivation(
          hero,
          catalog: katalog.catalog,
        ),
        'autoKarma': hasAutomaticDivineActivation(
          hero,
          catalog: katalog.catalog,
        ),
        'unbekannt': parsed.unknownFragments,
        'statMods': parsed.statMods.toJson(),
        'attributMods': parsed.attributeMods.toJson(),
        'startMods': parsed.startAttributeMods.toJson(),
        'quellen': <String, Object?>{
          'rasse': quellen.rasseStatMods.toJson(),
          'kultur': quellen.kulturStatMods.toJson(),
          'profession': quellen.professionStatMods.toJson(),
          'rasseA': quellen.rasseAttributeMods.toJson(),
          'kulturA': quellen.kulturAttributeMods.toJson(),
          'professionA': quellen.professionAttributeMods.toJson(),
        },
      };
    }

    for (final held in Bestandsheld.values) {
      test('${held.datei}: Migration ändert keinen Regelwert', () {
        expect(
          projektion(held, migriert: true),
          projektion(held, migriert: false),
        );
      });
    }
  });
}
