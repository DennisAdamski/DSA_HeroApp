import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_graph_builder.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_evaluation.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';

RulesCatalog _catalog() {
  return RulesCatalog(
    version: 'test',
    source: 'test',
    talents: const [
      TalentDef(
        id: 'tal_raufen',
        name: 'Raufen',
        group: 'Kampftalent',
        steigerung: 'D',
        attributes: ['MU', 'GE', 'KK'],
      ),
      TalentDef(
        id: 'tal_ringen',
        name: 'Ringen',
        group: 'Kampftalent',
        steigerung: 'D',
        attributes: ['GE', 'KO', 'KK'],
      ),
    ],
    spells: const [],
    weapons: const <WeaponDef>[],
    combatSpecialAbilities: const [
      CombatSpecialAbilityDef(
        id: 'ksf_ausweichen_i',
        name: 'Ausweichen I',
        voraussetzungen: 'GE 10',
        kosten: '100 AP',
      ),
      CombatSpecialAbilityDef(
        id: 'ksf_ausweichen_ii',
        name: 'Ausweichen II',
        voraussetzungen: 'GE 12; SF Ausweichen I und Aufmerksamkeit',
      ),
      CombatSpecialAbilityDef(
        id: 'ksf_ausweichen_iii',
        name: 'Ausweichen III',
        voraussetzungen: 'GE 15; SF Ausweichen II',
        kosten: '200 AP',
      ),
      CombatSpecialAbilityDef(
        id: 'ksf_erzwingen',
        name: 'Erzwingen',
        voraussetzungen: 'TaW Raufen 10, TaW Ringen 7',
      ),
    ],
  );
}

HeroSheet _hero({
  int ge = 12,
  Map<String, HeroTalentEntry> talents = const {},
  List<String> learnedCombatSf = const [],
  int apTotal = 1000,
  int apSpent = 0,
}) {
  return HeroSheet(
    id: 'h1',
    name: 'Test',
    level: 1,
    attributes: Attributes(
      mu: 10,
      kl: 10,
      inn: 10,
      ch: 10,
      ff: 10,
      ge: ge,
      ko: 10,
      kk: 10,
    ),
    talents: talents,
    apTotal: apTotal,
    apSpent: apSpent,
    apAvailable: apTotal - apSpent,
    combatConfig: CombatConfig(
      specialRules: CombatSpecialRules(
        activeCombatSpecialAbilityIds: learnedCombatSf,
      ),
    ),
  );
}

SkillTreeView _view(HeroSheet hero) {
  final graph = buildCombatSkillGraph(_catalog());
  return evaluateSkillTree(
    graph: graph,
    category: SkillTreeCategory.combat,
    hero: hero,
    effectiveAttributes: hero.attributes,
  );
}

void main() {
  group('evaluateSkillTree', () {
    test('SF mit erfuellten Voraussetzungen ist lernbar', () {
      final view = _view(_hero(ge: 12));
      expect(
        view.evaluated['ksf_ausweichen_i']!.state,
        SkillNodeState.learnable,
      );
    });

    test('SF mit fehlender Voraussetzungs-SF ist gesperrt', () {
      final view = _view(_hero(ge: 12));
      final node = view.evaluated['ksf_ausweichen_ii']!;
      expect(node.state, SkillNodeState.locked);
      expect(
        node.unmetRequirements,
        contains(const AbilityRequirement('Ausweichen I')),
      );
    });

    test('SF mit nicht erfuellter Eigenschaft ist gesperrt', () {
      final view = _view(_hero(ge: 9));
      final node = view.evaluated['ksf_ausweichen_i']!;
      expect(node.state, SkillNodeState.locked);
      expect(
        node.unmetRequirements,
        contains(const AttributeRequirement('ge', 10)),
      );
    });

    test('gelernte Kampf-SF wird als learned erkannt', () {
      final view = _view(_hero(learnedCombatSf: ['ksf_ausweichen_i']));
      expect(view.evaluated['ksf_ausweichen_i']!.state, SkillNodeState.learned);
    });

    test('erfuellte Voraussetzungen mit unklarem Rest ergeben unknown', () {
      // Ausweichen I gelernt + GE 12 → Ausweichen II: nur "Aufmerksamkeit"
      // bleibt unklar (kein Knoten, nicht eingetragen).
      final view = _view(_hero(ge: 12, learnedCombatSf: ['ksf_ausweichen_i']));
      expect(
        view.evaluated['ksf_ausweichen_ii']!.state,
        SkillNodeState.unknownRequirements,
      );
    });

    test('Talentvoraussetzungen werden gegen den TaW geprueft', () {
      final lowView = _view(
        _hero(
          talents: const {
            'tal_raufen': HeroTalentEntry(talentValue: 5),
            'tal_ringen': HeroTalentEntry(talentValue: 12),
          },
        ),
      );
      expect(lowView.evaluated['ksf_erzwingen']!.state, SkillNodeState.locked);

      final highView = _view(
        _hero(
          talents: const {
            'tal_raufen': HeroTalentEntry(talentValue: 12),
            'tal_ringen': HeroTalentEntry(talentValue: 12),
          },
        ),
      );
      expect(
        highView.evaluated['ksf_erzwingen']!.state,
        SkillNodeState.learnable,
      );
    });

    test('canAfford spiegelt verfuegbare AP gegen AP-Kosten', () {
      final poor = _view(_hero(apTotal: 50));
      expect(poor.evaluated['ksf_ausweichen_i']!.canAfford, isFalse);

      final rich = _view(_hero(apTotal: 500));
      expect(rich.evaluated['ksf_ausweichen_i']!.canAfford, isTrue);
    });
  });
}
