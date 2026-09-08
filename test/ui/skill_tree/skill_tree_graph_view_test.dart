import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';
import 'package:dsa_heldenverwaltung/ui/screens/skill_tree/skill_tree_graph_view.dart';

SkillTreeView _view() {
  const nodes = {
    'a': SkillNode(
      id: 'a',
      name: 'Ausweichen I',
      kind: SkillNodeKind.combatSf,
      apCost: 100,
    ),
    'b': SkillNode(
      id: 'b',
      name: 'Ausweichen II',
      kind: SkillNodeKind.combatSf,
      apCost: 200,
    ),
  };
  const edges = [SkillEdge(fromId: 'a', toId: 'b')];
  const graph = SkillGraph(nodes: nodes, edges: edges, rootIds: ['a']);
  final evaluated = {
    'a': const EvaluatedNode(
      node: SkillNode(
        id: 'a',
        name: 'Ausweichen I',
        kind: SkillNodeKind.combatSf,
        apCost: 100,
      ),
      state: SkillNodeState.learnable,
      canAfford: true,
    ),
    'b': const EvaluatedNode(
      node: SkillNode(
        id: 'b',
        name: 'Ausweichen II',
        kind: SkillNodeKind.combatSf,
        apCost: 200,
      ),
      state: SkillNodeState.locked,
    ),
  };
  return SkillTreeView(
    graph: graph,
    evaluated: evaluated,
    category: SkillTreeCategory.combat,
  );
}

void main() {
  testWidgets('rendert Knoten und meldet Tipps', (tester) async {
    EvaluatedNode? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: SkillTreeGraphView(
              view: _view(),
              onNodeTap: (evaluated) => tapped = evaluated,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ausweichen I'), findsOneWidget);
    expect(find.text('Ausweichen II'), findsOneWidget);
    expect(find.text('Lernbar'), findsOneWidget);
    expect(find.text('Gesperrt'), findsOneWidget);

    await tester.tap(find.text('Ausweichen I'));
    expect(tapped?.node.id, 'a');
  });
}
