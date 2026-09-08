import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_graph_builder.dart';
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
      ),
      CombatSpecialAbilityDef(
        id: 'ksf_ausweichen_ii',
        name: 'Ausweichen II',
        voraussetzungen: 'GE 12; SF Ausweichen I und Aufmerksamkeit',
      ),
      CombatSpecialAbilityDef(
        id: 'ksf_ausweichen_iii',
        name: 'Ausweichen III',
        voraussetzungen: 'GE 15; SF Ausweichen II und Kampfreflexe',
        kosten: '200 AP',
      ),
      CombatSpecialAbilityDef(id: 'ksf_linkhand', name: 'Linkhand'),
      CombatSpecialAbilityDef(
        id: 'ksf_beidh_i',
        name: 'Beidhändiger Kampf I',
        voraussetzungen: 'GE 12, SF Linkhand',
      ),
      CombatSpecialAbilityDef(
        id: 'ksf_beidh_ii',
        name: 'Beidhändiger Kampf II',
        voraussetzungen: 'GE 15, SF Beidhändiger Kampf I',
      ),
      CombatSpecialAbilityDef(
        id: 'ksf_erzwingen',
        name: 'Erzwingen',
        voraussetzungen: 'TaW Raufen 10, TaW Ringen 7',
      ),
    ],
  );
}

void main() {
  group('buildCombatSkillGraph', () {
    test('legt fuer jede Kampf-SF einen Knoten an', () {
      final graph = buildCombatSkillGraph(_catalog());
      expect(graph.nodes.containsKey('ksf_ausweichen_i'), isTrue);
      expect(graph.nodes.containsKey('ksf_beidh_ii'), isTrue);
      expect(graph.nodes['ksf_ausweichen_i']!.kind, SkillNodeKind.combatSf);
    });

    test('bindet referenzierte Talente als Knoten ein', () {
      final graph = buildCombatSkillGraph(_catalog());
      expect(graph.nodes.containsKey('tal_raufen'), isTrue);
      expect(graph.nodes.containsKey('tal_ringen'), isTrue);
      expect(graph.nodes['tal_raufen']!.kind, SkillNodeKind.talent);
    });

    test('verkettet aufeinander aufbauende SF (Ausweichen I->II->III)', () {
      final graph = buildCombatSkillGraph(_catalog());
      expect(
        graph.edges,
        contains(
          const SkillEdge(fromId: 'ksf_ausweichen_i', toId: 'ksf_ausweichen_ii'),
        ),
      );
      expect(
        graph.edges,
        contains(
          const SkillEdge(
            fromId: 'ksf_ausweichen_ii',
            toId: 'ksf_ausweichen_iii',
          ),
        ),
      );
    });

    test('verkettet Beidhändiger Kampf I->II und Linkhand->I', () {
      final graph = buildCombatSkillGraph(_catalog());
      expect(
        graph.edges,
        contains(const SkillEdge(fromId: 'ksf_linkhand', toId: 'ksf_beidh_i')),
      );
      expect(
        graph.edges,
        contains(
          const SkillEdge(fromId: 'ksf_beidh_i', toId: 'ksf_beidh_ii'),
        ),
      );
    });

    test('zieht Kanten von benoetigten Talenten zur SF', () {
      final graph = buildCombatSkillGraph(_catalog());
      expect(
        graph.edges,
        contains(const SkillEdge(fromId: 'tal_raufen', toId: 'ksf_erzwingen')),
      );
      expect(
        graph.edges,
        contains(const SkillEdge(fromId: 'tal_ringen', toId: 'ksf_erzwingen')),
      );
    });

    test('erzeugt keine Knoten fuer unbekannte Referenzen', () {
      final graph = buildCombatSkillGraph(_catalog());
      final hasAufmerksamkeit = graph.nodes.values.any(
        (node) => node.name == 'Aufmerksamkeit',
      );
      expect(hasAufmerksamkeit, isFalse);
    });

    test('liest AP-Kosten aus dem kosten-Feld', () {
      final graph = buildCombatSkillGraph(_catalog());
      expect(graph.nodes['ksf_ausweichen_iii']!.apCost, 200);
    });

    test('markiert voraussetzungsfreie SF und Talente als Wurzeln', () {
      final graph = buildCombatSkillGraph(_catalog());
      expect(graph.rootIds, contains('ksf_ausweichen_i'));
      expect(graph.rootIds, contains('ksf_linkhand'));
      expect(graph.rootIds, contains('tal_raufen'));
      expect(graph.rootIds, isNot(contains('ksf_ausweichen_ii')));
      expect(graph.rootIds, isNot(contains('ksf_beidh_ii')));
    });
  });
}
