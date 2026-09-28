import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_begabung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support/real_catalog.dart';

/// Begabung und Unfaehigkeit aus Vor-/Nachteilen wirken auf ihre Ziele.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RulesCatalog catalog;

  setUpAll(() async {
    catalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  HeroSheet held({
    String vorteile = '',
    String nachteile = '',
    Map<String, HeroTalentEntry> talents = const {},
    List<HeroRitualCategory> ritualCategories = const [],
    String muttersprache = '',
  }) {
    return HeroSheet(
      id: 'h',
      name: 'Test',
      level: 1,
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
      vorteileText: vorteile,
      nachteileText: nachteile,
      talents: talents,
      ritualCategories: ritualCategories,
      muttersprache: muttersprache,
    );
  }

  AdvancementOption option(HeroSheet hero, AdvancementKind kind, String id) {
    return resolveAdvancementOption(
      hero: hero,
      catalog: catalog,
      kind: kind,
      targetId: id,
    )!;
  }

  String komplexitaet(HeroSheet hero, AdvancementKind kind, String id) {
    return option(hero, kind, id).complexityHint!.split(' ').last;
  }

  group('Zuordnung geteilter Templates', () {
    test('„Begabung für X“ trifft den Eintrag, dessen Liste X führt', () {
      final katalog = MerkmalKatalog.von(catalog);
      final faelle = <String, String>{
        'Begabung für Abrichten': 'adv_begabung_anderes_talent',
        'Begabung für Schwerter': 'adv_begabung_kampf_koerper_talent',
        'Begabung für Objekt': 'adv_begabung_merkmal',
        'Begabung für Balsam Salabunde': 'adv_begabung_zauber',
        'Begabung für Hammerschlag': 'adv_begabung_ritual',
        'Begabung Talentgruppe Körperliche Talente':
            'adv_begabung_talentgruppe_kampf_koerper',
      };
      for (final MapEntry(key: text, value: id) in faelle.entries) {
        final eintrag = ordneMerkmalZu(text, katalog.vorteile);
        expect(eintrag.katalogId, id, reason: text);
      }
    });

    test('ohne Bestätigung durch eine Liste bleibt es mehrdeutig', () {
      final katalog = MerkmalKatalog.von(catalog);
      final eintrag = ordneMerkmalZu('Begabung für Blabla', katalog.vorteile);

      expect(eintrag.istKatalogisiert, isFalse);
      expect(eintrag.kandidatenIds.length, greaterThan(1));
    });
  });

  group('Talente', () {
    test('Einzeltalent: eine Spalte günstiger und Maximum +2', () {
      final ohne = held();
      final mit = held(vorteile: 'Begabung für Abrichten');

      expect(komplexitaet(ohne, AdvancementKind.talent, 'tal_abrichten'), 'B');
      expect(komplexitaet(mit, AdvancementKind.talent, 'tal_abrichten'), 'A');
      expect(
        option(mit, AdvancementKind.talent, 'tal_abrichten').maxValue,
        option(ohne, AdvancementKind.talent, 'tal_abrichten').maxValue + 2,
      );
      // Andere Talente bleiben unberührt.
      expect(komplexitaet(mit, AdvancementKind.talent, 'tal_klettern'), 'D');
    });

    test('Talentgruppe wirkt auf jedes Talent der Gruppe', () {
      final hero = held(vorteile: 'Begabung Talentgruppe Körperliche Talente');

      expect(komplexitaet(hero, AdvancementKind.talent, 'tal_klettern'), 'C');
      expect(komplexitaet(hero, AdvancementKind.talent, 'tal_schwimmen'), 'C');
      expect(komplexitaet(hero, AdvancementKind.talent, 'tal_abrichten'), 'B');
    });

    test('Nahkampf-Begabung trifft Nahkampf-, nicht Fernkampftalente', () {
      final hero = held(vorteile: 'Begabung für Nahkampf-Talente');

      expect(komplexitaet(hero, AdvancementKind.talent, 'tal_schwerter'), 'D');
      expect(komplexitaet(hero, AdvancementKind.talent, 'tal_bogen'), 'E');
    });

    test('Unfähigkeit: eine Spalte teurer, Maximum unverändert', () {
      final ohne = held();
      final hero = held(nachteile: 'Unfähigkeit für Abrichten');

      expect(komplexitaet(hero, AdvancementKind.talent, 'tal_abrichten'), 'C');
      expect(
        option(hero, AdvancementKind.talent, 'tal_abrichten').maxValue,
        option(ohne, AdvancementKind.talent, 'tal_abrichten').maxValue,
      );
      final befund = ermittleBegabungen(
        hero,
        catalog: catalog,
      ).talent(catalog.talents.firstWhere((t) => t.id == 'tal_abrichten'));
      expect(befund.unfaehig, isTrue);
      expect(befund.unfaehigkeitsQuellen, ['Unfähigkeit für Abrichten']);
    });

    test('Begabung und Unfähigkeit heben sich auf', () {
      final hero = held(
        vorteile: 'Begabung für Abrichten',
        nachteile: 'Unfähigkeit Talentgruppe Handwerkliche Talente',
      );

      expect(komplexitaet(hero, AdvancementKind.talent, 'tal_abrichten'), 'B');
    });

    test('Häkchen und Vorteil zählen zusammen nur eine Spalte', () {
      final hero = held(
        vorteile:
            'Begabung für Abrichten; '
            'Begabung Talentgruppe Handwerkliche Talente',
        talents: const {'tal_abrichten': HeroTalentEntry(gifted: true)},
      );

      expect(komplexitaet(hero, AdvancementKind.talent, 'tal_abrichten'), 'A');
    });
  });

  group('Zauber und Merkmale', () {
    test('Merkmals-Begabungen zählen je passendem Merkmal', () {
      // Custodosigil: Objekt, Metamagie, Elementar (Feuer); Basis C.
      final zwei = held(
        vorteile: 'Begabung für Objekt; Begabung für Elementar (Feuer)',
      );
      final eine = held(vorteile: 'Begabung für Objekt');

      expect(
        komplexitaet(
          eine,
          AdvancementKind.spell,
          'spell_custodosigil_diebesbann',
        ),
        'B',
      );
      expect(
        komplexitaet(
          zwei,
          AdvancementKind.spell,
          'spell_custodosigil_diebesbann',
        ),
        'A',
      );
      // Balsam (Heilung, Form) hat keines der Merkmale.
      expect(
        komplexitaet(zwei, AdvancementKind.spell, 'spell_balsam_salabunde'),
        'C',
      );
    });

    test('Merkmals-Unfähigkeit verteuert spiegelbildlich', () {
      final hero = held(
        vorteile: 'Begabung für Objekt; Begabung für Elementar (Feuer)',
        nachteile: 'Unfähigkeit für Metamagie',
      );

      expect(
        komplexitaet(
          hero,
          AdvancementKind.spell,
          'spell_custodosigil_diebesbann',
        ),
        'B',
      );
    });

    test('Zauber-Begabung: eine Spalte günstiger und Maximum +2', () {
      final ohne = held();
      final mit = held(vorteile: 'Begabung für Balsam Salabunde');

      expect(
        komplexitaet(mit, AdvancementKind.spell, 'spell_balsam_salabunde'),
        'B',
      );
      expect(
        option(mit, AdvancementKind.spell, 'spell_balsam_salabunde').maxValue,
        option(ohne, AdvancementKind.spell, 'spell_balsam_salabunde').maxValue +
            2,
      );
    });
  });

  group('Sprachen und Schriften', () {
    test('Sprachen-Begabung und Schriften-Unfähigkeit', () {
      final fremd = catalog.sprachen.firstWhere(
        (sprache) => sprache.familie != 'Garethi-Familie',
      );
      final ohne = held(muttersprache: 'spr_garethi');
      final hero = held(
        muttersprache: 'spr_garethi',
        vorteile: 'Begabung für Talentgruppe Sprachen',
        nachteile: 'Unfähigkeit Talentgruppe Schriften',
      );

      expect(
        option(ohne, AdvancementKind.language, fremd.id).learnCost,
        learnCostFromKomplexitaet('B'),
      );
      expect(
        option(hero, AdvancementKind.language, fremd.id).learnCost,
        learnCostFromKomplexitaet('A'),
      );
      expect(
        option(hero, AdvancementKind.script, 'sch_altes_alaani').learnCost,
        learnCostFromKomplexitaet('B'),
      );
    });
  });

  group('Rituale', () {
    HeroRitualCategory kategorie(
      String name, {
      List<HeroRitualEntry> rituale = const [],
    }) {
      return HeroRitualCategory(
        id: name,
        name: name,
        knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
        ownKnowledge: HeroRitualKnowledge(
          name: name,
          value: 5,
          learningComplexity: 'E',
        ),
        rituals: rituale,
      );
    }

    test('Ritual-Begabung verbilligt die Ritualkenntnis seiner Tradition', () {
      final stab = kategorie('Stabzauber');
      final eigene = kategorie(
        'Meine Rituale',
        rituale: const [HeroRitualEntry(name: 'Hammerschlag')],
      );
      final fremd = kategorie('Hexenflüche');
      final hero = held(
        vorteile: 'Begabung für Hammerschlag',
        ritualCategories: [stab, eigene, fremd],
      );
      final begabungen = ermittleBegabungen(hero, catalog: catalog);

      String wirksam(HeroRitualCategory k) {
        return effektiveRitualkenntnisKomplexitaet(
          basisKomplexitaet: 'E',
          befund: begabungen.ritualkenntnis(k),
        );
      }

      expect(wirksam(stab), 'D');
      expect(wirksam(eigene), 'D');
      expect(wirksam(fremd), 'E');
      expect(begabungen.ritualBegabungen('Hammerschlag'), [
        'Begabung für Hammerschlag',
      ]);
      expect(begabungen.ritualBegabungen('Ewige Flamme'), isEmpty);
    });

    test('Ritualkenntnis fällt nicht unter A', () {
      expect(
        effektiveRitualkenntnisKomplexitaet(
          basisKomplexitaet: 'A',
          befund: const LernspaltenBefund(begabungen: ['x']),
        ),
        'A',
      );
    });
  });

  group('Ohne Zuordnung keine Wirkung', () {
    test('freie und mehrdeutige Texte wirken nicht', () {
      final hero = held(vorteile: 'Begabung für Blabla');
      expect(ermittleBegabungen(hero, catalog: catalog).istLeer, isTrue);
    });

    test('gespeicherte Kandidaten wirken erst nach der Wahl', () {
      final hero = held(vorteile: 'Begabung für Abrichten').copyWith(
        vorteilEintraege: const [
          HeroMerkmal(
            text: 'Begabung für Abrichten',
            kandidatenIds: [
              'adv_begabung_anderes_talent',
              'adv_begabung_ritual',
            ],
            zuordnung: HeroMerkmalZuordnung.migration,
          ),
        ],
      );
      expect(komplexitaet(hero, AdvancementKind.talent, 'tal_abrichten'), 'B');
    });

    test('ohne Katalog wirkt nichts', () {
      final hero = held(vorteile: 'Begabung für Abrichten');
      expect(ermittleBegabungen(hero, catalog: null).istLeer, isTrue);
    });
  });

  test('die Merkmalskarte nennt Ziel und Richtung', () {
    final katalog = MerkmalKatalog.von(catalog);
    final begabung = ordneMerkmalZu('Begabung für Objekt', katalog.vorteile);
    final unfaehig = ordneMerkmalZu(
      'Unfähigkeit für Abrichten',
      katalog.nachteile,
    );

    expect(beschreibeMerkmal(begabung, katalog, vorteil: true).wirkungen, [
      'Zauber je Merkmal Objekt eine Spalte günstiger',
    ]);
    expect(beschreibeMerkmal(unfaehig, katalog, vorteil: false).wirkungen, [
      'Abrichten eine Spalte teurer',
    ]);
  });

  test('Reihenfolge: erst verteuern, dann verbilligen', () {
    expect(
      effectiveTalentLernkomplexitaet(
        basisKomplexitaet: 'H',
        gifted: true,
        unfaehigkeitsSchritte: 1,
      ),
      'G',
    );
    expect(
      effectiveSpellLernkomplexitaet(
        basisKomplexitaet: 'B',
        istHauszauber: false,
        zauberMerkmale: const [],
        heldMerkmalskenntnisse: const [],
        gifted: true,
        zusatzReduktion: 3,
      ),
      'A*',
    );
  });
}
