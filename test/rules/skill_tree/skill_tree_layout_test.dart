import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_layout.dart';

SkillGraph _chain() {
  const nodes = {
    'a': SkillNode(id: 'a', name: 'A', kind: SkillNodeKind.combatSf),
    'b': SkillNode(id: 'b', name: 'B', kind: SkillNodeKind.combatSf),
    'c': SkillNode(id: 'c', name: 'C', kind: SkillNodeKind.combatSf),
    'root': SkillNode(id: 'root', name: 'Root', kind: SkillNodeKind.talent),
  };
  const edges = [
    SkillEdge(fromId: 'a', toId: 'b'),
    SkillEdge(fromId: 'b', toId: 'c'),
    SkillEdge(fromId: 'root', toId: 'b'),
  ];
  return const SkillGraph(nodes: nodes, edges: edges, rootIds: ['a', 'root']);
}

void main() {
  group('computeTiers', () {
    test('weist Wurzeln Tier 0 zu', () {
      final tiers = computeTiers(_chain());
      expect(tiers['a'], 0);
      expect(tiers['root'], 0);
    });

    test('nimmt den laengsten Pfad als Tier', () {
      final tiers = computeTiers(_chain());
      expect(tiers['b'], 1);
      expect(tiers['c'], 2);
    });

    test('faengt Zyklen defensiv ab', () {
      const nodes = {
        'x': SkillNode(id: 'x', name: 'X', kind: SkillNodeKind.combatSf),
        'y': SkillNode(id: 'y', name: 'Y', kind: SkillNodeKind.combatSf),
      };
      const edges = [
        SkillEdge(fromId: 'x', toId: 'y'),
        SkillEdge(fromId: 'y', toId: 'x'),
      ];
      const graph = SkillGraph(nodes: nodes, edges: edges, rootIds: []);
      final tiers = computeTiers(graph);
      expect(tiers.keys, containsAll(['x', 'y']));
    });
  });

  group('layoutGraph', () {
    test('positioniert hoehere Tiers weiter rechts', () {
      final layout = layoutGraph(_chain());
      final ax = layout.positions['a']!.dx;
      final bx = layout.positions['b']!.dx;
      final cx = layout.positions['c']!.dx;
      expect(ax < bx, isTrue);
      expect(bx < cx, isTrue);
    });
  });
}
