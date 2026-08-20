import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_cost_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_overrides.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/voraussetzungen_parser.dart';

/// Roh-Eingabe einer Sonderfertigkeit fuer den Graph-Aufbau.
class _SfInput {
  const _SfInput({
    required this.id,
    required this.name,
    required this.kind,
    required this.voraussetzungen,
    required this.kosten,
    required this.beschreibung,
    required this.nurEpisch,
  });

  final String id;
  final String name;
  final SkillNodeKind kind;
  final String voraussetzungen;
  final String kosten;
  final String beschreibung;
  final bool nurEpisch;
}

/// Baut den Kampf-Skilltree aus dem Regelkatalog.
SkillGraph buildCombatSkillGraph(
  RulesCatalog catalog, {
  Map<String, SkillTreeOverride> overrides = skillTreeOverrides,
}) {
  final inputs = catalog.combatSpecialAbilities
      .map(
        (def) => _SfInput(
          id: def.id,
          name: def.name,
          kind: SkillNodeKind.combatSf,
          voraussetzungen: def.voraussetzungen,
          kosten: def.kosten,
          beschreibung: def.beschreibung,
          nurEpisch: def.nurEpisch,
        ),
      )
      .toList(growable: false);
  return _buildGraph(inputs, catalog, overrides);
}

/// Baut den Magie-Skilltree aus dem Regelkatalog.
SkillGraph buildMagicSkillGraph(
  RulesCatalog catalog, {
  Map<String, SkillTreeOverride> overrides = skillTreeOverrides,
}) {
  final inputs = catalog.magicSpecialAbilities
      .map(
        (def) => _SfInput(
          id: def.id,
          name: def.name,
          kind: SkillNodeKind.magicSf,
          voraussetzungen: def.voraussetzungen,
          kosten: def.kosten,
          beschreibung: def.beschreibung,
          nurEpisch: def.nurEpisch,
        ),
      )
      .toList(growable: false);
  return _buildGraph(inputs, catalog, overrides);
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

SkillGraph _buildGraph(
  List<_SfInput> sfInputs,
  RulesCatalog catalog,
  Map<String, SkillTreeOverride> overrides,
) {
  // Namens- und ID-Indizes fuer Talente und Zauber.
  final talentById = {for (final t in catalog.talents) t.id: t};
  final spellById = {for (final s in catalog.spells) s.id: s};
  final talentByName = {for (final t in catalog.talents) _normalize(t.name): t};
  final spellByName = {for (final s in catalog.spells) _normalize(s.name): s};

  // Sichtbare SF (nicht via Override ausgeblendet) als Namensindex.
  final visibleSf = sfInputs
      .where((sf) => !(overrides[sf.id]?.ignore ?? false))
      .toList(growable: false);
  final sfByName = {for (final sf in visibleSf) _normalize(sf.name): sf};

  final nodes = <String, SkillNode>{};
  final edges = <SkillEdge>[];
  final edgeKeys = <String>{};

  void addEdge(String fromId, String toId, {bool alternative = false}) {
    if (fromId == toId) return;
    final key = '$fromId|$toId|$alternative';
    if (edgeKeys.add(key)) {
      edges.add(SkillEdge(fromId: fromId, toId: toId, isAlternative: alternative));
    }
  }

  void ensureTalentNode(String id) {
    final def = talentById[id];
    if (def == null || nodes.containsKey(id)) return;
    nodes[id] = SkillNode(id: id, name: def.name, kind: SkillNodeKind.talent);
  }

  void ensureSpellNode(String id) {
    final def = spellById[id];
    if (def == null || nodes.containsKey(id)) return;
    nodes[id] = SkillNode(id: id, name: def.name, kind: SkillNodeKind.spell);
  }

  // 1) SF-Knoten anlegen (mit gefilterten Voraussetzungen + AP-Kosten).
  for (final sf in visibleSf) {
    final override = overrides[sf.id];
    final removeNames = (override?.removePrerequisiteNames ?? const <String>[])
        .map(_normalize)
        .toSet();
    final parsed = parseVoraussetzungen(sf.voraussetzungen)
        .where((req) => !removeNames.contains(_normalize(_requirementName(req))))
        .toList(growable: false);
    nodes[sf.id] = SkillNode(
      id: sf.id,
      name: sf.name,
      kind: sf.kind,
      requirements: parsed,
      apCost: override?.apCostOverride ?? parseApCost(sf.kosten),
      voraussetzungenRaw: sf.voraussetzungen,
      kostenRaw: sf.kosten,
      beschreibung: sf.beschreibung,
      nurEpisch: sf.nurEpisch,
    );
  }

  // 2) Kanten aus den geparsten Voraussetzungen aufloesen.
  void resolve(SkillRequirement req, String toId, {bool alternative = false}) {
    switch (req) {
      case AbilityRequirement(:final name):
        final sf = sfByName[_normalize(name)];
        if (sf != null) addEdge(sf.id, toId, alternative: alternative);
      case TalentRequirement(:final name):
        final talent = talentByName[_normalize(name)];
        if (talent != null) {
          ensureTalentNode(talent.id);
          addEdge(talent.id, toId, alternative: alternative);
        }
      case SpellRequirement(:final name):
        final spell = spellByName[_normalize(name)];
        if (spell != null) {
          ensureSpellNode(spell.id);
          addEdge(spell.id, toId, alternative: alternative);
        }
      case OrRequirement(:final options):
        for (final option in options) {
          resolve(option, toId, alternative: true);
        }
      case AttributeRequirement():
      case TraitRequirement():
      case RaceRequirement():
      case UnknownRequirement():
        break;
    }
  }

  for (final sf in visibleSf) {
    final node = nodes[sf.id]!;
    for (final req in node.requirements) {
      resolve(req, sf.id);
    }
    // 3) Kuratierte Zusatz-Voraussetzungen.
    for (final extraId in overrides[sf.id]?.extraPrerequisiteIds ??
        const <String>[]) {
      ensureTalentNode(extraId);
      ensureSpellNode(extraId);
      if (nodes.containsKey(extraId)) {
        addEdge(extraId, sf.id);
      }
    }
  }

  // 4) Wurzeln = Knoten ohne eingehende Kanten.
  final withIncoming = edges.map((edge) => edge.toId).toSet();
  final rootIds = nodes.keys
      .where((id) => !withIncoming.contains(id))
      .toList(growable: false);

  return SkillGraph(nodes: nodes, edges: edges, rootIds: rootIds);
}

/// Liefert den Namen einer Voraussetzung fuer Override-Vergleiche.
String _requirementName(SkillRequirement req) => switch (req) {
  AbilityRequirement(:final name) => name,
  TalentRequirement(:final name) => name,
  SpellRequirement(:final name) => name,
  TraitRequirement(:final name) => name,
  RaceRequirement(:final name) => name,
  AttributeRequirement(:final attribute) => attribute,
  UnknownRequirement(:final rawText) => rawText,
  OrRequirement() => '',
};
