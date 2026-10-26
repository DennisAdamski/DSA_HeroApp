import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/lernkosten_faktor_rules.dart';

import '../test_support/real_catalog.dart';

/// Hexalogie, Gedächtnis-Vorteile und Lehrmeister-Grenzen in den
/// Steigerungsoptionen (Wege der Zauberei S. 74/384, Wege der Helden S. 251/253,
/// Hausregel „Lehrmeister“).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RulesCatalog catalog;

  setUpAll(() async {
    catalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  HeroSheet held({
    String vorteile = '',
    Map<String, HeroSpellEntry> spells = const {},
    Map<String, HeroTalentEntry> talents = const {},
    List<String> merkmalskenntnisse = const [],
  }) => HeroSheet(
    id: 'h',
    name: 'Test',
    level: 1,
    attributes: const Attributes(
      mu: 14,
      kl: 14,
      inn: 14,
      ch: 14,
      ff: 14,
      ge: 14,
      ko: 14,
      kk: 14,
    ),
    vorteileText: vorteile,
    spells: spells,
    talents: talents,
    merkmalskenntnisse: merkmalskenntnisse,
    representationen: const ['Mag'],
  );

  AdvancementOption option(HeroSheet hero, AdvancementKind kind, String id) =>
      resolveAdvancementOption(
        hero: hero,
        catalog: catalog,
        kind: kind,
        targetId: id,
      )!;

  const eintrag = HeroSpellEntry(
    learnedRepresentation: 'Mag',
    learnedTradition: 'Mag',
  );

  group('Hexalogie in der Steigerungsoption', () {
    final hero = held(
      spells: {
        'spell_wand_aus_flammen': eintrag.copyWith(spellValue: 9),
        'spell_wand_aus_erz': eintrag.copyWith(spellValue: 3),
      },
      merkmalskenntnisse: const ['Elementar (Erz)'],
    );

    test('Wand aus Erz: Spalte C, eine weitere leichter bis ZfW 9', () {
      final o = option(hero, AdvancementKind.spell, 'spell_wand_aus_erz');
      expect(o.learnCost, LearnCost.c);
      expect(o.lernregeln.erleichterungBisWert, 9);
      expect(o.lernregeln.hinweise.single, contains('bis ZfW 9'));
      expect(o.lernregeln.spaltenHerleitung, isNotNull);
    });

    test(
      'Wand aus Luft (Gegenelement von Erz): Spalte E, keine Erleichterung',
      () {
        final o = option(hero, AdvancementKind.spell, 'spell_wand_aus_luft');
        expect(o.learnCost, LearnCost.e);
        expect(o.lernregeln.erleichterungBisWert, isNull);
        // Der Erwerbsdialog nennt den Grund für die schwerere Spalte.
        expect(
          o.lernregeln.hinweise.where((h) => h.startsWith('Gegenelement:')),
          hasLength(1),
        );
      },
    );

    test('ohne Merkmalskenntnis gibt es keinen Nachteil für Luft', () {
      final o = option(
        held(spells: hero.spells),
        AdvancementKind.spell,
        'spell_wand_aus_luft',
      );
      expect(o.learnCost, LearnCost.d);
      expect(o.lernregeln.erleichterungBisWert, 9);
    });
  });

  group('Lernspalte von Sprachen und Schriften als Herleitung', () {
    test('Sprache ohne Besonderheit: Spalte aus dem Katalog', () {
      final hero = held().copyWith(muttersprache: 'spr_garethi');
      final o = option(hero, AdvancementKind.language, 'spr_garethi');
      final herleitung = o.lernregeln.spaltenHerleitung;
      expect(herleitung, isNotNull);
      // Muttersprache ist die verbilligte Spalte A.
      expect(o.learnCost, LearnCost.a);
      expect(herleitung!.wert, kLernkomplexitaeten.indexOf('A'));
      expect(herleitung.schritte.first.formel, 'Spalte A');
    });

    test(
      'Begabung für Sprachen senkt die Spalte, die Herleitung nennt sie',
      () {
        final hero = held(vorteile: 'Begabung für Talentgruppe Sprachen')
            .copyWith(muttersprache: 'spr_garethi');
        final ohne = option(
          held().copyWith(muttersprache: 'spr_garethi'),
          AdvancementKind.language,
          'spr_garethi',
        );
        final mit = option(hero, AdvancementKind.language, 'spr_garethi');
        final herleitung = mit.lernregeln.spaltenHerleitung!;
        expect(
          herleitung.wert,
          lessThan(ohne.lernregeln.spaltenHerleitung!.wert),
        );
        // Anzeige und Kosten stammen aus derselben Spalte.
        expect(kLernkomplexitaeten[herleitung.wert], 'A*');
        expect(mit.learnCost, LearnCost.z);
      },
    );

    test('Schrift hat dieselbe Herleitung wie das Talent', () {
      final o = option(held(), AdvancementKind.script, 'sch_altes_alaani');
      final herleitung = o.lernregeln.spaltenHerleitung;
      expect(herleitung, isNotNull);
      expect(herleitung!.schritte, isNotEmpty);
      expect(herleitung.wert, kLernkomplexitaeten.indexOf('A'));
    });
  });

  group('Gedächtnis-Vorteile', () {
    test('Gutes Gedächtnis: Zauber ja — Wissenstalent und Klettern nicht', () {
      final hero = held(vorteile: 'Gutes Gedächtnis I');
      final faktoren = option(
        hero,
        AdvancementKind.spell,
        'spell_balsam_salabunde',
      ).lernregeln.faktoren;
      expect(faktoren, hasLength(1));
      expect((faktoren.single.zaehler, faktoren.single.nenner), (3, 4));
      for (final id in <String>['tal_geographie', 'tal_klettern']) {
        expect(
          option(hero, AdvancementKind.talent, id).lernregeln.faktoren,
          isEmpty,
          reason: id,
        );
      }
    });

    test('Eidetisches Gedächtnis verbilligt auch Wissenstalente', () {
      final hero = held(vorteile: 'Eidetisches Gedächtnis');
      final faktoren = option(
        hero,
        AdvancementKind.talent,
        'tal_geographie',
      ).lernregeln.faktoren;
      expect(faktoren, hasLength(1));
      expect((faktoren.single.zaehler, faktoren.single.nenner), (1, 2));
    });

    test('Eidetisches Gedächtnis halbiert und geht vor Gutem Gedächtnis', () {
      final hero = held(vorteile: 'Eidetisches Gedächtnis; Gutes Gedächtnis I');
      final faktoren = lernkostenFaktoren(hero, LernzielArt.wissenstalent);
      expect(faktoren, hasLength(1));
      expect((faktoren.single.zaehler, faktoren.single.nenner), (1, 2));
    });

    test('ohne den Vorteil gibt es keinen Faktor', () {
      expect(lernkostenFaktoren(held(), LernzielArt.wissenstalent), isEmpty);
    });
  });

  group('Lehrmeister', () {
    test('nur bei Talenten und Zauberfertigkeiten (Hausregel)', () {
      final hero = held();
      expect(
        option(
          hero,
          AdvancementKind.talent,
          'tal_klettern',
        ).lehrmeisterMoeglich,
        isTrue,
      );
      expect(
        option(
          hero,
          AdvancementKind.spell,
          'spell_balsam_salabunde',
        ).lehrmeisterMoeglich,
        isTrue,
      );
      expect(
        option(hero, AdvancementKind.attribute, 'mu').lehrmeisterMoeglich,
        isFalse,
      );
      expect(
        option(hero, AdvancementKind.boughtStat, 'lep').lehrmeisterMoeglich,
        isFalse,
      );
    });
  });
}
