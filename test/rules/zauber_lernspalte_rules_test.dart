import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/hexalogie_katalog.dart';
import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_begabung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/zauber_lernspalte_rules.dart';

import '../test_support/real_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  SpellDef zauber(String id) =>
      katalog.catalog.spells.firstWhere((s) => s.id == id);

  ZauberLernspalte spalteFuer(
    String id, {
    required Map<String, HeroSpellEntry> hero,
    List<String> merkmalskenntnisse = const <String>[],
    Set<String> begabteMerkmale = const <String>{},
    bool harmonisiert = false,
    int fremd = 0,
    LernspaltenBefund befund = LernspaltenBefund.keiner,
  }) => zauberLernspalte(
    spell: zauber(id),
    eintrag: hero[id],
    fremdeReprSpalten: fremd,
    befund: befund,
    merkmalskenntnisse: merkmalskenntnisse,
    begabteMerkmale: begabteMerkmale,
    elementarharmonisiert: harmonisiert,
    zauber: hero,
  );

  group('Beispiel aus Wege der Zauberei S. 385 (Rafik, Wand aus …)', () {
    // WAND AUS FEUER ZfW 9, WAND AUS ERZ ZfW 3, Merkmalskenntnis Erz.
    final hero = <String, HeroSpellEntry>{
      'spell_wand_aus_flammen': const HeroSpellEntry(spellValue: 9),
      'spell_wand_aus_erz': const HeroSpellEntry(spellValue: 3),
    };
    const mk = <String>['Elementar (Erz)'];

    test('der Zauber mit dem höchsten ZfW wird normal gesteigert (D)', () {
      final s = spalteFuer(
        'spell_wand_aus_flammen',
        hero: hero,
        merkmalskenntnisse: mk,
      );
      expect(s.spalte, 'D');
      // Der höchste andere Zauber ist ERZ mit ZfW 3: bis dahin wäre eine
      // Erleichterung möglich, der Zauber selbst steht aber schon darüber.
      expect(s.hexalogieBisWert, 3);
    });

    test(
      'Wand aus Erz: Merkmalskenntnis (C) und Hexalogie ergeben Spalte B',
      () {
        final s = spalteFuer(
          'spell_wand_aus_erz',
          hero: hero,
          merkmalskenntnisse: mk,
        );
        expect(s.spalte, 'C');
        expect(s.hexalogieBisWert, 9);
        final kosten = berechneSteigerungskosten(
          vonWert: 3,
          aufWert: 5,
          effektiveKomplexitaet: learnCostFromKomplexitaet(s.spalte)!,
          erleichterungBisWert: s.hexalogieBisWert,
        );
        // Spalte C minus Hexalogie = Spalte B für beide Schritte.
        expect(
          kosten.apKosten,
          LearnCost.b.costForStep(3) + LearnCost.b.costForStep(4),
        );
      },
    );

    test('Wand aus Luft (Gegenelement): Spalte E, keine Hexalogie', () {
      final s = spalteFuer(
        'spell_wand_aus_luft',
        hero: hero,
        merkmalskenntnisse: mk,
      );
      expect(s.spalte, 'E');
      expect(s.hexalogieBisWert, isNull);
      expect(s.hexalogieHinweis, contains('Gegenelement'));
      expect(s.gegenelementHinweis, contains('bevorzugt Erz'));
      expect(s.gegenelementHinweis, contains('Elementarharmonisierte Aura'));
      expect(
        s.herleitung.schritte
            .singleWhere((x) => x.bezeichnung == kSpalteGegenelementSchritt)
            .betrag,
        1,
      );
    });

    test('Dornen, Wasser und Gletscher: Spalte D, eine leichter bis ZfW 9', () {
      for (final id in <String>[
        'spell_wand_aus_dornen',
        'spell_wand_aus_wasser',
        'spell_gletscherwand',
      ]) {
        final s = spalteFuer(id, hero: hero, merkmalskenntnisse: mk);
        expect(s.spalte, 'D', reason: id);
        expect(s.hexalogieBisWert, 9, reason: id);
      }
    });

    test('Elementarharmonisierte Aura hebt den Nachteil auf', () {
      final s = spalteFuer(
        'spell_wand_aus_luft',
        hero: hero,
        merkmalskenntnisse: mk,
        harmonisiert: true,
      );
      expect(s.spalte, 'D');
      expect(s.hexalogieBisWert, 9);
      expect(s.gegenelementHinweis, isNull);
    });
  });

  group('Gegenelement', () {
    test('Paare nach dem Siegel der Elemente', () {
      expect(Magieelement.feuer.gegenelement, Magieelement.wasser);
      expect(Magieelement.erz.gegenelement, Magieelement.luft);
      expect(Magieelement.humus.gegenelement, Magieelement.eis);
      for (final e in Magieelement.values) {
        expect(e.gegenelement.gegenelement, e);
      }
    });

    test('Begabung für ein Element wirkt wie die Merkmalskenntnis', () {
      final s = spalteFuer(
        'spell_wand_aus_luft',
        hero: const <String, HeroSpellEntry>{},
        begabteMerkmale: <String>{'elementar (erz)'},
      );
      expect(s.spalte, 'E');
    });

    test('Elementar (allgemein) löst keinen Nachteil aus', () {
      final s = spalteFuer(
        'spell_wand_aus_luft',
        hero: const <String, HeroSpellEntry>{},
        merkmalskenntnisse: const <String>['Elementar (allgemein)'],
      );
      expect(s.spalte, 'D');
    });

    test('Zauber mit zwei Elementen: das Gegenelement zählt wörtlich', () {
      // Nebelleib trägt Luft und Wasser; Wasser ist das Gegenelement von Feuer
      // (WdZ S. 381: „alle Zauber, die das Merkmal des Gegenelementes tragen“).
      final s = spalteFuer(
        'spell_nebelleib',
        hero: const <String, HeroSpellEntry>{},
        merkmalskenntnisse: const <String>['Elementar (Feuer)'],
      );
      expect(
        s.herleitung.schritte
            .singleWhere((x) => x.bezeichnung == kSpalteGegenelementSchritt)
            .betrag,
        1,
      );
      expect(s.gegenelementHinweis, contains('bevorzugt Feuer'));

      final harmonisiert = spalteFuer(
        'spell_nebelleib',
        hero: const <String, HeroSpellEntry>{},
        merkmalskenntnisse: const <String>['Elementar (Feuer)'],
        harmonisiert: true,
      );
      expect(harmonisiert.gegenelementHinweis, isNull);
    });

    test('ohne Gegenelement unter den Merkmalen bleibt es bei 0', () {
      final s = spalteFuer(
        'spell_nebelleib',
        hero: const <String, HeroSpellEntry>{},
        merkmalskenntnisse: const <String>['Elementar (Humus)'],
      );
      expect(
        s.herleitung.schritte
            .singleWhere((x) => x.bezeichnung == kSpalteGegenelementSchritt)
            .betrag,
        0,
      );
    });
  });

  group('Hexalogie ohne Geschwister', () {
    test('ohne weiteren gelernten Zauber gibt es keine Erleichterung', () {
      final s = spalteFuer(
        'spell_ignifaxius',
        hero: const <String, HeroSpellEntry>{
          'spell_ignifaxius': HeroSpellEntry(spellValue: 5),
        },
      );
      expect(s.hexalogieBisWert, isNull);
      expect(s.hexalogieHinweis, contains('Sobald ein weiterer Zauber'));
    });

    test('nicht aktivierte Geschwister zählen nicht', () {
      final s = spalteFuer(
        'spell_ignifaxius',
        hero: const <String, HeroSpellEntry>{
          'spell_archofaxius': HeroSpellEntry(),
        },
      );
      expect(s.hexalogieBisWert, isNull);
    });

    test('ein aktivierter Zauber mit ZfW 0 erleichtert die Aktivierung', () {
      final s = spalteFuer(
        'spell_ignifaxius',
        hero: const <String, HeroSpellEntry>{
          'spell_archofaxius': HeroSpellEntry(spellValue: 0),
        },
      );
      expect(s.hexalogieBisWert, 0);
    });

    test('ein Zauber ohne Hexalogie hat keinen Hinweis', () {
      final s = spalteFuer(
        'spell_armatrutz',
        hero: const <String, HeroSpellEntry>{},
      );
      expect(s.hexalogie, isNull);
      expect(s.hexalogieHinweis, isNull);
    });
  });

  group('Spaltenherleitung', () {
    test('Summe der Schritte ist der Index der Spalte', () {
      for (final spell in katalog.catalog.spells) {
        for (final fremd in const [0, 1, 2, 3]) {
          for (final haus in const [false, true]) {
            final s = zauberLernspalte(
              spell: spell,
              eintrag: HeroSpellEntry(hauszauber: haus, gifted: haus),
              fremdeReprSpalten: fremd,
              befund: const LernspaltenBefund(
                zusatzBegabungen: ['Test'],
                unfaehigkeiten: ['Test'],
              ),
              merkmalskenntnisse: const <String>['Elementar (Feuer)'],
            );
            if (s.herleitung.schritte.isEmpty) continue;
            expect(
              s.herleitung.wert,
              kLernkomplexitaeten.indexOf(s.spalte),
              reason: '${spell.id} fremd=$fremd haus=$haus',
            );
          }
        }
      }
    });

    test('nennt Hauszauber, Merkmalskenntnis und fremde Repräsentation', () {
      final s = zauberLernspalte(
        spell: zauber('spell_ignifaxius'),
        eintrag: const HeroSpellEntry(hauszauber: true),
        fremdeReprSpalten: 2,
        befund: LernspaltenBefund.keiner,
        merkmalskenntnisse: const <String>['Elementar (Feuer)'],
      );
      final namen = s.herleitung.sichtbareSchritte.map((x) => x.bezeichnung);
      expect(
        namen,
        containsAll(<String>[
          kSpalteKatalogSchritt,
          kSpalteHauszauberSchritt,
          kSpalteMerkmalskenntnisSchritt,
          kSpalteFremdeReprSchritt,
        ]),
      );
    });
  });

  group('Fremde Repräsentation (Wege der Zauberei S. 74)', () {
    int spalten(String? a, String? b) => fremdeRepraesentationsSpalten(
      learnedRepresentation: a,
      learnedTradition: b,
    );

    test('Regelfall sind zwei Spalten, symmetrisch', () {
      expect(spalten('Dru', 'Elf'), 2);
      expect(spalten('Elf', 'Dru'), 2);
      expect(spalten('Srl', 'Bor'), 2);
    });

    test('Schelme zahlen drei Spalten, mit Scharlatanen zwei', () {
      expect(spalten('Sch', 'Mag'), 3);
      expect(spalten('Mag', 'Sch'), 3);
      expect(spalten('Sch', 'Srl'), 2);
      expect(spalten('Srl', 'Sch'), 2);
    });

    test(
      'Gildenmagier zahlen mit Scharlatan und Borbaradianer eine Spalte',
      () {
        expect(spalten('Mag', 'Srl'), 1);
        expect(spalten('Srl', 'Mag'), 1);
        expect(spalten('Mag', 'Bor'), 1);
        expect(spalten('Bor', 'Mag'), 1);
      },
    );

    test('gleiche oder fehlende Angaben kosten nichts', () {
      expect(spalten('Mag', 'Mag'), 0);
      expect(spalten(null, 'Mag'), 0);
      expect(spalten('Mag', ''), 0);
    });

    test('die Herleitung nennt die Spalten der fremden Repräsentation', () {
      final s = zauberLernspalte(
        spell: zauber('spell_armatrutz'),
        eintrag: null,
        fremdeReprSpalten: 3,
        befund: LernspaltenBefund.keiner,
        merkmalskenntnisse: const <String>[],
      );
      expect(
        s.herleitung.schritte
            .singleWhere((x) => x.bezeichnung == kSpalteFremdeReprSchritt)
            .betrag,
        3,
      );
    });
  });
}
